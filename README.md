# dotfiles

A modular Bash environment for macOS, engineered for fast interactive shell
startup. The previous iteration took **~1 second** to open every new terminal
tab; this one takes **~30 milliseconds** — a **~32× improvement** without
losing any functionality.

---

## Results

Measured on Apple Silicon (M-series) with macOS system bash (3.2.57), 20
samples of `bash -lic exit`:

|                     |  Before |   After |     Delta |
| ------------------- | ------: | ------: | --------: |
| Median startup      | 1.010 s | 0.030 s | **−97 %** |
| Mean startup        | 1.016 s | 0.031 s | **−97 %** |
| Worst-case (p100)   |  1.02 s | 0.050 s | **−95 %** |
| `.bash_profile` LOC |     127 |      62 |     −51 % |

Reproduce on your machine:

```bash
bin/bench-shell.sh 20
```

---

## The problem

The original setup sourced **ten** modules eagerly at startup. The two main
offenders:

- **NVM** — `nvm.sh` is ~4,700 lines. Sourcing it at startup cost ~500 ms–2 s
  on its own. Worse, a "deep shell integration" script globally redefined
  `cd` to call `nvm use` on every directory change, so each `cd` paid a
  `nvm_find_up` traversal cost forever after.
- **Homebrew completions** — a `for` loop sourced every file in
  `$HOMEBREW_PREFIX/etc/bash_completion.d/` at startup, even though
  `bash-completion@2` already supports on-demand loading.

Smaller cuts came from a 71 KB `git-completion.bash` sourced eagerly,
`$(which aws_completer)` subshells, `AWS_CLI_AUTO_PROMPT=on` adding latency to
every `aws` call, and a `__git_ps1` prompt running extra `git ls-files` /
`git rev-list` commands on every render.

## The solution

Three principles drove the restructure:

1. **No subprocesses at load time.** Every `$(...)` or `eval "$(...)"` at
   startup costs 1–100 ms. Cache via `export`, or defer.
2. **Lazy-load expensive tools.** Replace a heavy `source` with a thin stub
   that loads the real tool on first invocation.
3. **One completion entry point, not a loop.** `bash-completion@2` registers
   a dynamic loader — completions are sourced only when the user TABs for
   that command.

---

## Architecture

```
.
├── .bash_profile                 Entry point. Resolves DOTFILES_DIR, orders modules.
│
├── lib/                          Cross-cutting infrastructure (numeric prefix = load order).
│   ├── 00-core.sh                Env, history, BASH_SILENCE_DEPRECATION.
│   ├── 10-brew.sh                brew shellenv + bash-completion@2 init.
│   ├── 20-aliases.sh             Generic aliases (ls, docker, killPort, ...).
│   └── 30-prompt.sh              PS1 + git-prompt (tuned for speed).
│
├── nvm/                          The biggest startup win.
│   ├── lazy.sh                   Lazy stubs for nvm / node / npm / npx.
│   └── auto-switch.sh            .nvmrc-aware cd wrapper (sourced by lazy.sh).
│
├── git_setup/
│   ├── git_setup.sh              Git aliases; sources git-prompt.sh for PS1.
│   ├── git-prompt.sh             Vendor — sourced once.
│   └── git-completion.bash       Vendor — loaded lazily via bash-completion@2.
│
├── dx-tools/aws/
│   ├── aws.sh                    AWS CLI completion + helpers.
│   └── aws-helpers.sh            Pure-function helper library.
│
├── AiTools/ClaudeBedrock.sh      Claude via Amazon Bedrock (env + alias).
├── Python/python.sh              venv helpers.
├── Rust/rust.sh                  Guarded $HOME/.cargo/env source.
│
└── bin/bench-shell.sh            Timing harness.
```

**Module-local logic stays in the module.** `nvm/`'s lazy loader lives
alongside its auto-switch wrapper — not in `lib/` — so the nvm concern is
self-contained. Adding another heavy tool (e.g. `pyenv`) follows the same
pattern: its own directory, its own `lazy.sh`, one line in `.bash_profile`.

Each top-level directory is a **module**: it owns its scripts and its own
`.md` documentation. New modules plug in with a one-line `source` in
`.bash_profile`.

### Load order (and why it matters)

