#!/bin/bash

## ALL GIT REPOS URLS INCLUDE "_git", THIS IS AZURE SPECIFIC
## REMOVE THE SUBSTRING (_git) IF IT DOES NOT APPLY TO YOU

# Configuration
SOURCE_REPOS_ORG_URL="https://source.example.com/source-org/source-project"  # Replace with your source Azure Repos URL
TARGET_REPOS_ORG_URL="https://target.example.com/target-org/target-project"  # Replace with your target Azure DevOps URL

SOURCE_REPOS_PROJECT_PAT="source-repos-pat"  # Replace with your source PAT
TARGET_REPOS_PROJECT_PAT="target-repos-pat"  # Replace with your target PAT

CURRENT_DIR="$(pwd)"  # Current working directory
WORKING_DIR="/${CURRENT_DIR}/repos_migration"  # Working directory for cloning repos
REPORTS_DIR="/${CURRENT_DIR}/migration_reports"  # Directory where reports files will be stored
PATCH_FILE="${WORKING_DIR}/source-state.patch"  # Patch file for merging source and target branches
SUCCEEDED_REPORT_FILE="${REPORTS_DIR}/succeeded-migrations.csv"  # Succeeded code migrations report
FAILED_REPORT_FILE="${REPORTS_DIR}/failed-migrations.csv"  # Failed code migrations report

TARGET_REPOS_PREFIX="team-name" # Common prefix all target repos have. Set to empty string if none
REPOS_LIST_FILE="$1"  # Path to file containing list of source repos to mirror (one repo per line)
SOURCE_REPOS=""

# Create directories tree and files
mkdir -p "${WORKING_DIR}"
mkdir -p "${REPORTS_DIR}"

# Prepare the report headers
echo "source_repo_url, source_repo, source_branch, target_repo_url, target_repo" > "${SUCCEEDED_REPORT_FILE}"
echo "source_repo_url, source_repo, source_branch, target_repo_url, target_repo" > "${FAILED_REPORT_FILE}"

cd "${WORKING_DIR}"

if [ ! -z "${REPOS_LIST_FILE}" -a -f "${REPOS_LIST_FILE}" -a -r "${REPOS_LIST_FILE}" ];
then
  SOURCE_REPOS=$(cat $REPOS_LIST_FILE)
  echo "=> Top N repos provided: "
  echo $SOURCE_REPOS | head
else
  echo "=> Repos list file must be provided as input to the script."
  echo "=> Example: ./repo-migration.sh source-repos.txt"
  exit 1
fi

# Loop through each repository
for REPO in $SOURCE_REPOS; do
    echo "==> Migrating repository: $REPO"

    SOURCE_REPO_URL="${SOURCE_REPOS_ORG_URL}/_git/${REPO}"
    SOURCE_REPO_URL_PAT="https://${SOURCE_REPOS_PROJECT_PAT}@${SOURCE_REPOS_ORG_URL//https:///}/_git/${REPO}" "${REPO}"

    echo "==> Clone the source repository with all branches and tags..."
    git clone --mirror "${SOURCE_REPO_URL_PAT}"
    cd "${REPO}"
    echo "==> Set source remote url to repo..."
    git remote add source ${SOURCE_REPO_URL_PAT}

    # Fetch all branches and tags from the source remote
    echo "==> Fetching all branches and tags from ${SOURCE_REPO_URL}..."
    git fetch source --tags

    echo "==> Get a list of all branches in the source remote..."
    SOURCE_BRANCHES=$(git branch -r | grep "source/" | sed "s/source\///" | grep -v "HEAD")

    TARGET_REPO_URL=""
    TARGET_REPO_URL_PAT=""

    if [ -z "${TARGET_REPOS_PREFIX}" ];
    then
      TARGET_REPO="${REPO}"
      TARGET_REPO_URL="${TARGET_REPOS_ORG_URL}/_git/${TARGET_REPO}"
      TARGET_REPO_URL_PAT="https://${TARGET_REPOS_PROJECT_PAT}@${TARGET_REPOS_ORG_URL//https:///}/_git/${TARGET_REPO}"
    else
      TARGET_REPO="${TARGET_REPOS_PREFIX}-${REPO}"
      TARGET_REPO_URL="${TARGET_REPOS_ORG_URL}/_git/${TARGET_REPO}"
      TARGET_REPO_URL_PAT="https://${TARGET_REPOS_PROJECT_PAT}@${TARGET_REPOS_ORG_URL//https:///}/_git/${TARGET_REPO}"
    fi
    echo "==> Set target remote url to repo..."
    git remote add target ${TARGET_REPO_URL_PAT}

    # Copy individual branches from source to destination
    for BRANCH in "${SOURCE_BRANCHES}"; do
        echo "===> Copying branch ${BRANCH}..."

        echo "===> Checkout the branch from the source remote"
        git checkout -b ${BRANCH} "source/${BRANCH}"

        echo "===> Save the source state to patch file"
        git diff HEAD > "${PATCH_FILE}"

        echo "===> Reset to latest from target remote branch"
        git fetch target ${BRANCH}
        git reset --hard "target/${BRANCH}"

        echo "===> Applying source state patch file..."
        git apply "${PATCH_FILE}"

        if [ "$?" == "0" ];
        then
          echo "===> Conflict resolution for branch '${BRANCH}' completed."
          echo "===> Push the branch to the target remote"
          git commit -am "Repo Migration: Merged source and target branches."
          git push target ${BRANCH}

          # Write succeeded report
          echo "${SOURCE_REPO_URL}, ${REPO}, ${BRANCH}, ${TARGET_REPO_URL}, ${TARGET_REPO}" >> "${SUCCEEDED_REPORT_FILE}"
        else
          echo "===> Conflict resolution for branch '${BRANCH}' failed. Check the ${FAILED_REPORT_FILE} file"

          # Write failed report
          echo "${SOURCE_REPO_URL}, ${REPO}, ${BRANCH}, ${TARGET_REPO_URL}, ${TARGET_REPO}" >> "${FAILED_REPORT_FILE}"
        fi
    done

    echo "==> Copying tags from source to target..."
    git push target --tags

    # Clean up
    cd ..
    rm -rf "${REPO}"
done

# Clean up working directory
cd ..
rm -rf "$WORKING_DIR"
echo "=> Migration completed!"
echo "=> Check the reports files in: ${REPORTS_DIR}"
