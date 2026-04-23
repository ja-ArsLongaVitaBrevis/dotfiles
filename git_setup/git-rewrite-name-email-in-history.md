Changing the email address for all past commits requires rewriting your repository's history. Because this changes the cryptographic hashes (SHAs) of every altered commit and all commits that come after them, **you should only do this if you are absolutely sure, and you will need to force-push the changes.** If you are working on a shared repository, coordinate with your team first, as they will need to re-clone the repository after you force-push.

Here is the standard, most reliable method using a `git filter-branch` script.

### Step 1: Create a fresh, bare clone of your repository
To ensure you don't mess up your current local workspace, it is highly recommended to perform this action on a fresh "bare" clone of your repository.

Open your terminal and run:
```bash
git clone --bare https://github.com/YourUsername/YourRepositoryName.git
cd YourRepositoryName.git
```

---

### Step 2: Run the script to rewrite history
Copy and paste the following script into your terminal. Before hitting Enter, **change the three variables at the top** (`OLD_EMAIL`, `CORRECT_NAME`, and `CORRECT_EMAIL`) to match your details.

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

**What this script does:**
* It goes through every commit and tag in your history.
* It checks if the Author or Committer email matches the `OLD_EMAIL`.
* If it finds a match, it replaces both the name and the email with the `CORRECT_NAME` and `CORRECT_EMAIL`.

*(Note: Git may display a warning that `filter-branch` is deprecated and suggest using `git-filter-repo`. You can safely ignore this warning for this specific, simple task.)*

---

### Step 3: Review the new history
You can verify that the script worked by checking the Git log. Since it's a bare repository, use this command:
```bash
git log --format="%an <%ae>" | head -n 10
```
This will print the author name and email of the last 10 commits. Ensure your new email is showing up correctly.

---

### Step 4: Force-push the corrected history to GitHub
Once you are satisfied that the emails have been updated, you must force-push the rewritten history and tags back to your remote repository.

```bash
git push --force --tags origin 'refs/heads/*'
```

---

### Step 5: Clean up
Because you created a temporary bare clone to perform this operation safely, you can now delete that folder from your computer. 

Go back to your regular, working local repository. Because the history has been completely rewritten on the remote, **do not pull** the changes. Instead, delete your old local repository and clone the fresh, updated one from GitHub:

```bash
cd ..
rm -rf YourRepositoryName.git  # Deletes the temporary bare clone
git clone https://github.com/YourUsername/YourRepositoryName.git
```

Your repository is now successfully updated with the correct email addresses.