```
00-core       →  set env and history before anything else touches them
10-brew       →  HOMEBREW_PREFIX must exist for later modules to find completions
20-aliases    →  cheap, no dependencies
tool modules  →  (aws, git, python, rust, ai) env vars & function defs only
nvm/lazy.sh   →  install nvm stubs LAST, so they don't shadow real commands
30-prompt     →  PS1 is set last so every GIT_PS1_* var from git_setup is in scope
```

---

## Key techniques

### Lazy-loading pattern

The core trick. Instead of sourcing a 4,700-line script at startup, define a
stub that loads it on first call and then re-invokes itself.

```bash
# nvm/lazy.sh
_load_nvm() {
  unset -f nvm node npm npx _load_nvm
  \. "$NVM_DIR/nvm.sh"
  [[ -s "$NVM_DIR/bash_completion" ]] && \. "$NVM_DIR/bash_completion"
}
nvm()  { _load_nvm; nvm  "$@"; }
node() { _load_nvm; node "$@"; }
npm()  { _load_nvm; npm  "$@"; }
npx()  { _load_nvm; npx  "$@"; }
```

The first call pays the ~500 ms load cost once. Subsequent calls hit the real
`nvm` directly. Shells that never touch Node (e.g. a tab just running `git`)
pay zero.

A similar pattern could wrap `pyenv`, `rbenv`, `jenv`, `conda`, or the Google
Cloud SDK — anything that ships a heavy init script.

### Default-node on PATH without loading nvm

Stubs break editors and scripts that shell out to `node` without a bash
function context. Fix: read `$NVM_DIR/alias/default` and inject the matching
`bin/` onto PATH without loading nvm itself.

```bash
if [[ -s "$NVM_DIR/alias/default" ]]; then
  _nvm_default="$(< "$NVM_DIR/alias/default")"
  export PATH="$NVM_DIR/versions/node/v$_nvm_default/bin:$PATH"
fi
```

### Prompt tuning

`__git_ps1` is called on every prompt render. The default is fast; these
flags are not:

```bash
# Disabled for speed — each adds a git subprocess per prompt:
# export GIT_PS1_SHOWUNTRACKEDFILES=1   # runs `git ls-files --others`
# export GIT_PS1_SHOWUPSTREAM='verbose' # runs `git rev-list --count`
```

Kept on (cheap — flags from `git status` alone): dirty state, stash state,
color hints.

### Completion deferral

The old `.brew.sh` looped over every file in `bash_completion.d/`:

```bash
# Before — eager, sources N files at startup:
for completion in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*; do
  [[ -r "$completion" ]] && source "$completion"
done
```

Replaced with a single entry point that wires `bash-completion@2`'s loader.
Completions are now sourced on the user's first TAB for that command:

```bash
# After — one source, lazy per-command:
source "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh"
```

### Opt-in `cd` auto-switch

The old integration aliased `cd` globally. The new one is a per-session
opt-in:

```bash
source "$DOTFILES_DIR/nvm/auto-switch.sh"
```

Default shells keep a bare `cd` builtin with zero overhead.

---

## Profiling

Per-line trace of a startup — useful for spotting regressions:

```bash
bin/bench-shell.sh 1 trace
# prints the 20 slowest lines
```

Or manually:

```bash
DOTFILES_PROFILE=1 bash -lic exit 2> /tmp/trace.log
```

`DOTFILES_PROFILE=1` enables `set -x` with a timestamped `PS4` inside
`.bash_profile`, so every sourced line is logged with wall-clock time.

---

## Opt-in features

All off by default; enable per session or by uncommenting a single line in
`nvm/lazy.sh`.

| Feature                      | Why it's off                                      | Enable                                    |
| ---------------------------- | ------------------------------------------------- | ----------------------------------------- |
| `nvm`-aware `cd` auto-switch | Adds per-`cd` cost even outside Node projects     | `source $DOTFILES_DIR/nvm/auto-switch.sh` |
| AWS CLI auto-prompt          | Adds latency to every `aws` invocation            | `export AWS_CLI_AUTO_PROMPT=on`           |
| Eager git completion         | 71 KB script; bash-completion@2 handles it lazily | `git_completion_load`                     |

---

## Per-machine overrides

Anything you don't want in the repo (secrets, work-specific aliases) goes in
either of these, both loaded last and both git-ignored:

- `$DOTFILES_DIR/.local.sh` — lives in the repo, ignored by `.gitignore`
- `~/.bash_profile.local` — lives in `$HOME`

---

## Setup on a new machine

