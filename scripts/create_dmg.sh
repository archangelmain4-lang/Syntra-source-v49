#!/usr/bin/env bash
# create_dmg.sh — packages Syntra.app into a distributable DMG
# Usage: ./scripts/create_dmg.sh <path-to-app-bundle> <arch> <version>
#   e.g. ./scripts/create_dmg.sh build/arm64/Syntra.app arm64 1.0.0
set -euo pipefail

APP_PATH="${1:?Usage: $0 <app-path> <arch> <version>}"
ARCH="${2:?arch required}"
VERSION="${3:-1.0.0}"

APP_NAME="Syntra"
DMG_NAME="${APP_NAME// /-}-${VERSION}-${ARCH}.dmg"
STAGING_DIR="$(mktemp -d)"
VOLUME_NAME="${APP_NAME} ${VERSION}"

echo "▶ Staging app for DMG..."
cp -R "${APP_PATH}" "${STAGING_DIR}/"

# Create a symbolic link to /Applications for easy drag-install
ln -s /Applications "${STAGING_DIR}/Applications"

echo "▶ Creating DMG: ${DMG_NAME}"
hdiutil create \
  -volname "${VOLUME_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_NAME}"

rm -rf "${STAGING_DIR}"
echo "✅ Created: ${DMG_NAME}"
