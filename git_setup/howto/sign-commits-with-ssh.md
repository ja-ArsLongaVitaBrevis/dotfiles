> **⚡ Multi-identity? Use [`identities/`](../identities/README.md) instead.**
> If you work with more than one git user on this machine (personal + work,
> multiple GitHub accounts, …) the steps below are the single-identity
> primer. For the automated, directory-scoped, 1Password-backed setup —
> one shell command per identity — see
> [`git_setup/identities/README.md`](../identities/README.md).
>
> Back to → [git_setup](../README.md) · [dotfiles root](../../README.md)

---

# Sign commits with an SSH key

Setting up a key to sign your commits used to be a notoriously frustrating process with GPG. Fortunately, GitHub now allows you to sign commits using **SSH keys**, which is significantly easier to set up and manage.

Here is the step-by-step process to generate an SSH key, add it to GitHub, and tell Git to use it for signing.

---

### Step 1: Generate a new SSH key

Create an SSH key with 1Password:

1. Open 1Password → **New item → SSH Key → Ed25519**.
2. Name it e.g. `GitHub · <identity> · sign`.

---

### Step 2: Add the public key to GitHub

You need to give GitHub the "public" half of your key so it can verify your signatures.

**1. Copy your public key to your clipboard:**

```bash
pbcopy < ~/.ssh/id_ed25519.pub      # macOS
```

**2. Add it to GitHub:**

- Go to **GitHub → Settings → SSH and GPG keys → New SSH key**.
- Give it a title (e.g. "Personal Laptop Signing Key").
- **CRITICAL:** Change the "Key type" dropdown from *Authentication Key* to **Signing Key**.
- Paste your key and click **Add SSH key**.

---

### Step 3: Configure Git to use the key for signing

```bash
# Tell Git to use SSH for signatures (instead of GPG):
git config --global gpg.format ssh

# Tell Git which SSH key to use:
git config --global user.signingkey ~/.ssh/id_ed25519.pub

# (Optional but recommended) Auto-sign all future commits:
git config --global commit.gpgsign true
```

---

### Step 4: Create an `allowed_signers` file

Git needs a local file to map email addresses to public keys so it can verify signatures on your own machine. Without this, GitHub shows "Verified", but running `git log --show-signature` locally throws an error.

```bash
# Create the file:
touch ~/.ssh/allowed_signers

# Tell Git where it lives:
git config --global gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers

# Add your key (replace the email with your GitHub email):
echo "your_email@example.com $(cat ~/.ssh/id_ed25519.pub)" >> ~/.ssh/allowed_signers
```

You are fully set up. Any new commits (or history rewritten with `git rebase`) will be signed with your SSH key and show as **Verified** on GitHub.
