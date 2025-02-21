# Git Repositories Migration

Bash script for migrating repositories with everything (branches, tags,..etc) from one git provider to another.

## Pre-requisites
- Install Git
   - Instructions: `https://git-scm.com/book/en/v2/Getting-Started-Installing-Git`   
- Install git-filter-repo package
   - Instructions: `https://github.com/newren/git-filter-repo/blob/main/INSTALL.md`
- Configure the Git credentials helper: `https://git-scm.com/docs/gitcredentials`
- Script works best on a native Linux distribution
   - If on Windows, the script does not work well with Git Bash; instead set up Windows Subsystem for Linux (WSL)
      - Configure Git: `https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-git`
- Git config file setup: `https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup`
- Generate project-scoped PAT tokens for source and target repos

## Procedure

1. Grant the script execute permission
   ```sh
   chmod 755 repo-migration.sh
   ```
2. Provide the list of source repositories in a file called repos.txt (add empty line at the end)
   ```sh
   cat > repos.txt << EOF
    repo1
    repo2
    repo3
   EOF
   ```
3. Set the variables in the repo-migration.sh file
   ```sh
   # Configuration - Set these variables before running the script
   # LEAVE OUT https://
   SOURCE_REPOS_ORG_URL="source.example.com/source-org/source-project"  # Replace with your source Azure Repos URL.
   # LEAVE OUT https://
   TARGET_REPOS_ORG_URL="target.example.com/target-org/target-project"  # Replace with your target Azure DevOps URL.
   SOURCE_REPOS_PROJECT_PAT=""  # Replace with your source PAT. Leave empty if you've already setup Git Credentials Helper for this url
   TARGET_REPOS_PROJECT_PAT=""  # Replace with your target PAT. Leave empty if you've already setup Git Credentials Helper for this url
   TARGET_REPOS_PREFIX="team-name"  # Common prefix all target repos have. Set to empty string if none
   CLEANUP_LARGE_FILES=true  # Set this flag to true if you want large files removed from git history
   LARGE_FILE_SIZE="5M"  # Potential values: 500K, 1M, 2M, 3M, 10M,..
   ```

4. Execute the bash script
   ```sh
   ./repo-migration.sh repos.txt 2>&1 | tee "repo-migrations-$(date +%Y%m%d%H%M).log"
   ```

