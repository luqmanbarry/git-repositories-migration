# 
# DRAFT - Not tested, there may be few bugs
#
import os
import subprocess
import sys
import shutil
from pathlib import Path

# Configuration - Set these variables before running the script
SOURCE_REPOS_ORG_URL = "source.example.com/source-org/source-project"  # Replace with your source Azure Repos URL.
TARGET_REPOS_ORG_URL = "target.example.com/target-org/target-project"  # Replace with your target Azure DevOps URL.
SOURCE_REPOS_PROJECT_PAT = ""  # Replace with your source PAT. Leave empty if you've already set up Git Credentials Helper for this URL.
TARGET_REPOS_PROJECT_PAT = ""  # Replace with your target PAT. Leave empty if you've already set up Git Credentials Helper for this URL.
TARGET_REPOS_PREFIX = "team-name"  # Common prefix all target repos have. Set to an empty string if none.
CLEANUP_LARGE_FILES = True  # Set this flag to True if you want large files removed from git history.
LARGE_FILE_SIZE = "5M"  # Potential values: 500K, 1M, 2M, 3M, 10M, etc.

# Directories and files
CURRENT_DIR = Path(os.getcwd())  # Current working directory
WORKING_DIR = CURRENT_DIR / "repo_migration"  # Working directory for cloning repos
REPORTS_DIR = CURRENT_DIR / "migration_reports" / (TARGET_REPOS_PREFIX or "")  # Directory where report files will be stored
PATCH_FILE = WORKING_DIR / "source-state.patch"  # Patch file for merging source and target branches
SUCCEEDED_REPORT_FILE = REPORTS_DIR / "succeeded-migrations.csv"  # Succeeded code migrations report
FAILED_REPORT_FILE = REPORTS_DIR / "failed-migrations.csv"  # Failed code migrations report


