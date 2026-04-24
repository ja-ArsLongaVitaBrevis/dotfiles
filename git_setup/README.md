# git_setup

Git aliases, prompt integration, lazy completion, and multi-identity SSH signing.

> Back to → [dotfiles root](../README.md)

---

## What this module loads

| File | Purpose |
|---|---|
| `git_setup.sh` | Git aliases; sources `git-prompt.sh` for PS1 |
| `git-prompt.sh` | Vendor script (ships with Homebrew git); sourced once at startup |
| `git-completion.bash` | Vendor script; registered lazily via `bash-completion@2` — loaded on first `<TAB>` |
| `lazy.sh` | Defers `git-completion.bash` registration so it doesn't cost startup time |

---

## Multi-identity setup (directory = identity)

If you work with more than one GitHub account on one machine, see:

→ **[`identities/README.md`](./identities/README.md)**

---

## How-to guides

Standalone recipes for common history-surgery tasks:

| Guide | What it covers |
|---|---|
| [Sign commits with SSH](./howto/sign-commits-with-ssh.md) | Generate an SSH key in 1Password, upload to GitHub, configure Git to sign commits automatically |
| [Sign past commits (Verified badge)](./howto/sign-past-commits.md) | Rewrite branch history to attach signatures to existing commits |
| [Rewrite author email in history](./howto/rewrite-author-email.md) | Bulk-change committer/author email across a repo's entire history |
