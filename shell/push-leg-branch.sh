#!/usr/bin/env bash
# shell/push-leg-branch.sh <results_dir>

set -eo pipefail
source "$(dirname "$0")/common.sh"

RESULTS_DIR=$(cd "$1" && pwd)
STAGE=$(mktemp -d)
mkdir -p "$STAGE/results"
cp "$RESULTS_DIR"/* "$STAGE/results/"
cd "$STAGE"
git init -q
git config user.email "40668522+RealTimeChris@users.noreply.github.com"
git config user.name "RealTimeChris"
git checkout -q -b "$BRANCH_NAME"
git add .
git commit -q -m "$COMMIT_MSG"
gh_retry git push -q -f "$REPO_URL" "$BRANCH_NAME"
