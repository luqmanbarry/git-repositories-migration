import subprocess
import os
import yaml
from datetime import datetime

# Configuration - Set these variables in the inputs.yaml file before running the script
INPUT_YAML_FILE = "inputs.yaml"
if not os.path.isfile(INPUT_YAML_FILE):
    print(f"File '{INPUT_YAML_FILE}' does not exist or is not a regular file.")
    exit(1)

# Parse input YAML
with open(INPUT_YAML_FILE, 'r') as f:
    config = yaml.safe_load(f)

SOURCE_REPOS_ORG_URL = config['inputs']['source_project_url']
TARGET_REPOS_ORG_URL = config['inputs']['destination_project_url']
CLEANUP_LARGE_FILES = config['inputs']['large_file_cleanup']['enable']
LARGE_FILE_SIZE = config['inputs']['large_file_cleanup']['file_size']
REPOS_LIST = config['inputs']['repositories']

# Create necessary directories
CURRENT_DIR = os.getcwd()
WORKING_DIR = f"{CURRENT_DIR}/repo_migration/runs_{datetime.now().strftime('%Y%m%d%H')}"
REPORTS_DIR = f"{CURRENT_DIR}/migration_reports/{config.get('TARGET_REPOS_PREFIX', '')}"
os.makedirs(WORKING_DIR, exist_ok=True)
os.makedirs(REPORTS_DIR, exist_ok=True)

# Prepare reports
SUCCEEDED_REPORT_FILE = os.path.join(REPORTS_DIR, "succeeded-migrations.csv")
FAILED_REPORT_FILE = os.path.join(REPORTS_DIR, "failed-migrations.csv")

with open(SUCCEEDED_REPORT_FILE, 'w') as f:
    f.write("source_repo_url, source_repo, source_branch, target_repo_url, target_repo\n")
with open(FAILED_REPORT_FILE, 'w') as f:
    f.write("source_repo_url, source_repo, source_branch, target_repo_url, target_repo\n")

if not REPOS_LIST:
    print("=> Repos list file must be provided as input to the script.")
    exit(1)

def run_command(command):
    """Run shell commands and handle errors."""
    print(f"Running command: {command}")
    try:
        subprocess.check_call(command, shell=True)
    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")
        exit(1)

