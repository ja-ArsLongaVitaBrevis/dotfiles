> Back to → [git_setup](../README.md) · [dotfiles root](../../README.md)

# Sign past commits (add the Verified badge retroactively)

To get the "Verified" badge on your commits in GitHub you need to sign them using a GPG, SSH, or S/MIME key.

**Signing past commits requires rewriting your repository's history.** This changes the cryptographic hashes (SHAs) of every commit, so you will need to force-push. Be cautious if you are collaborating with others.

### Prerequisite: configure a signing key first

Before you begin you must have an SSH (or GPG) key generated, configured in Git, and uploaded to your GitHub account settings.

```bash
# Check whether Git is already set up to sign:
git config --get user.signingkey
```

If nothing shows up, follow [sign-commits-with-ssh.md](./sign-commits-with-ssh.md) first.

---

### Step 1: Rewrite history to sign all commits

Navigate to your local repository and check out the branch you want to sign (e.g. `main`).

```bash
git rebase --root --exec "git commit --amend --no-edit -n -S"
```

What each flag does:

| Flag | Meaning |
|---|---|
| `--root` | Start from the very first commit |
| `--exec` | Execute the following command for every commit |
| `--amend` | Modify the existing commit |
| `--no-edit` | Keep the original commit message unchanged |
| `-n` | Skip pre-commit hooks (faster, avoids false errors) |
| `-S` | Attach your cryptographic signature |

> Depending on your SSH agent setup you may be prompted once for a biometric / passphrase. For large repositories this may take a minute or two.

---

### Step 2: Verify the signatures locally

```bash
git log --show-signature -n 5
```

You should see `Good "git" signature for …` on recent commits.

---

### Step 3: Force-push to GitHub

Because the commit SHAs have changed your local branch has diverged from the remote. Force-push to overwrite:

```bash
git push --force origin main
```

Replace `main` with your branch name if different.

---

### Note on multiple branches

The command above only rewrites the current branch. For each additional branch (`develop`, `feature-x`, …) check it out and repeat steps 1–3.
