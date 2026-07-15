#!/bin/zsh

set -euo pipefail

if (( $# < 4 || $# > 5 )); then
  print -u2 "Usage: $0 VERSION SHA256 RELEASE_BASE_URL HOMEPAGE [OUTPUT]"
  exit 64
fi

ROOT_DIR="${0:A:h:h}"
VERSION="$1"
SHA256="$2"
RELEASE_BASE_URL="${3%/}"
HOMEPAGE="$4"
OUTPUT="${5:-$ROOT_DIR/../homebrew-cask/Casks/edifier-controller.rb}"

if [[ ! "$SHA256" =~ '^[0-9a-f]{64}$' ]]; then
  print -u2 "SHA256 must contain exactly 64 lowercase hexadecimal characters."
  exit 64
fi

mkdir -p "${OUTPUT:h}"
cp "$ROOT_DIR/packaging/homebrew/edifier-controller.rb.template" "$OUTPUT"
sed -i '' \
  -e "s|__VERSION__|$VERSION|g" \
  -e "s|__SHA256__|$SHA256|g" \
  -e "s|__RELEASE_BASE_URL__|$RELEASE_BASE_URL|g" \
  -e "s|__HOMEPAGE__|$HOMEPAGE|g" \
  "$OUTPUT"

print "Updated: $OUTPUT"
