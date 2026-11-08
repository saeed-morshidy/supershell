# Governance

supershell is an open-source project: anyone may use, copy, modify and redistribute
it under the MIT License, and anyone may propose changes. **Merging** into the
official repository follows the rules below.

## Maintainers

Maintainers are listed in [`.github/CODEOWNERS`](.github/CODEOWNERS) and own every
file in the repository. New maintainers are proposed in an issue and accepted with
the same 3-approval rule as code.

## How a change gets in

1. Every change, including from maintainers, is a pull request to `main`.
2. **At least 3 approving reviews from maintainers** are required.
3. An approval is dismissed when new commits are pushed, and the most recent push
   must be approved by someone other than its author.
4. All CI checks must pass: `lint`, `tests (ubuntu-24.04)`, `tests (ubuntu-26.04)`,
   `e2e (ubuntu-26.04)`.
5. All review conversations must be resolved. History stays linear (squash merge).
6. The rules apply to repository admins too. Force-pushes to `main` are disabled.

These rules are enforced by GitHub branch protection. A repository admin applies
them once with:

```bash
scripts/setup-github.sh <owner>/supershell
```

> **Practical consequence:** GitHub never counts an author's approval of their own
> pull request. With 3 required approvals the project needs **at least 4
> maintainers** for every maintainer's PR to be mergeable (3 others to approve).
> Until then, PRs wait.

## Changes that need extra care

Anything that changes what gets downloaded or executed on users' machines —
`manifest/tools.ini`, `lib/tools.sh`, CI workflows — must:

- pin versions **and** SHA-256 hashes (`scripts/update-manifest.sh`),
- explain in the PR where each artifact comes from,
- never introduce `curl | sh` or similar.

## Decisions

Technical disagreements are discussed in the issue or PR. If consensus isn't
reached, a simple majority of maintainers decides; the reasoning is recorded in
the PR. Choices of tools are documented in
[docs/technology-selection.md](docs/technology-selection.md).
