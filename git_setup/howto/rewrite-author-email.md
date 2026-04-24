> Back to → [git_setup](../README.md) · [dotfiles root](../../README.md)

# Rewrite author email across an entire repository's history

Changing the email address for all past commits requires **rewriting your repository's history**. Because this changes the cryptographic hashes (SHAs) of every altered commit, **you should only do this if you are absolutely sure**. You will need to force-push the changes.

If you are working on a shared repository, coordinate with your team first — they will need to re-clone after you force-push.

---

### Step 1: Create a fresh bare clone

To avoid touching your current local workspace, perform this on a temporary bare clone:

```bash
git clone --bare https://github.com/YourUsername/YourRepositoryName.git
cd YourRepositoryName.git
```

---

### Step 2: Run the filter script

Change the three variables at the top before hitting Enter:

```bash
git filter-branch --env-filter '
OLD_EMAIL="your_old@email.com"
CORRECT_NAME="User Name"
CORRECT_EMAIL="user@example.com"

if [ "$GIT_COMMITTER_EMAIL" = "$OLD_EMAIL" ]
then
    export GIT_COMMITTER_NAME="$CORRECT_NAME"
    export GIT_COMMITTER_EMAIL="$CORRECT_EMAIL"
fi
if [ "$GIT_AUTHOR_EMAIL" = "$OLD_EMAIL" ]
then
    export GIT_AUTHOR_NAME="$CORRECT_NAME"
    export GIT_AUTHOR_EMAIL="$CORRECT_EMAIL"
fi
' --tag-name-filter cat -- --branches --tags
```

What this does: walks every commit and tag; wherever the author or committer email matches `OLD_EMAIL`, it overwrites both name and email with the correct values.

> Git may warn that `filter-branch` is deprecated and suggest `git-filter-repo`. You can safely ignore this warning for this specific, simple task.

---

### Step 3: Review the new history

```bash
git log --format="%an <%ae>" | head -n 10
```

Verify your corrected email appears on recent commits.

---

### Step 4: Force-push to GitHub

```bash
git push --force --tags origin 'refs/heads/*'
```

---

### Step 5: Clean up

Delete the bare clone and re-clone from the remote.  
**Do not `git pull` into your old local copy** — the history has been rewritten and can no longer be cleanly merged.

```bash
cd ..
rm -rf YourRepositoryName.git          # delete the temporary bare clone
git clone https://github.com/YourUsername/YourRepositoryName.git
```

Your repository now has the correct email addresses throughout its history.