# Loop through repositories list and perform migration
for repo in REPOS_LIST:
    SRC_REPO_NAME = repo['source']
    DEST_REPO_NAME = repo['destination']

    if not SRC_REPO_NAME or not DEST_REPO_NAME:
        print(f"One of Source ({SRC_REPO_NAME}) and/or destination ({DEST_REPO_NAME}) repository entries is empty.")
        exit(1)

    SOURCE_REPO_URL = f"{SOURCE_REPOS_ORG_URL}/{SRC_REPO_NAME}"
    if "dev.azure.com" in SOURCE_REPOS_ORG_URL:
        SOURCE_REPO_URL = f"{SOURCE_REPOS_ORG_URL}/_git/{SRC_REPO_NAME}"

    TARGET_REPO_URL = f"{TARGET_REPOS_ORG_URL}/{DEST_REPO_NAME}"
    if "dev.azure.com" in TARGET_REPOS_ORG_URL:
        TARGET_REPO_URL = f"{TARGET_REPOS_ORG_URL}/_git/{DEST_REPO_NAME}"

    print(f"==> Migrating repository: {SOURCE_REPO_URL}")

    os.chdir(WORKING_DIR)
    print("==> Clone the source repository with all branches and tags...")
    run_command(f"git clone {SOURCE_REPO_URL} || echo 'Repo exists already'")

    os.chdir(SRC_REPO_NAME)
    print("==> Set source remote url to repo...")
    run_command(f"git remote add source {SOURCE_REPO_URL}")

    # Fetch all branches and tags from the source remote
    print(f"==> Fetching all branches and tags from {SOURCE_REPO_URL}...")
    run_command("git fetch source --tags")

    print("==> Get a list of all branches in the source remote...")
    branches = subprocess.check_output("git branch -r | grep 'source/' | sed 's/source\///' | grep -v 'HEAD'", shell=True)
    branches = branches.decode('utf-8').splitlines()

    print(f"Source Branches: {branches}")

    # Set target remote URL to repo
    print("==> Set target remote URL to repo...")
    run_command(f"git remote add target {TARGET_REPO_URL}")

    for branch in branches:
        print(f"===> Migrating branch {branch}...")
        branch = branch.strip()

        print(f"===> Checkout the branch from the source remote")
        run_command(f"git checkout -b {branch} source/{branch} || true")

        run_command(f"git fetch")
        run_command(f"git pull source {branch}")

        PATCH_FILE = f"{WORKING_DIR}/source-state.patch"
        print("===> Save the source state to a patch file")
        run_command(f"git diff HEAD > {PATCH_FILE}")

        print(f"===> Pushing branch {branch} to target repository...")
        run_command(f"git push -u target {branch}")

        # Check if push was successful
        if subprocess.call(f"git push -u target {branch}", shell=True) == 0:
            print(f"===> Migration for branch '{branch}' succeeded.")
            with open(SUCCEEDED_REPORT_FILE, 'a') as f:
                f.write(f"{SOURCE_REPO_URL}, {SRC_REPO_NAME}, {branch}, {TARGET_REPO_URL}, {DEST_REPO_NAME}\n")
        else:
            print(f"===> Migration for branch '{branch}' failed. Performing conflict resolution.")

            if CLEANUP_LARGE_FILES == "true":
                print("==> Cleaning up binary files from the git history...")

                if subprocess.call("git filter-repo --version", shell=True) != 0:
                    print("==> git filter-repo is not installed or not working.")
                    print("==> Find install instructions at this url: https://github.com/newren/git-filter-repo/blob/main/INSTALL.md")
                    exit(1)

                print("~~~> Repository size BEFORE cleanup: ", subprocess.check_output("du -sh .", shell=True).decode('utf-8'))
                run_command("git repack -a -d --depth=300 --window=300")

                # Remove files with binary extensions from git history
                run_command("""
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
                """)

                run_command(f"git filter-repo --strip-blobs-bigger-than {LARGE_FILE_SIZE} --invert-paths --force")
                run_command("git gc --aggressive --prune=now")
                print("~~~> Repository size AFTER cleanup: ", subprocess.check_output("du -sh .", shell=True).decode('utf-8'))

                run_command("git commit -am 'Repo Migration: Removed binary files.'")
                run_command(f"git push target {branch}")

            print(f"===> Reset to latest from target branch")
            run_command(f"git fetch target {branch}")
            run_command(f"git reset --hard target/{branch}")

            print(f"===> Applying source state patch file...")
            run_command(f"git apply {PATCH_FILE}")
            run_command(f"git commit -am 'Repo Migration: Merged source and target branches.'")

            run_command(f"git push target {branch}")

            if subprocess.call(f"git push target {branch}", shell=True) != 0:
                with open(FAILED_REPORT_FILE, 'a') as f:
                    f.write(f"{SOURCE_REPO_URL}, {SRC_REPO_NAME}, {branch}, {TARGET_REPO_URL}, {DEST_REPO_NAME}\n")
            else:
                print(f"===> Migration for branch '{branch}' succeeded after conflict resolution.")
                with open(SUCCEEDED_REPORT_FILE, 'a') as f:
                    f.write(f"{SOURCE_REPO_URL}, {SRC_REPO_NAME}, {branch}, {TARGET_REPO_URL}, {DEST_REPO_NAME}\n")

    # Copy tags from source to target
    print(f"==> Copying tags from source to target...")
    run_command(f"git push target --tags")

print("=> Migration completed!")
print(f"=> Check the reports files in: {REPORTS_DIR}")
print(f"=> 'SUCCEEDED' migrations report file: {SUCCEEDED_REPORT_FILE}")
print(f"=> 'FAILED' migrations report file: {FAILED_REPORT_FILE}")
