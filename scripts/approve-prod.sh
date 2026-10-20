#!/usr/bin/env bash
# Approve a pending PROD deployment from the terminal (no GUI).
# Usage: ./scripts/approve-prod.sh ["approval comment"]
set -euo pipefail

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
COMMENT="${1:-Approved from CLI after verifying dev and test}"

RUN_ID=$(gh run list --branch main --limit 1 --json databaseId -q '.[0].databaseId')
ENV_ID=$(gh api "repos/$REPO/actions/runs/$RUN_ID/pending_deployments" \
  --jq '.[] | select(.environment.name=="prod") | .environment.id')

if [ -z "$ENV_ID" ]; then
  echo "Nothing waiting at prod in run $RUN_ID. No approval sent."
  exit 0
fi

echo "Repo:    $REPO"
echo "Run:     $RUN_ID"
echo "Env ID:  $ENV_ID (prod)"
echo "Comment: $COMMENT"
read -r -p "Approve prod deployment? Type 'yes' to continue: " ANSWER
if [ "$ANSWER" != "yes" ]; then
  echo "Not approved."
  exit 1
fi

gh api -X POST "repos/$REPO/actions/runs/$RUN_ID/pending_deployments" \
  -F "environment_ids[]=$ENV_ID" -f state=approved -f comment="$COMMENT" >/dev/null
echo "Prod approved."
