#!/usr/bin/env bash
# Apply branch protection to `main` on mbergo/claude-code-switchboard.
#
# Usage:
#   scripts/protect-main.sh            # apply protection via GitHub API
#   scripts/protect-main.sh --dry-run  # print the JSON payload only

set -euo pipefail

REPO="mbergo/claude-code-switchboard"
BRANCH="main"
ENDPOINT="/repos/${REPO}/branches/${BRANCH}/protection"

PAYLOAD=$(cat <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["build", "test", "lint"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": false,
  "lock_branch": false,
  "allow_fork_syncing": false
}
JSON
)

if [[ "${1:-}" == "--dry-run" ]]; then
  printf '%s\n' "$PAYLOAD"
  exit 0
fi

printf '%s\n' "$PAYLOAD" | gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  --input - \
  "$ENDPOINT" >/dev/null

echo "Branch protection applied to ${REPO}@${BRANCH}. Current state:"
gh api "$ENDPOINT"
