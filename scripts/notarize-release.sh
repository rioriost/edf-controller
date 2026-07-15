#!/bin/zsh

set -euo pipefail

ROOT_DIR="${0:A:h:h}"
: "${VERSION:?Set VERSION, for example VERSION=0.1.0}"

NOTARY_PROFILE="${NOTARY_PROFILE:-git-labeler-notary}"
export CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application: Ryo Fujita (23889H77KX)}"
export CASK_RELEASE_BASE_URL="${CASK_RELEASE_BASE_URL:-https://github.com/rioriost/edf-controller/releases/download}"
export CASK_HOMEPAGE="${CASK_HOMEPAGE:-https://github.com/rioriost/edf-controller}"
export CASK_OUTPUT="${CASK_OUTPUT:-$ROOT_DIR/../homebrew-cask/Casks/edifier-controller.rb}"

APP_NAME="Edifier Controller"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
ARCHIVE="$ROOT_DIR/dist/EdifierController-$VERSION.zip"
SUBMISSION_ARCHIVE="$ROOT_DIR/dist/EdifierController-$VERSION-submission.zip"

VERSION="$VERSION" "$ROOT_DIR/scripts/build-app.sh"

rm -f "$ARCHIVE" "$SUBMISSION_ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$SUBMISSION_ARCHIVE"

xcrun notarytool submit \
  "$SUBMISSION_ARCHIVE" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
spctl --assess --type execute --verbose=2 "$APP_DIR"

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE"
rm -f "$SUBMISSION_ARCHIVE"

SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
print "Notarized archive: $ARCHIVE"
print "SHA-256: $SHA256"

"$ROOT_DIR/scripts/update-cask.sh" \
  "$VERSION" \
  "$SHA256" \
  "$CASK_RELEASE_BASE_URL" \
  "$CASK_HOMEPAGE" \
  "$CASK_OUTPUT"
