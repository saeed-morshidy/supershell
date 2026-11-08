# Security policy

## Reporting a vulnerability

Please **do not open a public issue**. Use GitHub's private vulnerability reporting
(*Security → Report a vulnerability*) on the repository. You'll get an answer
within 7 days. Fixes go through the normal 3-approval review in a private fork.

## What supershell does to stay safe

- Installs from Ubuntu's archive when the version is good enough; otherwise from
  official GitHub releases, **pinned by version and SHA-256** in
  `manifest/tools.ini`. A mismatch deletes the file and stops.
- If no hash is pinned yet, the upstream checksum file is used and a warning is
  shown; with neither, the download is refused.
- Never runs `curl | sh`, never runs remote install scripts.
- `sudo` is used only for `apt-get`, only when needed, and the password is never
  stored or passed around.
- No telemetry. Atuin sync and update checks are switched off. No shell start-up
  network traffic.
- User files are backed up before every change; failed runs roll back.

See [docs/reports/security-dependencies.md](docs/reports/security-dependencies.md)
for the dependency list and the current state of pinning.
