#!/bin/bash
set +e
set -x
## ALL GIT REPOS URLS INCLUDE "_git", THIS IS AZURE SPECIFIC
## REMOVE THE SUBSTRING (_git) IF IT DOES NOT APPLY TO YOU

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


CURRENT_DIR="$(pwd)"  # Current working directory
WORKING_DIR="${CURRENT_DIR}/repo_migration_$(date +%Y%m%d%H)"  # Working directory for cloning repos
REPORTS_DIR="${CURRENT_DIR}/migration_reports/${TARGET_REPOS_PREFIX:- }"  # Directory where reports files will be stored
PATCH_FILE="${WORKING_DIR}/source-state.patch"  # Patch file for merging source and target branches
SUCCEEDED_REPORT_FILE="${REPORTS_DIR}/succeeded-migrations.csv"  # Succeeded code migrations report
FAILED_REPORT_FILE="${REPORTS_DIR}/failed-migrations.csv"  # Failed code migrations report

REPOS_LIST_FILE="$1"  # Path to file containing list of source repos to mirror (one repo per line)
SOURCE_REPOS=""

# Create directories tree and files
mkdir -p "${WORKING_DIR}"
mkdir -p "${REPORTS_DIR}"

# Prepare the report headers
echo "source_repo_url, source_repo, source_branch, target_repo_url, target_repo" > "${SUCCEEDED_REPORT_FILE}"
echo "source_repo_url, source_repo, source_branch, target_repo_url, target_repo" > "${FAILED_REPORT_FILE}"