def run_command(command, cwd=None):
    """Run a shell command and return its output."""
    result = subprocess.run(command, shell=True, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
        return False
    return True


def clone_repository(source_repo_url_pat, repo_name):
    """Clone the source repository with all branches and tags."""
    print(f"==> Cloning repository: {repo_name}...")
    if not run_command(f"git clone {source_repo_url_pat}"):
        print(f"==> Repository {repo_name} already exists or failed to clone.")
        return False
    return True


def fetch_all_branches_and_tags(repo_dir):
    """Fetch all branches and tags from the source remote."""
    print("==> Fetching all branches and tags...")
    if not run_command("git fetch source --tags", cwd=repo_dir):
        return False
    return True


def get_source_branches(repo_dir):
    """Get a list of all branches in the source remote."""
    result = subprocess.run(
        "git branch -r | grep 'source/' | sed 's/source\\///' | grep -v 'HEAD'",
        shell=True,
        cwd=repo_dir,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
        return []
    return [branch.strip() for branch in result.stdout.splitlines()]


def push_branch_to_target(repo_dir, branch, target_repo_url_pat):
    """Push a branch to the target repository."""
    print(f"===> Pushing branch {branch} to target...")
    if not run_command(f"git push -u target {branch}", cwd=repo_dir):
        return False
    return True


def cleanup_large_files(repo_dir):
    """Clean up large files from git history."""
    print("===> Cleaning up binary files from the git log...")
    commands = [
        "git repack -a -d --depth=300 --window=300",
        "git filter-repo --path-glob '*.zip' --path-glob '*.xls' --path-glob '*.tar' --path-glob '*.jar' "
        "--path-glob '*.gz' --path-glob '*.mov' --path-glob '*.avi' --path-glob '*.iso' --path-glob '*.msi' "
        "--path-glob '*.mp4' --path-glob '*.war' --path-glob '*.exe' --path-glob '*.dll' --path-glob '*.deb' "
        "--path-glob '*.vob' --path-glob '*.odt' --path-glob '*.docx' --path-glob '*.doc' --path-glob '*.tgz' "
        "--path-glob '*.rar' --path-glob '*.bz2' --path-glob '*.bzip2' --path-glob '*.7z' --path-glob '*.pptx' "
        "--path-glob '*.xlsm' --path-glob '*.xlsb' --path-glob '*.xltx' --path-glob '*.xlsx' --path-glob '*.pkg' "
        "--path-glob '*.rpm' --path-glob '*.tar.gz' --path-glob '*.dmg' --path-glob '*.bin' --path-glob 'node_modules/**' "
        "--path-glob '**/node_modules/**' --invert-paths --force",
        f"git filter-repo --strip-blobs-bigger-than {LARGE_FILE_SIZE} --force",
        "git gc --aggressive --prune=now",
    ]
    for command in commands:
        if not run_command(command, cwd=repo_dir):
            return False
    return True


def migrate_repository(source_repo_url, repo_name, target_repo_url, target_repo_url_pat):
    """Migrate a single repository from source to target."""
    repo_dir = WORKING_DIR / repo_name
    os.chdir(WORKING_DIR)

    # Clone the repository
    if not clone_repository(source_repo_url, repo_name):
        return

    # Fetch all branches and tags
    if not fetch_all_branches_and_tags(repo_dir):
        return

    # Get a list of all branches
    source_branches = get_source_branches(repo_dir)
    if not source_branches:
        print("==> No branches found in the source repository.")
        return

    # Push each branch to the target repository
    for branch in source_branches:
        print(f"===> Migrating branch: {branch}")
        if not push_branch_to_target(repo_dir, branch, target_repo_url_pat):
            if CLEANUP_LARGE_FILES:
                if not cleanup_large_files(repo_dir):
                    print(f"===> Failed to clean up large files for branch {branch}.")
                    continue
                if not push_branch_to_target(repo_dir, branch, target_repo_url_pat):
                    print(f"===> Failed to push branch {branch} after cleanup.")
                    continue

    # Push tags to the target repository
    print("==> Pushing tags to target...")
    run_command("git push target --tags", cwd=repo_dir)


def main():
    if len(sys.argv) != 2:
        print("Usage: python repo_migration.py <repos_list_file>")
        sys.exit(1)

    repos_list_file = sys.argv[1]
    if not os.path.isfile(repos_list_file):
        print(f"Error: Repos list file '{repos_list_file}' not found.")
        sys.exit(1)

    # Create directories
    WORKING_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    # Prepare report files
    with open(SUCCEEDED_REPORT_FILE, "w") as f:
        f.write("source_repo_url, source_repo, source_branch, target_repo_url, target_repo\n")
    with open(FAILED_REPORT_FILE, "w") as f:
        f.write("source_repo_url, source_repo, source_branch, target_repo_url, target_repo\n")

    # Read the list of repositories to migrate
    with open(repos_list_file, "r") as f:
        repos_list = f.readlines()

    for repo in repos_list:
        repo = repo.strip()
        if not repo:
            continue

        print(f"==> Migrating repository: {repo}")

        # Construct source and target URLs
        source_repo_url = f"{SOURCE_REPOS_ORG_URL}/_git/{repo}"
        if SOURCE_REPOS_PROJECT_PAT:
            source_repo_url_pat = f"https://{SOURCE_REPOS_PROJECT_PAT}@{SOURCE_REPOS_ORG_URL}/_git/{repo}"
        else:
            source_repo_url_pat = f"https://{SOURCE_REPOS_ORG_URL}/_git/{repo}"

        if TARGET_REPOS_PREFIX:
            target_repo = f"{TARGET_REPOS_PREFIX}-{repo}"
        else:
            target_repo = repo

        target_repo_url = f"{TARGET_REPOS_ORG_URL}/_git/{target_repo}"
        if TARGET_REPOS_PROJECT_PAT:
            target_repo_url_pat = f"https://{TARGET_REPOS_PROJECT_PAT}@{TARGET_REPOS_ORG_URL}/_git/{target_repo}"
        else:
            target_repo_url_pat = f"https://{TARGET_REPOS_ORG_URL}/_git/{target_repo}"

        # Migrate the repository
        migrate_repository(source_repo_url_pat, repo, target_repo_url, target_repo_url_pat)

    print("=> Migration completed!")
    print(f"=> Check the reports files in: {REPORTS_DIR}")
    print(f"=> 'SUCCEEDED' migrations report file: {SUCCEEDED_REPORT_FILE}")
    print(f"=> 'FAILED' migrations report file: {FAILED_REPORT_FILE}")


if __name__ == "__main__":
    main()
