# Git Identities — directory-scoped auth + signing

Architecture for working with **multiple git users on one machine**. Each
identity lives in its own root directory (`~/Code<identity>`, `~/CodeWork`, …)
and gets its own authentication SSH key + commit-signing SSH key, both
stored in **1Password** and exposed to the shell via `SSH_AUTH_SOCK`.

**Core rule:** *directory = identity*. Clone any repo under an identity
root and git picks up the right `user.name`, `user.email`, auth key,
signing key, and host alias automatically — no per-repo `git config`
gymnastics.

---

## Why this exists

One box, three GitHub accounts (personal alt, personal main, work). Each
account needs:
- a distinct commit email + display name,
- a distinct authentication key (so `git push` authenticates as the right
  user),
- a distinct signing key (so commits show **Verified** on GitHub).

Trying to juggle this with a single `~/.gitconfig` and a single
`~/.ssh/id_ed25519` silently attributes commits to the wrong user the
moment you forget to `cd`-then-`git config user.email`. Ask me how I know.

This module makes the attribution path **fail-closed** instead of
fail-silent.

---

## How it works — three-layer stack

```
┌──────────────────────────────────────────────────────────────────────┐
│ ~/.gitconfig            (defaults + routing)                         │
│   user.useConfigOnly = true  ← fails commits w/o email               │
│   gpg.format = ssh / commit.gpgsign = true                           │
│   includeIf "gitdir:~/Code<identity>/"    → .gitconfig-<identity>    │
│   includeIf "gitdir:~/CodeWork/"    → .gitconfig-work                │
├──────────────────────────────────────────────────────────────────────┤
│ ~/.gitconfig-<id>       (per-identity overrides)                     │
│   user.name / user.email / user.signingKey                           │
│   core.sshCommand → pins the auth key                                │
│   url.<alias>.insteadOf → rewrites plain github.com                  │
├──────────────────────────────────────────────────────────────────────┤
│ ~/.ssh/config           (Host aliases per identity)                  │
│   Host github.com-<id>                                               │
│     IdentityFile ~/.ssh/id_ed25519_<id>_auth.pub                     │
│     IdentitiesOnly yes                                               │
└──────────────────────────────────────────────────────────────────────┘

               ┌──────────────┐
               │  1Password   │ ← private keys, biometric unlock
               └──────┬───────┘
                      │  SSH_AUTH_SOCK   (auto-wired by identities.sh)
                      ▼
             ssh / ssh-keygen  (sees only .pub files → asks agent to sign)
```

**The `.pub` files on disk are handles, not secrets.** The private halves
stay inside 1Password. OpenSSH resolves the private key through the agent
when it sees the matching public key.

---

## Module layout

```
git_setup/identities/
├── README.md                       ← this file
├── identities.sh                   ← sourced from .bash_profile (helpers + agent wiring)
├── bootstrap.sh                    ← one call per identity; idempotent
├── lib/
│   ├── _pubkey.sh                  ← validate blob, fingerprint, atomic write
│   ├── _fenced_block.sh            ← idempotent fenced-block upsert/remove
│   └── _allowed_signers.sh         ← upsert/remove allowed_signers line
└── templates/
    ├── gitconfig-global.tmpl       ← seeded ONCE into ~/.gitconfig
    ├── gitconfig-identity.tmpl     ← rendered per identity into ~/.gitconfig-<id>
    └── ssh-config-identity.tmpl    ← rendered per identity, appended to ~/.ssh/config
```

---

## One-time prerequisites (per identity, manual in 1Password)

Do this **once per identity** in the 1Password app before running
`bootstrap.sh`:

1. **New item → SSH Key → Ed25519** — name it e.g. `GitHub · <identity> · auth`.
   This will be the **authentication** key.
2. **New item → SSH Key → Ed25519** — name it e.g. `GitHub · <identity> · sign`.
   This will be the **signing** key.
3. Open 1Password → **Settings → Developer** → enable
   *"Use the SSH agent"* (if not already on).
4. On GitHub → **Settings → SSH and GPG keys → New SSH key**, upload:
   - the `auth` public key, choose **Key type: Authentication Key**
   - the `sign` public key, choose **Key type: Signing Key**
     *(critical — the default dropdown is Authentication)*

Keep each item's **public key** field open — you'll paste it into
`bootstrap.sh` in a moment.

---

## Usage

### Provision a new identity

```bash
git_identity_bootstrap \
  --id    <identity> \
  --dir   ~/Code<identity> \
  --name  "User Name" \
  --email "user@example.com" \
  --auth-pub "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA…user-auth" \
  --sign-pub "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA…user-sign"
```

Behaviour:
- Creates `~/Code<identity>/` if missing (never touched otherwise).
- Writes `~/.ssh/id_ed25519_<identity>_auth.pub` and `~/.ssh/id_ed25519_<identity>_sign.pub`
  (chmod 644), validated with `ssh-keygen -lf`.
- Seeds `~/.gitconfig` with the strict global defaults **only on first run**.
- Renders `~/.gitconfig-<identity>`.
- Appends fenced `[includeIf]` block to `~/.gitconfig`.
- Appends fenced `Host github.com-<identity>` block to `~/.ssh/config`.
- Upserts `user@example.com <ed25519 blob>` in `~/.ssh/allowed_signers`.
- Backs up every file it touches (keeps 3 most recent `.bak.<ts>`).
- Prints fingerprints for eyeball-verification against 1Password.

Idempotent: run the same command twice → no net change. Re-run with a
rotated key → only the places that reference it are updated.

### Preview changes without writing anything