if [  ! -z "${REPOS_LIST_FILE}" -a -f "${REPOS_LIST_FILE}" -a -r "${REPOS_LIST_FILE}" ];
then
  # SOURCE_REPOS=$(<$REPOS_LIST_FILE)
  while SOURCE_REPOS= read -r line; do
    echo $line
    REPO=$(echo "$line" | tr -d '\r' |  tr -d '\n' | xargs)
    if [ ! -z "$REPO" ];
    then
      echo "==> Migrating repository: $REPO"

      SOURCE_REPO_URL="${SOURCE_REPOS_ORG_URL}/_git/${REPO}"
      if [ -z "${SOURCE_REPOS_PROJECT_PAT}" ];
      then
        SOURCE_REPO_URL_PAT="https://${SOURCE_REPOS_ORG_URL}/_git/${REPO}"
      else
        SOURCE_REPO_URL_PAT="https://${SOURCE_REPOS_PROJECT_PAT}@${SOURCE_REPOS_ORG_URL}/_git/${REPO}"
      fi 
      echo $SOURCE_REPO_URL_PAT
      
      cd "${WORKING_DIR}"
      echo "==> Clone the source repository with all branches and tags..."
      export GIT_PAT="$SOURCE_REPOS_PROJECT_PAT"
      export GIT_TOKEN="$SOURCE_REPOS_PROJECT_PAT"
      git clone  "${SOURCE_REPO_URL_PAT}" || true && echo "REPO exists already"

      # git tfs clone ${SOURCE_REPOS_ORG_URL} "\$/$REPO" ./${REPO} --branches=all
      cd "${REPO}"
      echo "==> Set source remote url to repo..."
      git remote add source ${SOURCE_REPO_URL_PAT}

      # Fetch all branches and tags from the source remote
      echo "==> Fetching all branches and tags from ${SOURCE_REPO_URL}..."
      git fetch source --tags

      echo "==> Get a list of all branches in the source remote..."
      SOURCE_BRANCHES=$(git branch -r | grep "source/" | sed "s/source\///" | grep -v "HEAD")
      echo $SOURCE_BRANCHES


      TARGET_REPO_URL=""
      TARGET_REPO_URL_PAT=""

      if [ -z "${TARGET_REPOS_PREFIX}" ];
      then
        TARGET_REPO="${REPO}"
        TARGET_REPO_URL="${TARGET_REPOS_ORG_URL}/_git/${TARGET_REPO}"

        if [ -z "${TARGET_REPOS_PROJECT_PAT}" ];
        then
          TARGET_REPO_URL_PAT="https://${TARGET_REPOS_ORG_URL}/_git/${TARGET_REPO}"
        else
          TARGET_REPO_URL_PAT="https://${TARGET_REPOS_PROJECT_PAT}@${TARGET_REPOS_ORG_URL}/_git/${TARGET_REPO}"
        fi
        
      else
        TARGET_REPO="${TARGET_REPOS_PREFIX}-${REPO}"
        TARGET_REPO_URL="${TARGET_REPOS_ORG_URL}/_git/${TARGET_REPO}"

        if [ -z "${TARGET_REPOS_PROJECT_PAT}" ];
        then
          TARGET_REPO_URL_PAT="${TARGET_REPOS_ORG_URL}/_git/${TARGET_REPO}"
        else
          TARGET_REPO_URL_PAT="https://${TARGET_REPOS_PROJECT_PAT}@${TARGET_REPOS_ORG_URL}/_git/${TARGET_REPO}"
        fi


      fi
      echo "==> Set target remote url to repo..."
      git remote add target ${TARGET_REPO_URL_PAT}
      # Copy individual branches from source to destination
      SOURCE_BRANCHES=($SOURCE_BRANCHES)
      echo ${SOURCE_BRANCHES[@]}

      for BRANCH in "${SOURCE_BRANCHES[@]}"; do
          echo "===> Copying branch ${BRANCH}..."
          BRANCH=$(echo $BRANCH | xargs)
          echo "===> Checkout the branch from the source remote"
          git checkout -b "${BRANCH}" source/${BRANCH} || true
        
          git fetch 
          git pull source ${BRANCH}


          echo "===> Save the source state to patch file"
          git diff HEAD > "${PATCH_FILE}"

          git push -u target ${BRANCH}
          
          if [ "$?" == "0" ];
          then
            echo "===> No resolutions for branch '${BRANCH}'."
            # Write succeeded report
            echo "${SOURCE_REPO_URL}, ${REPO}, ${BRANCH}, ${TARGET_REPO_URL}, ${TARGET_REPO}" >> "${SUCCEEDED_REPORT_FILE}"
          else
            if [ "$CLEANUP_LARGE_FILES" == "true" ];
            then
            
              if git filter-repo --version &> /dev/null; then
                echo "==> git filter-repo is installed and working."
              else
                echo "==> git filter-repo is not installed or not working."
                echo "==> Find install instructions at this url: https://github.com/newren/git-filter-repo/blob/main/INSTALL.md"
                exit 1
              fi
              
              echo "===> Cleaning up binary files from the git log..."
              echo "~~~> Repository size BEFORE cleanup: $(du -sh .)"

              echo "====> Repack the repository"
              git repack -a -d --depth=300 --window=300

              echo "====> Remove files with binary extensions from git history"
              git filter-repo \
                --path-glob '*.zip' \
                --path-glob '*.xls' \
                --path-glob '*.tar' \
                --path-glob '*.jar' \
                --path-glob '*.gz' \
                --path-glob '*.mov' \
                --path-glob '*.avi' \
                --path-glob '*.iso' \
                --path-glob '*.msi' \
                --path-glob '*.mp4' \
                --path-glob '*.war' \
                --path-glob '*.exe' \
                --path-glob '*.dll' \
                --path-glob '*.deb' \
                --path-glob '*.vob' \
                --path-glob '*.odt' \
                --path-glob '*.docx' \
                --path-glob '*.doc' \
                --path-glob '*.tgz' \
                --path-glob '*.rar' \
                --path-glob '*.bz2' \
                --path-glob '*.bzip2' \
                --path-glob '*.7z' \
                --path-glob '*.pptx' \
                --path-glob '*.xlsm' \
                --path-glob '*.xlsb' \
                --path-glob '*.xltx' \
                --path-glob '*.xlsx' \
                --path-glob '*.pkg' \
                --path-glob '*.rpm' \
                --path-glob '*.tar.gz' \
                --path-glob '*.dmg' \
                --path-glob '*.bin' \
                --path-glob 'node_modules/**' \
                --path-glob '**/node_modules/**' \
                --invert-paths \
                --force

              echo "====> Remove large files from history. Example: 1M, 5M, 10M"
              git filter-repo \
                --strip-blobs-bigger-than $LARGE_FILE_SIZE \
                --invert-paths \
                --force

              echo "====> Clean up the repository"
              git gc --aggressive --prune=now

              echo "====> Verify the repository size"
              du -sh .git
              echo "~~~> Repository size AFTER cleanup: $(du -sh .)"
              git commit -am "Repo Migration: Removed binary files."
              git push target ${BRANCH}
            fi
            echo "===> Conflict resolution for branch '${BRANCH}' failed. Check the ${FAILED_REPORT_FILE} file"
            echo "===> Reset to latest from target remote branch"
            git fetch target ${BRANCH}
            git reset --hard "target/${BRANCH}"

            echo "===> Applying source state patch file..."
            git apply "${PATCH_FILE}"
            git commit -am "Repo Migration: Merged source and target branches."
          
            git push target ${BRANCH}
            if [ "$?" != "0" ];
            then
              # Write failed report
              echo "${SOURCE_REPO_URL}, ${REPO}, ${BRANCH}, ${TARGET_REPO_URL}, ${TARGET_REPO}" >> "${FAILED_REPORT_FILE}"
            else
              echo "===> No resolutions for branch '${BRANCH}'."
              # Write succeeded report
              echo "${SOURCE_REPO_URL}, ${REPO}, ${BRANCH}, ${TARGET_REPO_URL}, ${TARGET_REPO}" >> "${SUCCEEDED_REPORT_FILE}"
            fi
          fi
      done

      echo "==> Copying tags from source to target..."
      git push target --tags
    fi

  done < $REPOS_LIST_FILE
 
else
  echo "=> Repos list file must be provided as input to the script."
  echo "=> Example: ./repo-migration.sh source-repos.txt"
  exit 1
fi

echo "=> Migration completed!"
echo "=> Check the reports files in: ${REPORTS_DIR}"
echo "=> 'SUCCEEDED' migrations report file: ${SUCCEEDED_REPORT_FILE}"
echo "=> 'FAILED' migrations report file: ${FAILED_REPORT_FILE}"
