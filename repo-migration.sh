#!/bin/bash

# Configuration
SOURCE_REPOS_ORG_URL="https://source.example.com/source-org/source-project"  # Replace with your source Azure Repos URL
TARGET_REPOS_ORG_URL="https://target.example.com/target-org/target-project"  # Replace with your target Azure DevOps URL

SOURCE_REPOS_PROJECT_PAT="source-repos-pat"  # Replace with your source PAT
TARGET_REPOS_PROJECT_PAT="target-repos-pat"  # Replace with your target PAT

WORKING_DIR="/tmp/repos_migration"  # Working directory for cloning repos

TARGET_REPOS_PREFIX="bosstwo" # Common prefix all target repos have. Set to empty string if none
REPOS_LIST_FILE="$1"  # Path to file containing list of source repos to mirror (one repo per line)
SOURCE_REPOS=""

# Create working directory
mkdir -p "$WORKING_DIR"
cd "$WORKING_DIR"

if [ -z "$REPOS_LIST_FILE" ];
then
  echo "==> Repos list file must be provided as input to the script."
  echo "==> Example: ./repo-migration.sh source-repos.txt"
  exit 1
else
  SOURCE_REPOS=$(cat $REPOS_LIST_FILE)
  echo "==> Some repos provided: "
  echo $SOURCE_REPOS | head
fi


# Loop through each repository
for REPO in $SOURCE_REPOS; do
    echo "Migrating repository: $REPO"

    # Clone the source repository with all branches and tags
    git clone --mirror "https://$SOURCE_REPOS_PROJECT_PAT@$SOURCE_REPOS_ORG_URL/_git/$TARGET_REPOS_PREFIX-$REPO" "$REPO"
    cd "$REPO"

    TARGET_REPO_URL=""
    TARGET_REPO_URL_PAT=""

    if [ -z "$TARGET_REPOS_PREFIX" ];
    then
      TARGET_REPO_URL="$TARGET_REPOS_ORG_URL/_git/$REPO"
      TARGET_REPO_URL_PAT="https://$TARGET_REPOS_PROJECT_PAT@$TARGET_REPOS_ORG_URL/_git/$REPO"
    else
      TARGET_REPO_URL="$TARGET_REPOS_ORG_URL/_git/$TARGET_REPOS_PREFIX-$REPO"
      TARGET_REPO_URL_PAT="https://$TARGET_REPOS_PROJECT_PAT@$TARGET_REPOS_ORG_URL/_git/$TARGET_REPOS_PREFIX-$REPO"
    fi

    # Add the target repository as a remote
    git remote add cloud "$TARGET_REPO_URL"
    git remote set-url --push cloud "$TARGET_REPO_URL_PAT"

    # Push all branches and tags to the cloud repository
    git push --mirror cloud

    # Clean up
    cd ..
    rm -rf "$REPO"
done

# Clean up working directory
cd ..
rm -rf "$WORKING_DIR"

echo "Migration completed!"
