#!/usr/bin/env bash
# Apply the project's merge rules to GitHub (run once by a repository admin):
#   * every change goes through a pull request
#   * at least 3 approving reviews from maintainers (code owners)
#   * new pushes dismiss earlier approvals; the last push must be approved by someone else
#   * all CI checks must pass and the branch must be up to date
#   * no force-pushes or deletion of main; rules apply to admins too
#
#   scripts/setup-github.sh owner/repo [branch]
set -euo pipefail
repo="${1:?usage: scripts/setup-github.sh owner/repo [branch]}"
branch="${2:-main}"
command -v gh >/dev/null || { echo "Install the GitHub CLI (gh) and run: gh auth login" >&2; exit 1; }

gh api -X PUT "repos/$repo/branches/$branch/protection" \
  -H "Accept: application/vnd.github+json" --input - <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["lint", "tests (ubuntu-24.04)", "tests (ubuntu-26.04)", "e2e (ubuntu-26.04)"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 3,
    "require_code_owner_reviews": true,
    "dismiss_stale_reviews": true,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON

gh api -X PATCH "repos/$repo" -F delete_branch_on_merge=true -F allow_merge_commit=false \
  -F allow_squash_merge=true -F allow_rebase_merge=false >/dev/null
echo "Branch protection applied to $repo@$branch: 3 approvals required."
