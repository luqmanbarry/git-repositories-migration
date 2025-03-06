#!/bin/bash
set +e
set -x

WORKING_DIR="$1"

# RUN SCRIPT FROM WITHIN GIT REPO

LARGE_FILE_SIZE="5M"  # Potential values: 500K, 1M, 2M, 3M, 10M,..

echo "Cleaning up this directory: $WORKING_DIR"
cd $WORKING_DIR && pwd


echo "===> Cleaning up binary files from the git log..."
echo "~~~> Repository size BEFORE cleanup: '$(du -sh .)'"

echo "===> Repack the repository"
git repack -a -d --depth=300 --window=300

echo "===> Remove files with binary extensions from git history"
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
  --invert-paths --force

echo "===> Remove large files from history. Example: 1M, 5M, 10M"
git filter-repo \
  --strip-blobs-bigger-than $LARGE_FILE_SIZE \
  --force

echo "===> Clean up the repository"
git gc --aggressive --prune=now

echo "===> Verify the repository size"
du -sh .git
echo "~~~> Repository size AFTER cleanup: '$(du -sh .)'"
