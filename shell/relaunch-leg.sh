#!/usr/bin/env bash
# shell/relaunch-leg.sh <leg> <attempt> <parent_run_id> <base_sha> <candidate_sha>

set -eo pipefail
source "$(dirname "$0")/common.sh"

awaitStatus=$(gh_retry gh run view "$3" --repo "$GITHUB_REPOSITORY" --json jobs -q '.jobs[] | select(.name == "Await-Legs") | .status') || awaitStatus=unknown
if [ "$awaitStatus" = "completed" ]; then
  echo "Parent run $3 is no longer awaiting legs, so $1 will not be relaunched."
  exit 0
fi
bash "$(dirname "$0")/dispatch-leg.sh" "$1" $(( $2 + 1 )) "$3" "$4" "$5"
