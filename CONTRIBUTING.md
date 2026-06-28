# Contributing to Container Desktop

Thanks for your interest! Container Desktop is a native macOS app that gives
Apple's [`container`](https://github.com/apple/container) runtime a graphical
management surface. It is a **client** of the CLI, never a reimplementation.

## Prerequisites

- Apple Silicon Mac on **macOS 26 (Tahoe)** or later
- **Xcode 26.6** (Swift 6.3 toolchain)
- The **Metal Toolchain** (SwiftTerm bundles Metal shaders):
  `xcodebuild -downloadComponent MetalToolchain`
- The **`container` CLI** installed with its daemon running, for anything that
  touches the runtime: `container system start`

## Build, run, test

```sh
# Build
xcodebuild -project Containers.xcodeproj -scheme Containers -configuration Debug build CODE_SIGNING_ALLOWED=NO

# Run / develop
open Containers.xcodeproj   # ⌘R

# Tests (need the container daemon running)
xcodebuild test -project Containers.xcodeproj -scheme Containers -destination 'platform=macOS'
```

CI builds the app and the landing page, but the test suite talks to a live
`container` daemon, so **run the tests locally** before opening a PR.

## Architecture

Layered, with one direction of dependency: **UI → stores → runtime client + models**.

- **Runtime client** (`RuntimeClient/`) — a single `actor` over the `container`
  CLI: `--format json` for reads, spawned processes for streaming, SwiftTerm for
  the PTY, typed errors. Depends on nothing else in the app.
- **Models** (`Models/`) — small `Codable` structs mirroring the CLI's JSON.
- **Stores** (`Stores/`) — one `@Observable @MainActor` store per area; lists
  refresh by diffed polling.
- **UI** (`UI/`) — a `NavigationSplitView` shell with a list + inspector per area.

Never reach upward across these layers.

## Conventions

- **Production-complete code** — no stubs, placeholders, or leftover TODOs.
- **No comments** — use descriptive identifiers instead.
- Swift 6 structured concurrency, `@Observable`, typed errors; avoid
  force-unwraps on production paths.
- User-facing strings go through the String Catalog (`LocalizedStringKey` /
  `String(localized:)`); the app is English-only.
- Follow Apple's Human Interface Guidelines and the patterns already in the code.

## Pull requests

- Branch from `main`, keep PRs focused, and describe the user-visible change.
- Make sure the app builds and local tests pass.
- By contributing, you agree your work is licensed under the project's
  [Apache 2.0](LICENSE) license.

## Releases

Cutting a signed, notarized release is documented in [RELEASE.md](RELEASE.md).
