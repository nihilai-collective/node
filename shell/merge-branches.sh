#!/usr/bin/env bash
# shell/merge-branches.sh <result_branch_prefix>

set -eo pipefail
source "$(dirname "$0")/common.sh"

RUN_TAG="${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
STAGE=$(mktemp -d)
cd "$STAGE"
git init -q
git config user.email "40668522+RealTimeChris@users.noreply.github.com"
git config user.name "RealTimeChris"
git checkout -q --orphan "$1-$RUN_TAG"
leg_branch_bases | while read -r base; do
  latest=$(remote_leg_branches "$base" "$GITHUB_RUN_ID" | sort -V | tail -n 1)
  if [ -z "$latest" ]; then
    echo "No branch found for $base-${GITHUB_RUN_ID}" >&2
    exit 1
  fi
  gh_retry git fetch -q "$REPO_URL" "refs/heads/$latest"
  git checkout -q FETCH_HEAD -- results
done
git add .
git commit -q -m "Jsonifier results for ${GITHUB_SHA} (run ${RUN_TAG})."
gh_retry git push -q -f "$REPO_URL" "$1-$RUN_TAG"
echo "Results pushed to $1-$RUN_TAG"
