#!/usr/bin/env bash

set -eo pipefail
source "$(dirname "$0")/common.sh"

leg_branch_bases | while read -r base; do
  for branch in $(remote_leg_branches "$base" "$GITHUB_RUN_ID"); do
    git push -q "$REPO_URL" --delete "$branch" || true
  done
done
