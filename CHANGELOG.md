# Changelog

All notable changes to Container Desktop are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] — 2026-06-29

### Fixed

- **Compose stacks that use `${VARIABLE}` syntax now launch.** The app performs full Docker Compose variable interpolation — `${VAR}`, `${VAR:-default}`, `${VAR-default}`, `${VAR:?err}`, `${VAR:+alt}`, `$$`, and nested forms — and reads a sibling `.env` file, so a port like `${POSTGRES_PORT:-5432}:5432` resolves to `5432:5432` instead of being passed literally to the runtime.
- **The menu-bar popover shows its running-container quick-nav again.** The scrollable list was collapsing to zero height inside the menu-bar window.
- **In-app updates install themselves.** Instead of opening a disk image you had to drag onto the still-running app (which macOS refuses), the updater verifies the new build's Developer ID, then quits, swaps the app in place, and relaunches.

### Changed

- The installer DMG's icon labels are now legible white text on the dark background.

## [1.0.1] — 2026-06-29

### Fixed

- **Compose stacks launch reliably.** Several real failures are resolved:
  - Short-form ports (`ports: ["3000"]`) are mapped to a valid `host:container` form instead of being rejected by `container run`.
  - Re-launching a stack no longer fails with “already exists” — existing containers for the project are reconciled before recreating.
  - Build-only services (`build:` with no `image:`) report a clear message instead of producing a malformed command.
  - `network`/`volume` creation failures surface their real cause instead of cascading into opaque per-service errors.
  - Long-form ports with only `target:` are no longer force-published to the host.
- **Installing the `container` CLI from the app finishes cleanly.** After the guided install the runtime daemon is started automatically, so the app lands on the running state instead of stranding you on a separate “Start” step.
- **Clearer runtime errors.** A failure to launch the `container` tool (quarantine, wrong architecture, …) reports its real cause instead of the misleading “tool isn’t installed.”
- **Registries no longer break on first login** — the login list decodes the runtime’s actual JSON shape.
- **DNS domain sheet** keeps itself open and shows validation/authorization errors inline instead of vanishing as if it succeeded; the domain list no longer clears on a transient read.
- **Background polling no longer re-presents a dismissed error alert** every few seconds, and no longer clobbers an error from an action you took.
- **The inspector closes** when you deselect or delete the selected item, instead of stranding a “No Selection” panel.
- **Hardened process handling** — a stuck `container` subprocess is escalated to a forced termination after a grace period so the app can’t hang waiting on it.

### Changed

- Marketing-site screenshots render at full resolution (no more pixelation).
- The release DMG ships a styled installer window (branded background, drag-to-Applications layout).
- CI security scanning (CodeQL) is scoped to JavaScript/TypeScript; the Swift app is built and tested by the regular CI job.
- The About panel shows the copyright and the “not affiliated with Apple” notice.

## [1.0.0] — 2026-06-28

Initial public release.

A native macOS app for Apple’s `container` runtime — run, inspect, and manage containers, images, volumes, networks, and machines; launch Compose stacks; stream logs and an embedded terminal; watch live CPU/memory; and control everything from the menu bar. Apple Silicon, macOS 26+. Developer ID-signed and notarized, with a guided `container` CLI install and a signed in-app self-update.

[1.0.2]: https://github.com/marcelbaklouti/container-desktop/releases/tag/v1.0.2
[1.0.1]: https://github.com/marcelbaklouti/container-desktop/releases/tag/v1.0.1
[1.0.0]: https://github.com/marcelbaklouti/container-desktop/releases/tag/v1.0.0
