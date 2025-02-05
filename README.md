# GIT REPOSITORIES MIGRATION

Bash script for migrating repositories with everything (branches, tags,..etc) from one git provider to another.

1. Grant the script execute permission
   ```sh
   chmod 755 repo-migration.sh
   ```
2. Provide the list of source repositories in a file called repos.txt
   ```sh
   cat > repos.txt
    repo1
    repo2
    repo3
   ```
3. Set the variables in the repo-migration.sh file
  ```sh
  # Configuration
  SOURCE_REPOS_ORG_URL="https://source.example.com/source-org/source-project"  # Replace with your source Azure Repos URL
  TARGET_REPOS_ORG_URL="https://target.example.com/target-org/target-project"  # Replace with your target Azure DevOps URL
  
  SOURCE_REPOS_PROJECT_PAT="source-repos-pat"  # Replace with your source PAT
  TARGET_REPOS_PROJECT_PAT="target-repos-pat"  # Replace with your target PAT
  
  WORKING_DIR="/tmp/repos_migration"  # Working directory for cloning repos
  
  TARGET_REPOS_PREFIX="bosstwo" # Common prefix all target repos have. Set to empty string if none
  REPOS_LIST_FILE="$1"  # Path to file containing list of source repos to mirror (one repo per line)
  SOURCE_REPOS=""
  ```

4. Execute the bash script
   ```sh
   ./repo-migration.sh repos.txt
   ```