The repo is **location-independent** — `DOTFILES_DIR` resolves itself from
`BASH_SOURCE` at load time (following symlinks), so you can clone anywhere.
It is also **architecture-independent** across macOS: the brew loader probes
`/opt/homebrew` (Apple Silicon) and `/usr/local` (Intel) in that order, and
Apple-Silicon-only aliases (e.g. `rosetta2`) are defined conditionally via
the Bash builtin `$HOSTTYPE`.

```bash

# Xcode Command Line Tools — the lightweight dev bundle Apple ships separately
# from the full Xcode.app. Required here because it provides `git` (used to
# clone this repo) and the toolchain Homebrew needs to build from source.
# Opens a GUI dialog; wait for it to finish before continuing. No-op if
# already installed.
#
# What you get (key tools; not exhaustive):
#   - git                  — version control
#   - clang / clang++      — Apple's C / C++ / Objective-C compiler
#   - make, ld, ar, nm,    — build + binutils-style tools
#     strip, lipo, otool
#   - lldb                 — debugger
#   - swift                — Swift compiler + REPL
#   - python3, perl, ruby  — Apple's bundled scripting runtimes
#   - xcrun, xcode-select  — toolchain selectors
#   - SDK headers          — under /Library/Developer/CommandLineTools/SDKs/
#
# Note: `brew install git` below installs a newer git over Apple's (and ships
# the contrib completion/prompt scripts this repo sources).
#
# Caveat: `xcode-select --install` only *triggers* the GUI installer and
# returns immediately — it does NOT block until the install finishes. We
# poll `xcode-select -p` so the rest of the script doesn't race ahead and
# fail with "git: command not found".
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install 2>/dev/null || true
  printf 'Waiting for Xcode Command Line Tools to finish installing'
  until xcode-select -p >/dev/null 2>&1; do
    printf '.'
    sleep 5
  done
  printf '\nXcode Command Line Tools installed.\n'
fi

# Clone wherever you like:
## Pick any location — then reuse $DOTFILES_DIR in the rest of this setup.
LOCATION="$HOME/CodeJean"
[[ -d $LOCATION ]] || mkdir ${LOCATION}

DOTFILES_DIR="$LOCATION/dotfiles"
git clone https://github.com/jesuarva/jesuarva-dotfiles.git "$DOTFILES_DIR"
## Wire it into ~/.bash_profile (create the file if it doesn't exist yet
[[ -f ~/.bash_profile ]] || touch ~/.bash_profile
echo "source \"$DOTFILES_DIR/.bash_profile\"" >> ~/.bash_profile
source ~/.bash_profile

# Homebrew + dependencies
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# nv
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
## Set a default Node so stubs can expose it on PATH
nvm install --lts
nvm alias default 'lts/*'


# Open a new terminal. Verify:
cd "$DOTFILES_DIR" && bin/bench-shell.sh 10
```

Optional: AWS CLI v2, Rust (`curl https://sh.rustup.rs -sSf | sh`), Google
Cloud SDK.

---

## Repository layout

Each module directory holds its script(s) plus a `.md` with the
language-/tool-specific notes I've accumulated over time.

| Directory                 | What's in it                                                         |
| ------------------------- | -------------------------------------------------------------------- |
| `lib/`                    | Infrastructure loaded on every shell                                 |
| `bin/`                    | Executables in the repo (currently just the benchmark)               |
| `AiTools/`                | Claude + Bedrock environment                                         |
| `Python/`                 | venv helpers + Python notes                                          |
| `Rust/`                   | Cargo env sourcing                                                   |
| `git_setup/`              | Git aliases, `git-prompt.sh`, lazy `git-completion.bash`             |
| `dx-tools/aws/`           | AWS CLI completion + a helper library for IAM role / stack workflows |
| `nvm/`                    | Opt-in `.nvmrc` auto-switch                                          |
| `Elixir/`, `GoogleCloud/` | Notes (no active shell config)                                       |

---

## Stack

- **Bash 3.2+** — runs on macOS system bash out of the box; also tested on
  Homebrew Bash 5 (`brew install bash`)
- **bash-completion@2** for lazy command completion
- **nvm** lazy-loaded on demand
- No external prompt framework — PS1 built with `__git_ps1` from
  `git-prompt.sh` (the one that ships with Git itself)

No oh-my-bash, no starship, no Powerlevel10k. The whole system is ~400 lines
of shell, readable end-to-end.
