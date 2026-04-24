#!/bin/bash
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
[[ -d $LOCATION ]] || mkdir -p ${LOCATION}

DOTFILES_DIR="$LOCATION/dotfiles"
git clone git@github.com:ja-ArsLongaVitaBrevis/dotfiles.git "$DOTFILES_DIR"
## Wire it into ~/.bash_profile (create the file if it doesn't exist yet
[[ -f ~/.bash_profile ]] || touch ~/.bash_profile
echo "source \"$DOTFILES_DIR/.bash_profile\"" >> ~/.bash_profile
source ~/.bash_profile

# Homebrew + dependencies
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# nvm
## The NVM install script APPENDS an eager `. nvm.sh` block to ~/.bash_profile.
## That block defeats nvm/lazy.sh and adds ~0.25 s to every new shell on Apple
## Silicon. Strip it out right after install, then re-source.
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
sed -i.bak '/NVM_DIR/d;/nvm\.sh/d;/nvm.*bash_completion/d' ~/.bash_profile && rm ~/.bash_profile.bak
source ~/.bash_profile
nvm install --lts
nvm alias default 'lts/*'


# Open a new terminal. Verify — target ≤0.10 s median on Apple Silicon,
# ≤0.05 s on Intel. The bench script also runs a "doctor" pass that warns
# on known footguns (eager NVM, eager `rbenv init`, etc).
cd "$DOTFILES_DIR" && bin/bench-shell.sh 10
