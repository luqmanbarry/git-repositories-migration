#!/bin/bash

## ALL GIT REPOS URLS INCLUDE "_git", THIS IS AZURE SPECIFIC
## REMOVE THE SUBSTRING (_git) IF IT DOES NOT APPLY TO YOU

# Configuration
SOURCE_REPOS_ORG_URL="https://source.example.com/source-org/source-project"  # Replace with your source Azure Repos URL
TARGET_REPOS_ORG_URL="https://target.example.com/target-org/target-project"  # Replace with your target Azure DevOps URL

SOURCE_REPOS_PROJECT_PAT="source-repos-pat"  # Replace with your source PAT
TARGET_REPOS_PROJECT_PAT="target-repos-pat"  # Replace with your target PAT

WORKING_DIR="/tmp/repos_migration"  # Working directory for cloning repos

TARGET_REPOS_PREFIX="team-name" # Common prefix all target repos have. Set to empty string if none
REPOS_LIST_FILE="$1"  # Path to file containing list of source repos to mirror (one repo per line)
SOURCE_REPOS=""

# Create working directory
mkdir -p "${WORKING_DIR}"
cd "${WORKING_DIR}"

if [ -z "${REPOS_LIST_FILE}" ];
then
  echo "=> Repos list file must be provided as input to the script."
  echo "=> Example: ./repo-migration.sh source-repos.txt"
  exit 1
else
  SOURCE_REPOS=$(cat $REPOS_LIST_FILE)
  echo "=> Top N repos provided: "
  echo $SOURCE_REPOS | head
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
      TARGET_REPO_URL="${TARGET_REPOS_ORG_URL}/_git/${REPO}"
      TARGET_REPO_URL_PAT="https://${TARGET_REPOS_PROJECT_PAT}@${TARGET_REPOS_ORG_URL//https:///}/_git/${REPO}"
    else
      TARGET_REPO_URL="${TARGET_REPOS_ORG_URL}/_git/${TARGET_REPOS_PREFIX}-${REPO}"
      TARGET_REPO_URL_PAT="https://${TARGET_REPOS_PROJECT_PAT}@${TARGET_REPOS_ORG_URL//https:///}/_git/${TARGET_REPOS_PREFIX}-${REPO}"
    fi
    echo "==> Set target remote url to repo..."
    git remote add target ${TARGET_REPO_URL_PAT}

    # Copy individual branches from source to destination
    for BRANCH in "${SOURCE_BRANCHES}"; do
        echo "===> Copying branch ${BRANCH}..."

        echo "===> Checkout the branch from the source remote"
        git checkout -b ${BRANCH} "source/${BRANCH}"

        echo "===> Save the source state to patch file"
        git diff HEAD > source-state.patch

        echo "===> Reset to latest from target remote branch"
        git reset --hard "target/${BRANCH}"

        echo "===> Applying source state patch file..."
        git apply source-state.patch

        if [ "$?" == "0" ];
        then
          echo "===> Conflict resolution for branch '${BRANCH}' completed."
          echo "===> Push the branch to the target remote"
          git push target ${BRANCH}
        else
          echo "===> Conflict resolution for branch '${BRANCH}' failed. Check the conflicts.txt file"
          echo "${BRANCH}" >> conflicts.txt
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
rm -rf "${WORKING_DIR}"

echo "=> Migration completed!"
