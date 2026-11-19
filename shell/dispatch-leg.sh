#!/usr/bin/env bash
# shell/dispatch-leg.sh <leg> <attempt> <parent_run_id> <base_sha> <candidate_sha>

set -eo pipefail
source "$(dirname "$0")/common.sh"

gh_retry gh workflow run "$WORKFLOW_FILE" \
  --repo "$GITHUB_REPOSITORY" \
  --ref "$GITHUB_REF_NAME" \
  -f leg="$1" \
  -f attempt="$2" \
  -f parent_run_id="$3" \
  -f base_sha="$4" \
  -f candidate_sha="$5"
