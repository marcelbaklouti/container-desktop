#!/usr/bin/env bash
#
# Build, sign (Developer ID), notarize, staple, and optionally publish a
# Container Desktop release DMG. Run from the repo root.
#
# One-time setup and the full checklist live in RELEASE.md.
#
# Required environment:
#   DEVELOPER_ID_TEAM   Apple Developer Team ID (10 chars, e.g. ABCDE12345)
#   NOTARY_PROFILE      notarytool keychain profile name created with
#                       `xcrun notarytool store-credentials` (see RELEASE.md)
#
# Optional environment:
#   SIGNING_IDENTITY    codesign identity (default: "Developer ID Application")
#   VERSION             release version (default: MARKETING_VERSION from the project)
#
# Flags:
#   --publish           create the GitHub release and upload the DMG
#   --skip-notarize     build and sign only (local smoke test; not distributable)
#
set -euo pipefail

REPO="marcelbaklouti/container-desktop"
SCHEME="Containers"
PROJECT="Containers.xcodeproj"
PRODUCT="Container Desktop"
BUILD_DIR="build/release"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"

PUBLISH=0
SKIP_NOTARIZE=0
for arg in "$@"; do
  case "$arg" in
    --publish) PUBLISH=1 ;;
    --skip-notarize) SKIP_NOTARIZE=1 ;;
    *) echo "Unknown flag: $arg" >&2; exit 2 ;;
  esac
done

step() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

# --- Preflight ---------------------------------------------------------------
step "Preflight"
[ -f "$PROJECT/project.pbxproj" ] || fail "run this from the repo root (no $PROJECT found)."

# Default the team to the project's DEVELOPMENT_TEAM so it stays in sync with Xcode.
if [ -z "${DEVELOPER_ID_TEAM:-}" ]; then
  DEVELOPER_ID_TEAM="$(grep -m1 'DEVELOPMENT_TEAM' "$PROJECT/project.pbxproj" | sed -E 's/.*= ([A-Z0-9]+);.*/\1/')"
fi
[ -n "$DEVELOPER_ID_TEAM" ] || fail "set DEVELOPER_ID_TEAM (10-char Apple Team ID), or set DEVELOPMENT_TEAM in the project. See RELEASE.md."

if ! security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
  fail "no \"$SIGNING_IDENTITY\" certificate in the keychain.
       Create one in Xcode > Settings > Accounts > Manage Certificates (+ Developer ID Application),
       or at https://developer.apple.com/account/resources/certificates. See RELEASE.md."
fi

if [ "$SKIP_NOTARIZE" -eq 0 ]; then
  [ -n "${NOTARY_PROFILE:-}" ] || fail "set NOTARY_PROFILE, or pass --skip-notarize. See RELEASE.md."
fi

if [ "$PUBLISH" -eq 1 ]; then
  gh auth status >/dev/null 2>&1 || fail "gh is not authenticated (gh auth login) — needed for --publish."
fi

VERSION="${VERSION:-$(grep -m1 'MARKETING_VERSION' "$PROJECT/project.pbxproj" | sed -E 's/.*= ([0-9A-Za-z.]+);/\1/')}"
[ -n "$VERSION" ] || fail "could not determine VERSION."
echo "Version:        $VERSION"
echo "Team:           $DEVELOPER_ID_TEAM"
echo "Identity:       $SIGNING_IDENTITY"
echo "Notarize:       $([ "$SKIP_NOTARIZE" -eq 1 ] && echo no || echo "yes ($NOTARY_PROFILE)")"
echo "Publish:        $([ "$PUBLISH" -eq 1 ] && echo "yes ($REPO)" || echo no)"

ARCHIVE="$BUILD_DIR/$PRODUCT.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/$PRODUCT.app"
# Space-free, versioned filename so GitHub doesn't rewrite spaces to dots on upload.
DMG="$BUILD_DIR/Container-Desktop-$VERSION.dmg"
EXPORT_OPTS="$BUILD_DIR/ExportOptions.plist"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --- Archive -----------------------------------------------------------------
step "Archiving (Release, hardened runtime)"
xcodebuild clean archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$DEVELOPER_ID_TEAM" \
  CODE_SIGN_STYLE=Automatic \
  ENABLE_HARDENED_RUNTIME=YES \
  | grep -E 'error:|ARCHIVE SUCCEEDED|ARCHIVE FAILED' || true
[ -d "$ARCHIVE" ] || fail "archive failed."

# --- Export (Developer ID) ---------------------------------------------------
step "Exporting Developer ID app"
cat > "$EXPORT_OPTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>${DEVELOPER_ID_TEAM}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTS" \
  | grep -E 'error:|EXPORT SUCCEEDED|EXPORT FAILED' || true
[ -d "$APP" ] || fail "export failed (no $APP)."

step "Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv --verbose=4 "$APP" 2>&1 | grep -E 'Authority|TeamIdentifier|Runtime|Timestamp' || true

# --- DMG ---------------------------------------------------------------------
step "Building DMG"
DMG_STAGE="$BUILD_DIR/dmg-stage"
rm -rf "$DMG_STAGE"; mkdir -p "$DMG_STAGE"
cp -R "$APP" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create -volname "$PRODUCT" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --sign "$SIGNING_IDENTITY" --timestamp "$DMG"
echo "Built $DMG"

# --- Notarize + staple -------------------------------------------------------
if [ "$SKIP_NOTARIZE" -eq 0 ]; then
  step "Submitting to Apple notary service (waits for result)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  step "Stapling ticket"
  xcrun stapler staple "$DMG"
  step "Gatekeeper verification"
  xcrun stapler validate "$DMG"
  spctl -a -t open --context context:primary-signature -vv "$DMG" || \
    fail "Gatekeeper rejected the DMG."
else
  echo "Skipped notarization (--skip-notarize): the DMG is NOT distributable."
fi

# --- Publish -----------------------------------------------------------------
if [ "$PUBLISH" -eq 1 ]; then
  step "Creating GitHub release v$VERSION"
  gh release create "v$VERSION" "$DMG" \
    --repo "$REPO" \
    --title "$PRODUCT $VERSION" \
    --notes "Container Desktop $VERSION. Apple Silicon, macOS 26+. Download the DMG, drag the app to Applications, and on first launch right-click > Open if Gatekeeper prompts."
  echo "Published: https://github.com/$REPO/releases/tag/v$VERSION"
else
  step "Done (not published)"
  echo "DMG ready at: $DMG"
  echo "To publish:   $0 --publish   (or: gh release create v$VERSION \"$DMG\" --repo $REPO)"
fi
