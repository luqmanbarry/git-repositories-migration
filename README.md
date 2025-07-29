# Git Repositories Migration

While preserving git history, this bash script migrates repositories including branches, tags, commit log, from one git organization to another. The script support code migration between git providers as well; for example: BitBucket to GitHub, Self hosted git server to Azure DevOps.

The script has logic to clean up files with certain extensions ([see script](./repo-migration.sh)); and files with sizes reaching a defined value, the default is 5 Megabytes (5M).

To enable Large File cleanup, set these two parameters (enabled by default):

- `large_file_cleanup.enable: true`: Set to true to enable the file cleanup, false for otherwise.
- `large_file_cleanup.file_size: 5M`: Set the large file size limit using this variable. The default is 5M.
- Files extensions are defined within the script, you can add or remove extensions per your needs.

## Pre-requisites

- Install Python >= 3.12.x (If running the Python script)
- Install Git
   - Instructions: `https://github.com/git-guides/install-git`
- Install yq
  - Instructions: `https://github.com/mikefarah/yq?tab=readme-ov-file#install`
- Install git-filter-repo package
   - Instructions: `https://github.com/newren/git-filter-repo/blob/main/INSTALL.md`
- Configure the Git credentials helper: `https://git-scm.com/docs/gitcredentials`
- Script works best on a native Linux distribution
   - If on Windows, the script does not work well with Git Bash; instead set up Windows Subsystem for Linux (WSL)
      - Configure Git: `https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-git`
- Configure git authentication for the source and target organizations; if configured properly, you should be able to clone from both git organizations without being prompted for credentials

## Procedure

1. Grant the script execute permission (If running the shell script)
   ```sh
   chmod 755 repo-migration.sh
   ```

2. Populate the [inputs.yaml](./inputs.yaml) file with your repositories information.
   
   ```yaml
   # Configuration - Set these variables in the inputs.yaml file before running the script
   inputs:
      source_project_url: https://github.com/project1
      destination_project_url: https://github.com/project2
      large_file_cleanup:
         enable: true # Set false disable
         file_size: 5M # Could be 1M, 2M, 3M, etc
      repositories:
         - source: my-src-repository1
            destination: my-dest-repository1
         - source: my-src-repository2
            destination: my-dest-repository2
         - source: my-src-repository3
            destination: my-dest-repository3
      
   ```

3. Execute the script

   ```sh
   ./repo-migration.sh 2>&1 | tee "repo-migrations-bash-$(date +%Y%m%d%H%M).log"
   ```

# Git large file size cleanup for a single repository

1. Run the bash script
   
   ```sh
   ./git-large-file-size-fix.sh <path_to_git_directory>
   # Example: If I am already in the git directory: ./git-large-file-size-fix.sh .
   ```

2. Commit and Push

   ```sh
   git commit -am "Resolved git large-file-size issues"
   git push
   ```

