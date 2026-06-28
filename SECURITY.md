# Security Policy

Container Desktop drives Apple's `container` CLI and performs a few **privileged
operations** (for example, DNS domain registration behind an authenticated admin
prompt), so we take security reports seriously.

## Reporting a vulnerability

Please **do not open a public issue** for security problems.

- Preferred: open a private report via GitHub — **Security ▸ Report a
  vulnerability** on this repository.
- Or email **marcel@baklouti.de** with details and steps to reproduce.

You'll get an acknowledgement within a few days. Once a fix is available, the
release notes will credit you unless you prefer to stay anonymous.

## Scope

In scope: the macOS app, the privileged-operation paths, the in-app updater, and
the release/signing pipeline (`scripts/release.sh`).

Out of scope: Apple's `container` runtime itself — report those to
[apple/container](https://github.com/apple/container) — and the user's own
machine configuration.

## Supported versions

Only the latest released version receives security fixes. The app couples its
version to the `container` CLI it targets.
