## What and why

<!-- One or two sentences. Link the issue: Fixes #123 -->

## Checklist

- [ ] `tests/run.sh` passes locally (paste the summary line)
- [ ] `shellcheck` is clean
- [ ] No standard command (ls, cat, grep, find, cd, vi, …) is redefined
- [ ] Interactive start-up still prints nothing; `supershell bench` overhead not worse
- [ ] New/changed downloads are pinned in `manifest/tools.ini` with SHA-256 (`scripts/update-manifest.sh`)
- [ ] User files are never overwritten without a backup and consent
- [ ] Docs updated (README, docs/, CHANGELOG.md)
- [ ] Arabic: if this touches display/editing, the relevant part of `docs/arabic-test-plan.md` was run

## Reviewers

Merging needs **3 approving reviews** from maintainers. Approvals are dismissed when new commits are pushed.
