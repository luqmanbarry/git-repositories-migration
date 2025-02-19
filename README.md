# Git Repositories Migration

Bash script for migrating repositories with everything (branches, tags,..etc) from one git provider to another.

## Pre-requisites
- Configure the Git credentials helper: `https://git-scm.com/docs/gitcredentials`
- Script works best on a native Linux distribution
   - If on Windows, the script does not work well with Git Bash; instead set up Windows Subsystem for Linux (WSL)
      - Configure Git: `https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-git`
- Git config file setup: `https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup`
- Generate project scoped PAT tokens for source and target repos

## Procedure

1. Grant the script execute permission
   ```sh
   chmod 755 repo-migration.sh
   ```
2. Provide the list of source repositories in a file called repos.txt
   ```sh
   cat > repos.txt << EOF
    repo1
    repo2
    repo3
   EOF
   ```
3. Set the variables in the repo-migration.sh file
  ```sh
   # Configuration
   SOURCE_REPOS_ORG_URL="https://source.example.com/source-org/source-project"  # Replace with your source Azure Repos URL
   TARGET_REPOS_ORG_URL="https://target.example.com/target-org/target-project"  # Replace with your target Azure DevOps URL

   SOURCE_REPOS_PROJECT_PAT="source-repos-pat"  # Replace with your source PAT
   TARGET_REPOS_PROJECT_PAT="target-repos-pat"  # Replace with your target PAT
   TARGET_REPOS_PREFIX="team-name" # Common prefix all target repos have. Set to empty string if none
  ```

4. Execute the bash script
   ```sh
   ./repo-migration.sh repos.txt | tee "$(date +%Y%m%d%H%M)-repo-migrations.log"
   ```