```bash
git_identity_bootstrap --id <identity> --dir ~/Code<identity> \
  --name "User Name" --email "user@example.com" \
  --auth-pub "ssh-ed25519 …" --sign-pub "ssh-ed25519 …" \
  --dry-run
```

### Tear down an identity

```bash
git_identity_bootstrap \
  --id    <identity> \
  --dir   ~/Code<identity> \
  --name  "User Name" \
  --email "user@example.com" \
  --auth-pub "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA…user-auth" \
  --sign-pub "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA…user-sign" \
  --remove
```

Removes the fenced blocks, the `.pub` files, the `~/.gitconfig-<identity>`
file, and the `allowed_signers` line. **Never** deletes `~/Code<identity>` or
any repos inside it.

### Runtime helpers (always available, zero startup cost)

| Function | What it does |
|---|---|
| `git_whoami` | Prints the resolved identity for the current repo (`user.*`, `core.sshCommand`, remote URL). Warns on mismatches. |
| `git_clone_as <id> <owner/repo>` | `cd` to the identity root and clone using the correct host alias. |
| `git_identity_list` | Table of every identity currently configured. |
| `git_identity_doctor` | Walks every repo under every managed root, reports drift. Exit ≠ 0 on errors. |
| `git_identity_fix` | Rewrites the current repo's `origin` URL to use the identity host alias. |
| `git_identity_bootstrap …` | Thin wrapper around `bootstrap.sh` so you don't type the full path. |

---

## Verify end-to-end

```bash
# Auth works:
ssh -T git@github.com-<identity>        # "Hi <username>! You've successfully authenticated"

# Clone + use:
git_clone_as <identity> myuser/myrepo
cd ~/Code<identity>/myrepo
git_whoami                        # identity resolves; no warnings
git commit --allow-empty -m "test"
git log --show-signature          # Good "git" signature…
```

### Fingerprint cross-check

When `bootstrap.sh` finishes it prints, for each key:

```
  Auth pub          /Users/you/.ssh/id_ed25519_<identity>_auth.pub
                    SHA256:CzfgIvLLZkJV5DqYhcj5lNaFCdC1zpNpsAulHsJ7Hjw
```

That `SHA256:…` value **must** match the fingerprint field shown in the
corresponding 1Password item. If it doesn't, you pasted the wrong key.

---

## Fail-closed semantics

`~/.gitconfig` is seeded with `user.useConfigOnly = true`. Any repo
outside every `includeIf "gitdir:"` root will refuse to commit:

```
fatal: no email was given and auto-detection is disabled
```

That's the point. No silent mis-attribution — either the repo is inside
a managed root and the identity is unambiguous, or git stops and makes
you move the repo.

---

## Adding a new identity later

Exactly one `git_identity_bootstrap` call, no edits to existing files:

```bash
git_identity_bootstrap \
  --id <identity2> --dir ~/Code<identity2> \
  --name "User Two" --email "user2@example.com" \
  --auth-pub "ssh-ed25519 …<identity2>-auth" \
  --sign-pub "ssh-ed25519 …<identity2>-sign"
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `fatal: no email was given` on commit | repo lives outside every managed root | move the repo under the right `~/Code<Id>/`, or add a new identity for it |
| `git log --show-signature` → `No principal matched` | missing `allowed_signers` line | re-run `bootstrap.sh` for that identity |
| `ssh -T git@github.com-<identity>` → `Permission denied` | auth pub not uploaded to GitHub, or uploaded as "Signing Key" by mistake | re-upload as **Authentication Key** |
| Pushing as the wrong user | repo was cloned with plain `git@github.com:…` | `cd` into repo → `git_identity_fix` |
| `Load key "/Users/…/…_auth.pub": invalid format` | wrote the private key instead of public | re-paste the **public key** field from 1Password |
| `git_identity_doctor` prints `ERR email=… (expected …)` | someone ran `git config user.email <wrong>` locally in that repo | `git -C <repo> config --unset user.email` then re-open |
| 1Password prompts on every single `git` command | agent not picked up | check `echo "$SSH_AUTH_SOCK"` — should be the 1Password path; open a new shell |

### Useful one-liners

```bash
# Fingerprint of every pub file managed here:
for f in ~/.ssh/id_ed25519_*.pub; do ssh-keygen -lf "$f"; done

# Which identity does git think this repo belongs to?
cd <repo>; git config --show-origin user.email

# What keys does the agent expose?
ssh-add -l
```

---

## Design notes

- **Why `user.useConfigOnly = true` globally?** Strict fail-closed was an
  explicit requirement. The cost is that committing in `/tmp/scratch-repo`
  fails until you either move it under a managed root or set
  `user.email` locally — which is the correct pain-point to surface.
- **Why public-key file paths, not embedded strings, in gitconfig?**
  `user.signingKey` and `core.sshCommand -i` both want a filesystem
  path. 1Password cannot stream a key into a config file, but OpenSSH is
  perfectly happy being pointed at a `.pub` when the matching private
  key lives in the agent.
- **Why fenced blocks, not `git config --global --add`?** Re-running
  `git config --add includeIf …` appends duplicates. Fenced blocks make
  the file's managed region trivially replaceable, keeps the rest of the
  user's `~/.gitconfig` pristine, and makes `--remove` a line-surgery
  instead of "remember every `git config` call in reverse".
- **Why not use the `op` CLI?** Deliberate — reduces runtime deps.
  Copying the public key from the 1Password UI is already part of
  setting up a 1Password SSH item; adding the CLI just to re-fetch it
  buys us nothing. Rotation is a re-run of `bootstrap.sh`.
