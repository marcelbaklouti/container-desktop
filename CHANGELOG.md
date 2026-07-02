# Changelog

All notable changes to Container Desktop are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.5] — 2026-07-02

### Added

- **Stacks are now first-class.** A new sidebar area lists every Compose project as one unit — services with live status and per-service start/stop/restart, stack-wide controls, and **combined logs**: every service's output merged live with stable per-service colors, chips to show or hide services (⌥-click isolates one), search, and a detachable window (⇧⌘L). Stacks remember their compose file — including stacks migrated from Docker — so *Relaunch Stack* re-reads it and *Open Compose File* jumps to Finder. Deleting a stack keeps its volumes and network. The menu bar groups running containers by stack with one-click stop-all.
- **Logs became a place to work.** Search with live highlighting and ⌘G match navigation, a tail control (last 500 / 5,000 / everything) so logs open instantly, Copy All and Save…, and stopped containers show the final logs from their last run instead of an empty view. The buffer doubled to 10,000 lines and log storms no longer churn the UI.
- **Duplicate and Copy Run Command.** Right-click any container to duplicate it into a prefilled Run sheet — settings diffed against the image's own defaults so only real overrides carry over, with a note for anything that can't — or copy the complete, shell-quoted `container run` one-liner to paste anywhere.
- **Advanced run options.** The Run sheet gains entrypoint, user, working directory, labels, tmpfs, SSH agent forwarding, and a Platform picker — run **Intel-only images via Rosetta** at near-native speed with one selection.
- **Know what's using what.** Volume inspectors list the containers mounting them (with an In Use badge on rows), network inspectors list attached members — click any to jump to it. *Remove Stopped Containers* joins the Containers toolbar with a counted confirmation.
- **Settings: Refresh rate and Open at Login.** Choose Fast, Default, or Relaxed polling (applies immediately), and have Container Desktop start at login so the menu bar is always there.

### Changed

- **Keyboard-first polish.** ⌘1–⌘9 switch areas, ⌘R refreshes, ⌥⌘I toggles the inspector, ⌘⌫ deletes the selection (with the usual confirmation), and log search follows the system Find conventions. Lists, badges, and counts animate smoothly — and not at all when Reduce Motion is on. Badges, empty screens, and shortcut hints scale with the system text size.

## [1.0.4] — 2026-07-02

### Added

- **Migrate from Docker in one click — data included.** If Docker is installed, a new assistant in Containers lists every Docker container grouped by Compose project (running ones preselected) and moves your selection over: images transfer directly (registry pull as fallback), named volumes are recreated **with their data**, and containers are rebuilt with their ports, environment, mounts, resource limits, and labels — so Compose groups carry over. Docker originals are stopped only after their replacement is running, restarted automatically if it isn't, and never deleted. Anything that can't carry over (restart policies, custom Docker networks) is listed per container. Re-running is safe: already-migrated containers are skipped.
- **Compose `build:` services now build.** Launching a stack builds services that declare `build:` (shorthand or full `context`/`dockerfile`/`args`/`target` form) instead of failing them — the builder starts automatically when needed, with visible progress for its first-run image pull, and built images follow Compose naming (`<project>-<service>`). Failures propagate through `depends_on`, so a dependent reports “didn’t start — X failed” instead of a confusing runtime error.
- **App updates install in the background.** Container Desktop now checks daily, notifies you once per version, downloads and signature-verifies the update in the background, and waits for one click — **Restart to Update** in the menu bar or Settings. The app never restarts on its own; automatic downloads and update notifications have Settings toggles.
- **Errors that help instead of apologize.** Alerts now say what went wrong and offer the fix: deleting a running container offers *Stop and Delete*, an in-use volume or network names the containers using it and can reveal them, a port conflict offers *Show Running Containers*, and a stopped system offers *Start Container System*. Every alert can copy the failing command for diagnosis.

### Fixed

- **Starting the container system no longer flashes a false error.** The app now waits for the daemon to report ready (it keeps booting after the start command returns) and shows “Starting the container system…” progress in the meantime — in the start screen and the menu bar.
- **Lifecycle actions show what's happening.** Containers display *Starting…*, *Stopping…*, and *Restarting…* badges with a spinner the moment you act, instead of a stale Running/Stopped badge until the next poll; machines show the same while stopping. A container that wedges mid-transition surfaces a message after 30 seconds.

## [1.0.3] — 2026-06-29

### Fixed

- **The installer DMG's styled window renders again.** A 1.0.2 change set the Finder icon-label size to an out-of-range value to hide the labels; on macOS 26 that made Finder discard the window's entire icon-view layout, so the disk image opened as a plain default window with no background art, arrow, or instructions. The label size is back in the valid range and the branded installer background is restored. This is the only change in this release.

## [1.0.2] — 2026-06-29

### Added

- **Multiple selection across every list.** ⌘-click or ⇧-click to select several containers, images, networks, volumes, machines, or registry logins, then act on them all at once from the right-click menu — start, stop, restart, or delete containers; delete images, networks, and volumes; stop or delete machines; or log out of registries together. The menu adapts to what you picked, so Stop appears only when something selected is running.
- **Start or stop a whole Compose stack.** Each project group header in Containers now has Start All and Stop All, so an entire stack goes up or down in one move.

### Fixed

- **Compose stacks that use `${VARIABLE}` syntax now launch.** The app performs full Docker Compose variable interpolation — `${VAR}`, `${VAR:-default}`, `${VAR-default}`, `${VAR:?err}`, `${VAR:+alt}`, `$$`, and nested forms — and reads a sibling `.env` file, so a port like `${POSTGRES_PORT:-5432}:5432` resolves to `5432:5432` instead of being passed literally to the runtime.
- **The menu-bar popover shows its running-container quick-nav again.** The scrollable list was collapsing to zero height inside the menu-bar window.
- **In-app updates install themselves.** Instead of opening a disk image you had to drag onto the still-running app (which macOS refuses), the updater verifies the new build's Developer ID, then quits, swaps the app in place, and relaunches.
- **Clearer Compose launch.** Each service shows a named phase — *Pulling image… → Starting… → Running / Failed* — with an always-animating indicator and a live "N of M ready" summary, and failures show a readable message (e.g. a port conflict) instead of raw CLI progress output.

### Changed

- The installer DMG's icon labels are now legible white text on the dark background.
- **Empty screens now teach.** Each area with no items explains, in plain language, what the resource is and lists the relevant keyboard shortcuts — and **⌘N** creates a new one in every area (run a container, pull an image, create a network/volume/machine, log in to a registry).

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

[1.0.5]: https://github.com/marcelbaklouti/container-desktop/releases/tag/v1.0.5
[1.0.4]: https://github.com/marcelbaklouti/container-desktop/releases/tag/v1.0.4
[1.0.3]: https://github.com/marcelbaklouti/container-desktop/releases/tag/v1.0.3
[1.0.2]: https://github.com/marcelbaklouti/container-desktop/releases/tag/v1.0.2
[1.0.1]: https://github.com/marcelbaklouti/container-desktop/releases/tag/v1.0.1
[1.0.0]: https://github.com/marcelbaklouti/container-desktop/releases/tag/v1.0.0
