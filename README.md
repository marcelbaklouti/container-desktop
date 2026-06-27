# Apple Container UI — Project Documents

A native macOS GUI for [`apple/container`](https://github.com/apple/container) — a Docker Desktop alternative built on ContainerClient (the apple/container Swift library) over XPC, with the `container` CLI as a fallback. Built in SwiftUI, Apple Silicon only.

Product name: Containers. The app ships with a visible "not affiliated with Apple" notice and does not use Apple's logo or trade dress. Document language: English (can be regenerated in German on request).

## What is in this folder

- `Projectplan.md` — the single source of truth. Full scope, architecture, locked decisions, the CLI-to-feature mapping, platform baseline, distribution, and open items.
- `buildphases.md` — the execution checklist. The build is split into self-contained phases sized for one generation pass each. Each phase has a goal, its dependencies, deliverables, and explicit done-criteria, and can be marked complete.
- `Memory.md` — living context for every work session. Holds the locked decisions, conventions, hard technical facts about the CLI, known pitfalls, current status, and the open questions. Read it first, update it last.
- `README.md` — this file.

## How to use these documents

`Projectplan.md` is the reference. It changes only when a decision changes. It does not track progress.

`buildphases.md` is the order of work. Phases are ordered by dependency, not by time, and contain no time estimates by design. Work top to bottom. Do not start a phase until every phase it depends on is checked. Mark a phase `- [x]` only when all of its done-criteria are met.

`Memory.md` is what keeps separate sessions (human or AI) consistent. A fresh session has none of the prior context except what is written here, so it must be read at the start and updated at the end.

## Recommended session loop

1. Read `Memory.md`, then the relevant part of `Projectplan.md`, then the next unchecked phase in `buildphases.md`.
2. Implement exactly that phase. No scope creep into later phases.
3. Verify the result against the phase's done-criteria.
4. Mark the phase `- [x]` in `buildphases.md`.
5. Update `Memory.md`: new status, any decision made, anything learned, anything that changed an open question.

## Conventions

The canonical convention list lives in `Memory.md`. In short: production-complete code only (no MVPs, no stubs), no comments in code, descriptive identifiers, no time estimates in any planning document, German umlauts whenever German text is written.

## Sources and references

### Apple container project (primary)
- Repository: https://github.com/apple/container
- Releases: https://github.com/apple/container/releases
- CLI command reference: https://github.com/apple/container/blob/main/docs/command-reference.md
- Technical overview (apiserver, XPC helpers, architecture): https://github.com/apple/container/blob/main/docs/technical-overview.md
- Container machine: https://github.com/apple/container/blob/main/docs/container-machine.md
- How-to (networks, capabilities, multi-arch): https://github.com/apple/container/blob/main/docs/how-to.md
- Getting started tutorial: https://github.com/apple/container/blob/main/docs/tutorials/start-here.md
- API documentation: https://apple.github.io/container/documentation/
- Containerization Swift package: https://github.com/apple/containerization
- WWDC25 "Meet Containerization": https://developer.apple.com/videos/play/wwdc2025/346/

### Apple platform — SwiftUI, macOS 27, Metal (WWDC 2026)
- WWDC26 SwiftUI guide: https://developer.apple.com/wwdc26/guides/swiftui/
- "What's New in SwiftUI" session: https://developer.apple.com/videos/play/wwdc2026/269/
- WWDC26 macOS guide: https://developer.apple.com/wwdc26/guides/macos/
- What's new in macOS 27 (beta): https://developer.apple.com/macos/whats-new/
- SwiftUI what's new: https://developer.apple.com/swiftui/whats-new/
- Metal overview: https://developer.apple.com/metal/
- Metal what's new: https://developer.apple.com/metal/whats-new/

### Tooling and dependencies
- XcodeGen: https://github.com/yonaskolb/XcodeGen
- SwiftTerm (embedded PTY terminal): https://github.com/migueldeicaza/SwiftTerm
- Swift Charts: https://developer.apple.com/documentation/charts
- Observation framework: https://developer.apple.com/documentation/observation
- create-dmg: https://github.com/create-dmg/create-dmg
- Developer ID and notarization: https://developer.apple.com/developer-id/
