# jesuarva-dotfiles

Personal terminal setup. Architected for fast interactive shell startup
(~30ms on Apple Silicon + Homebrew).

## Architecture

Entry point is `.bash_profile`, sourced by `~/.bash_profile`. It sets
`DOTFILES_DIR` and sources modules in a deliberate order:

```
.bash_profile
├── lib/00-core.sh        env, history, BASH_SILENCE
├── lib/10-brew.sh        brew shellenv + bash-completion@2 (lazy per-command)
├── lib/20-aliases.sh     generic aliases (ls, docker, killPort, etc.)
├── dx-tools/aws/aws.sh   AWS CLI completion + helper functions
├── git_setup/git_setup.sh  git aliases + opt-in git_completion_load
├── Python/python.sh      python venv / http.server helpers
├── Rust/rust.sh          sources $HOME/.cargo/env if present
├── AiTools/ClaudeBedrock.sh  Claude via Amazon Bedrock env
├── lib/40-lazy.sh        LAZY: nvm / node / npm / npx stubs
└── lib/30-prompt.sh      PS1 + __git_ps1 (sources git-prompt.sh)
```

Per-machine overrides: `.local.sh` in this repo (gitignored) or
`~/.bash_profile.local`.

### Design rules

1. **No subprocesses at load time.** Every `$(...)` or `eval "$(...)"` at
   startup is 1–100ms. Cache with `export`, or defer.
2. **Lazy-load expensive tools.** NVM alone is ~4,700 lines; sourcing it at
   startup cost ~1 second. Instead `lib/40-lazy.sh` defines stubs for `nvm`,
   `node`, `npm`, `npx` that load the real thing on first invocation.
3. **One completion entry point, not a loop.** `bash-completion@2` (loaded
   once in `lib/10-brew.sh`) registers a dynamic loader — completions are
   pulled in only when the user presses TAB for that command.
4. **Prompt tuning matters.** `__git_ps1` with `SHOWUPSTREAM=verbose` +
   `SHOWUNTRACKEDFILES` runs extra git commands on every prompt render —
   painful in big repos. Those flags are off by default.

## Benchmarking

```
bin/bench-shell.sh            # 5 samples, min/median/mean
bin/bench-shell.sh 20         # 20 samples
bin/bench-shell.sh 1 trace    # per-line trace -> /tmp/dotfiles-trace.log
```

Or one-off:

```
DOTFILES_PROFILE=1 bash -lic exit 2> /tmp/trace.log
```

## Opt-in features

- **NVM auto-switch on `cd`** — the old setup redefined `cd` globally and
  triggered `nvm use` on every directory change. Now opt-in per session:
  ```
  source "$DOTFILES_DIR/nvm/auto-switch.sh"
  ```
  Or enable always by uncommenting the line in `lib/40-lazy.sh`.

- **AWS CLI auto-prompt** — `export AWS_CLI_AUTO_PROMPT=on` in the shell you
  want it in. It's off by default because it adds latency to every `aws`
  call.

- **Eager git completion** — `git_completion_load` in any shell to source
  the full 71 KB `git-completion.bash` immediately. Normally you don't
  need this: bash-completion@2 loads it lazily on the first `git<TAB>`.

## Setup on a new machine

1. Install Homebrew: https://brew.sh
2. `brew install bash-completion@2 git nvm jq`
3. `nvm alias default <node_version>`
4. Clone this repo to `~/CodeBis/jesuarva-dotfiles`
5. Add to `~/.bash_profile`:
   ```
   source ~/CodeBis/jesuarva-dotfiles/.bash_profile
   ```
6. Install AWS CLI v2 if needed.

Optional: JDK, Rust (`curl https://sh.rustup.rs -sSf | sh`).
