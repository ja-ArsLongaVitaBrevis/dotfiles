To get the "Verified" badge on your commits in GitHub, you need to sign them using a GPG, SSH, or S/MIME key. 

Just like changing your email address, **signing past commits requires rewriting your repository's history**. This will change the cryptographic hashes (SHAs) of every commit, so you will need to force-push. Be cautious if you are collaborating with others.

Here is how to sign your entire commit history for a branch.

### Prerequisite: You must have a signing key configured
Before you begin, you must already have a GPG or SSH key generated, told Git to use it, and uploaded the public key to your GitHub account settings. 
* To check if Git is configured to sign, run: `git config --get user.signingkey`
* If nothing shows up, you need to set up a GPG or SSH key with GitHub first.

---

### Step 1: Rewrite history to sign all commits
Open your terminal, navigate to your local repository, and make sure you are on the branch you want to sign (e.g., `main`).

Run the following command:
```bash
git rebase --root --exec "git commit --amend --no-edit -n -S"
```

**What this command does:**
* `--root`: Tells Git to start rebasing from the very first commit in your history.
* `--exec`: Executes the following command for every single commit.
* `git commit --amend`: Modifies the commit.
* `--no-edit`: Keeps the exact same commit message.
* `-n`: Skips any pre-commit hooks you might have (saves time and prevents errors).
* `-S`: Adds your cryptographic signature to the commit.

*(Note: Depending on your GPG/SSH setup, you might be prompted to enter your key's passphrase. If you have a massive repository, this process might take a minute or two.)*

---

### Step 2: Verify the signatures locally
Before pushing, it's a good idea to check if the commits were successfully signed. Run:
```bash
git log --show-signature -n 5
```
You should see a message like `Good signature from "Your Name <your@email.com>"` on your recent commits.

---

### Step 3: Force-push to GitHub
Because you altered the history to attach the signatures, your local branch and the remote branch have completely diverged. You must force-push to overwrite the remote history.

```bash
git push --force origin main
```
*(If your branch is named `master` or something else, replace `main` accordingly).*

### Note on Multiple Branches
The `git rebase` command above only rewrites the history for the **current branch**. If you have multiple branches (like `develop`, `feature-x`, etc.) that you also want to mark as verified, you will need to check out each branch individually and run the rebase and force-push commands again.