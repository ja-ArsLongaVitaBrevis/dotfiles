> **⚡ Multi-identity? Use [`identities/`](./identities/README.md) instead.**
> If you work with more than one git user on this machine (personal + work,
> multiple GitHub accounts, …) the steps below are the single-identity
> primer. For the automated, directory-scoped, 1Password-backed setup —
> one shell command per identity — see
> [`git_setup/identities/README.md`](./identities/README.md).

---

Setting up a key to sign your commits used to be a notoriously frustrating process with GPG. Fortunately, GitHub now allows you to sign commits using **SSH keys**, which is significantly easier to set up and manage. 

Here is the step-by-step process to generate an SSH key, add it to GitHub, and tell Git to use it for signing.

### Step 1: Generate a new SSH key
- Create a SSh key with 1password


### Step 2: Add the public key to GitHub
You need to give GitHub the "public" half of your key so it can verify your signatures.

**1. Copy your public key to your clipboard:**
* **Mac:** `pbcopy < ~/.ssh/id_ed25519.pub`
* **Windows:** `clip < ~/.ssh/id_ed25519.pub`
* **Linux:** `xclip -sel clip < ~/.ssh/id_ed25519.pub` (or just `cat ~/.ssh/id_ed25519.pub` and copy it manually).

**2. Add it to GitHub:**
* Go to GitHub and click your profile picture in the top right, then select **Settings**.
* In the left sidebar, click **SSH and GPG keys**.
* Click the green **New SSH key** button.
* Give it a Title (e.g., "Personal Laptop Signing Key").
* **CRITICAL:** Change the "Key type" dropdown from *Authentication Key* to **Signing Key**.
* Paste your key into the "Key" box and click **Add SSH key**.

### Step 3: Configure Git to use the key for signing
Now you need to tell your local Git installation to use SSH for signing, and point it to the exact key.

Run these commands in your terminal one by one:

**1. Tell Git to use SSH for signatures (instead of GPG):**
```bash
git config --global gpg.format ssh
```

**2. Tell Git which SSH key to use:**
*(If you saved your key somewhere other than the default, update this path)*
```bash
git config --global user.signingkey ~/.ssh/id_ed25519.pub
```

**3. (Optional but recommended) Tell Git to automatically sign all future commits:**
```bash
git config --global commit.gpgsign true
```

### Step 4: Create an `allowed_signers` file (Prevents local errors)
When you use SSH to sign, Git needs a local file to map email addresses to public keys so it can verify signatures on your own machine. Without this, GitHub will show "Verified", but running `git log --show-signature` locally will throw an error.

**1. Create the file:**
```bash
touch ~/.ssh/allowed_signers
```

**2. Tell Git where this file is:**
```bash
git config --global gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers
```

**3. Add your public key and email to the file:**
*(Replace the email with your GitHub email)*
```bash
echo "your_email@example.com $(cat ~/.ssh/id_ed25519.pub)" >> ~/.ssh/allowed_signers
```

You are completely set up! Any new commits you make (or any history you rewrite using the `git rebase` command from earlier) will now be signed with your SSH key and show up as **Verified** on GitHub.