#!/bin/bash
set +e
set -x

# Place the inputs.yaml file in the same directory as the bash script.

# Configuration - Set these variables in the inputs.yaml file before running the script
INPUT_YAML_FILE="inputs.yaml"
if [ -f "$INPUT_YAML_FILE" ]; then
  echo "File '$INPUT_YAML_FILE' exists and is a regular file."
else
  echo "File '$INPUT_YAML_FILE' does not exist or is not a regular file."
fi

if [ ! -s "$INPUT_YAML_FILE" ]; then
  echo "The file '$INPUT_YAML_FILE' is empty or does not exist."
else
  echo "The file '$INPUT_YAML_FILE' exists and is not empty."
fi

SOURCE_REPOS_ORG_URL="$(yq e '.inputs.source_project_url' $INPUT_YAML_FILE)"
TARGET_REPOS_ORG_URL="$(yq e '.inputs.destination_project_url' $INPUT_YAML_FILE)"
CLEANUP_LARGE_FILES="$(yq e '.inputs.large_file_cleanup.enable' $INPUT_YAML_FILE)"
LARGE_FILE_SIZE="$(yq e '.inputs.large_file_cleanup.file_size' $INPUT_YAML_FILE)"


CURRENT_DIR="$(pwd)"  # Current working directory
WORKING_DIR="${CURRENT_DIR}/repo_migration/runs_$(date +%Y%m%d%H)"  # Working directory for cloning repos
REPORTS_DIR="${CURRENT_DIR}/migration_reports/${TARGET_REPOS_PREFIX:- }"  # Directory where reports files will be stored
PATCH_FILE="${WORKING_DIR}/source-state.patch"  # Patch file for merging source and target branches
SUCCEEDED_REPORT_FILE="${REPORTS_DIR}/succeeded-migrations.csv"  # Succeeded code migrations report
FAILED_REPORT_FILE="${REPORTS_DIR}/failed-migrations.csv"  # Failed code migrations report
REPOS_LIST="$(yq '.inputs.repositories' )"
SOURCE_REPOS=""

# Create directories tree and files
mkdir -p "${WORKING_DIR}"
mkdir -p "${REPORTS_DIR}"

# Prepare the report headers
echo "source_repo_url, source_repo, source_branch, target_repo_url, target_repo" > "${SUCCEEDED_REPORT_FILE}"
echo "source_repo_url, source_repo, source_branch, target_repo_url, target_repo" > "${FAILED_REPORT_FILE}"


if [  ! -z "${REPOS_LIST}" ];
then
  # SOURCE_REPOS=$(<$REPOS_LIST_FILE)
  for REPO in $REPOS_LIST;
  do
    SRC_REPO_NAME=$(echo $REPO | yq .source | tr -d '\r' |  tr -d '\n' | xargs)
    DEST_REPO_NAME=$(echo $REPO | yq .destination | tr -d '\r' |  tr -d '\n' | xargs)

    if [ -z "$SRC_REPO_NAME" ] || [ -z "$DEST_REPO_NAME" ];
    then
      echo "One of Source ("$SRC_REPO_NAME") and/or destination ("$DEST_REPO_NAME") repository entries is empty."
      exit 1
    fi

    SOURCE_REPO_URL="${SOURCE_REPOS_ORG_URL}/${SRC_REPO_NAME}"
    if [[ "$SOURCE_REPOS_ORG_URL" == *"dev.azure.com"* ]]; then
      SOURCE_REPO_URL="${SOURCE_REPOS_ORG_URL}/_git/${SRC_REPO_NAME}"
    fi

    TARGET_REPO_URL="${TARGET_REPOS_ORG_URL}/${DEST_REPO_NAME}"
    if [[ "$TARGET_REPOS_ORG_URL" == *"dev.azure.com"* ]]; then
      TARGET_REPO_URL="${TARGET_REPOS_ORG_URL}/_git/${DEST_REPO_NAME}"
    fi

    echo "==> Migrating repository: $SOURCE_REPO_URL"
    
    cd "${WORKING_DIR}"
    echo "==> Clone the source repository with all branches and tags..."
    git clone "${SOURCE_REPO_URL}" || true && echo "REPO exists already"

    cd "${SRC_REPO_NAME}"
    echo "==> Set source remote url to repo..."
    git remote add source ${SOURCE_REPO_URL}

    # Fetch all branches and tags from the source remote
    echo "==> Fetching all branches and tags from ${SOURCE_REPO_URL}..."
    git fetch source --tags

    echo "==> Get a list of all branches in the source remote..."
    SOURCE_BRANCHES=$(git branch -r | grep "source/" | sed "s/source\///" | grep -v "HEAD")
    echo $SOURCE_BRANCHES


    echo "==> Set target remote url to repo..."
    git remote add target ${TARGET_REPO_URL}
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


        echo "===> Save the source state to a patch file"
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

            echo "====> Verify the repository .git log size"
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

  done
 
else
  echo "=> Repos list file must be provided as input to the script."
  echo "=> Example: ./repo-migration.sh source-repos.txt"
  exit 1
fi

echo "=> Migration completed!"
echo "=> Check the reports files in: ${REPORTS_DIR}"
echo "=> 'SUCCEEDED' migrations report file: ${SUCCEEDED_REPORT_FILE}"
echo "=> 'FAILED' migrations report file: ${FAILED_REPORT_FILE}"
