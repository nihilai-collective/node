#!/usr/bin/env bash
# shell/dispatch-leg.sh <leg> <attempt> <parent_run_id> <sha> <jsonifier_sha>

set -eo pipefail
source "$(dirname "$0")/common.sh"

gh_retry gh workflow run "$WORKFLOW_FILE" \
  --repo "$GITHUB_REPOSITORY" \
  --ref "$GITHUB_REF_NAME" \
  -f leg="$1" \
  -f attempt="$2" \
  -f parent_run_id="$3" \
  -f sha="$4" \
  -f jsonifier_sha="$5"
