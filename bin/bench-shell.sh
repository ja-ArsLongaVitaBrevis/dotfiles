#!/usr/bin/env bash
# Measure interactive login shell startup time + diagnose common slowdowns.
#
# Usage:
#   bin/bench-shell.sh            # 5 samples, report min/median/mean + doctor
#   bin/bench-shell.sh 10         # N samples
#   bin/bench-shell.sh 5 trace    # also dump per-line trace to /tmp/dotfiles-trace.log
#   bin/bench-shell.sh doctor     # only run the doctor checks (no benchmark)
#
# Expected numbers on a clean setup (macOS stock /bin/bash 3.2):
#   Apple Silicon (M1–M5): 0.05–0.10 s
#   Intel:                 0.02–0.05 s
# If you see > 0.20 s on Apple Silicon, the doctor below will usually find why.

set -euo pipefail

# ---------------------------------------------------------------------------
# doctor() — audit the user's shell init files for known perf footguns.
# Prints warnings to STDOUT; never fails the script.
# ---------------------------------------------------------------------------
doctor() {
  local issues=0
  local bp="${HOME}/.bash_profile"
  local brc="${HOME}/.bashrc"

  printf '\n== Shell-init doctor ==\n'

  if [[ ! -r "$bp" ]]; then
    printf '  ⚠  ~/.bash_profile not readable (or missing).\n'
    issues=$((issues+1))
  fi

  # 1) Eager NVM source — the #1 startup killer on Apple Silicon.
  #    Matches lines that run `nvm.sh` directly at shell start.
  if [[ -r "$bp" ]] && grep -qE '^\s*[^#].*(\\\.|source|\.)\s*"?\$?\{?NVM_DIR\}?/nvm\.sh' "$bp"; then
    printf '  ⚠  ~/.bash_profile eagerly sources $NVM_DIR/nvm.sh.\n'
    printf '     This defeats nvm/lazy.sh and adds ~0.25 s per new shell.\n'
    printf '     Delete the block — %s handles nvm lazily.\n' 'nvm/lazy.sh'
    grep -nE '(\\\.|source|\.)\s*"?\$?\{?NVM_DIR\}?/nvm\.sh' "$bp" | sed 's/^/     /'
    issues=$((issues+1))
  fi
  if [[ -r "$brc" ]] && grep -qE '(\\\.|source|\.)\s*"?\$?\{?NVM_DIR\}?/nvm\.sh' "$brc"; then
    printf '  ⚠  ~/.bashrc eagerly sources $NVM_DIR/nvm.sh (same problem).\n'
    issues=$((issues+1))
  fi

  # 2) Obsolete `for`-loop over bash_completion.d — replaced by lazy @2 loader.
  if [[ -r "$bp" ]] && grep -qE 'bash_completion\.d/?\*' "$bp"; then
    printf '  ⚠  ~/.bash_profile iterates over bash_completion.d/*.\n'
    printf '     lib/10-brew.sh uses bash-completion@2 lazy loading instead.\n'
    issues=$((issues+1))
  fi

  # 3) `eval "$(rbenv init)"`, `pyenv init`, etc. — often slow; recommend lazy.
  for tool in rbenv pyenv goenv jenv; do
    if [[ -r "$bp" ]] && grep -qE "${tool}\s+init" "$bp"; then
      printf '  ℹ  ~/.bash_profile runs `%s init` eagerly (~50–150 ms each).\n' "$tool"
      printf '     Consider wrapping in a lazy stub like nvm/lazy.sh.\n'
    fi
  done

  # 4) Duplicate dotfiles entry-points (user sources `.bash_profile` twice).
  if [[ -r "$bp" ]]; then
    local count
    count=$(grep -cE 'dotfiles/\.bash_profile' "$bp" 2>/dev/null || echo 0)
    if (( count > 1 )); then
      printf '  ⚠  ~/.bash_profile sources dotfiles/.bash_profile %s times.\n' "$count"
      issues=$((issues+1))
    fi
  fi

  # 5) Hardware / bash info — useful when comparing across devices.
  local arch bash_ver
  arch="$(uname -m)"
  bash_ver="$(/bin/bash --version | head -1)"
  printf '  ℹ  /bin/bash: %s\n' "$bash_ver"
  printf '  ℹ  arch: %s\n' "$arch"

  if (( issues == 0 )); then
    printf '  ✓  No known perf footguns detected.\n'
  else
    printf '\n  %d issue(s) detected — fix these first for biggest wins.\n' "$issues"
  fi
}

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
samples="${1:-5}"
mode="${2:-}"

if [[ "$samples" == "doctor" ]]; then
  doctor
  exit 0
fi

if [[ "$mode" == "trace" ]]; then
  DOTFILES_PROFILE=1 bash -lic exit 2> /tmp/dotfiles-trace.log
  echo "Trace written to /tmp/dotfiles-trace.log"
  echo "Slowest 20 lines (rough, based on gaps between timestamps):"
  awk '
    /^\+ [0-9]/ {
      t = $2
      if (prev_t > 0) {
        dt = t - prev_t
        if (dt > 0.001) printf "%.3f  %s\n", dt, prev_line
      }
      prev_t = t
      $1=""; $2=""
      prev_line = $0
    }
  ' /tmp/dotfiles-trace.log | sort -rn | head -20
  exit 0
fi

# ---------------------------------------------------------------------------
# Benchmark
# ---------------------------------------------------------------------------
echo "Benchmarking 'bash -lic exit' × $samples..."
times=()
for _ in $(seq 1 "$samples"); do
  t=$( { /usr/bin/time -p bash -lic exit; } 2>&1 | awk '/^real/ {print $2}' )
  times+=("$t")
  printf '  %s\n' "$t"
done

printf '%s\n' "${times[@]}" | sort -n | awk '
  { a[NR] = $1; sum += $1 }
  END {
    n = NR
    mid = (n + 1) / 2
    median = (n % 2) ? a[int(mid)] : (a[n/2] + a[n/2+1]) / 2
    printf "\nmin:    %.3fs\nmedian: %.3fs\nmax:    %.3fs\nmean:   %.3fs\n", a[1], median, a[n], sum/n
  }
'

doctor
