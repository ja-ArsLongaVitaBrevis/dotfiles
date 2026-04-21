#!/usr/bin/env bash
# Measure interactive login shell startup time.
#
# Usage:
#   bin/bench-shell.sh            # 5 samples, report min/median/mean
#   bin/bench-shell.sh 10         # N samples
#   bin/bench-shell.sh 5 trace    # also dump per-line trace to /tmp/dotfiles-trace.log

set -euo pipefail

samples="${1:-5}"
mode="${2:-}"

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
