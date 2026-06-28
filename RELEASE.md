# Releasing Container Desktop

Container Desktop ships as a **Developer ID-signed, notarized DMG** attached to
a GitHub Release. The in-app updater (`AppUpdater`) polls
`github.com/marcelbaklouti/container-desktop/releases/latest` and offers any
newer version, so every release must be tagged with its version and attach a
`.dmg` asset.

The whole pipeline is automated by [`scripts/release.sh`](scripts/release.sh).
You only need the one-time setup below, then one command per release.

## One-time setup

1. **Apple Developer Program membership** (paid) — already in place under team
   `YW883T2H46`.

2. **Developer ID Application certificate** in your login keychain. This is
   distinct from the *Apple Distribution* certificate (which is for the Mac App
   Store) — direct, notarized DMG distribution needs *Developer ID Application*.
   Create it: Xcode ▸ Settings ▸ Accounts ▸ (your Apple ID) ▸ Manage
   Certificates ▸ **+** ▸ *Developer ID Application*. Confirm it is present:

   ```sh
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```

3. **Notary credentials** stored as a keychain profile (so the script never
   handles your password). Create an app-specific password at
   <https://account.apple.com> ▸ Sign-In and Security ▸ App-Specific Passwords,
   then:

   ```sh
   xcrun notarytool store-credentials "ContainerDesktopNotary" \
     --apple-id "marcel@baklouti.de" \
     --team-id "YW883T2H46" \
     --password "abcd-efgh-ijkl-mnop"
   ```

   (An App Store Connect API key works too — see `notarytool store-credentials --help`.)

4. Make sure you're signed into the Apple account in Xcode (Accounts), so
   automatic Developer ID signing can resolve during export.

## Cut a release

1. Bump the version. `MARKETING_VERSION` is intentionally **coupled to the
   `container` CLI version** the build targets (see `Memory.md`); update it in
   `Containers.xcodeproj` (both Debug/Release of the app target) and, if the
   targeted runtime changed, `ContainerInstaller.requiredVersion`.

2. Build, sign, notarize, staple, verify (the team is read from the project's
   `DEVELOPMENT_TEAM`; override with `DEVELOPER_ID_TEAM=…` if needed):

   ```sh
   NOTARY_PROFILE=ContainerDesktopNotary ./scripts/release.sh
   ```

   This produces `build/release/Container Desktop.dmg`, already notarized and
   stapled, and runs `spctl`/`stapler` to prove Gatekeeper will accept it.
   Add `--skip-notarize` for a local smoke build (not distributable).

3. Publish (creates the tag `v<version>`, the GitHub Release, and uploads the DMG):

   ```sh
   NOTARY_PROFILE=ContainerDesktopNotary ./scripts/release.sh --publish
   ```

## Verify on a clean machine

- Download the DMG from the Release page on a Mac that has never seen the app.
- `xcrun stapler validate "Container Desktop.dmg"` → *The validate action worked!*
- Open it, drag to Applications, launch — it should open **without** an
  "unidentified developer" warning.
- In the app, System ▸ Software Update should show "Up to date" (i.e. the
  updater can read the release).

## Landing page (Vercel)

The marketing site lives in [`landing/`](landing/) (Next.js). Deploy on Vercel
with **Root Directory = `landing`**; the rest is default. Before the first
deploy, set the real domain in `landing/lib/content.ts` (`site.url`, currently a
`// TODO` placeholder) so OpenGraph/canonical URLs are correct.

## Legal checklist (every release)

- The "not affiliated with Apple Inc." notice is present in the About window and
  on the landing page.
- No Apple logo or trade dress is used; the developer identity is visible.
- `LICENSE` (Apache-2.0), `NOTICE`, and `THIRD-PARTY-NOTICES.md` ship in the repo.
