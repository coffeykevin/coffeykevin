#!/bin/bash
# Generate the Bananarc Xcode project from the Godot project and open it.
#
# Usage (from anywhere in the repo, on macOS):
#   ./deploy/make-xcode-project.sh
#
# Optional environment overrides:
#   BUNDLE_ID=com.you.bananarc   bundle identifier baked into the project
#   TEAM_ID=ABCDE12345           Apple Team ID (or pick your team in Xcode)
#   GODOT=/path/to/godot         Godot binary if not auto-detected
#
# Prerequisites (one-time):
#   1. Install Godot 4.4+  — https://godotengine.org/download  (or: brew install --cask godot)
#   2. Open Godot once: Editor menu -> Manage Export Templates -> Download and Install
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="${BUNDLE_ID:-com.coffeykevin.bananarc}"
TEAM_ID="${TEAM_ID:-}"

# Find Godot.
if [ -z "${GODOT:-}" ]; then
  for c in "/Applications/Godot.app/Contents/MacOS/Godot" \
           "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
           "$(command -v godot || true)"; do
    if [ -n "$c" ] && [ -x "$c" ]; then GODOT="$c"; break; fi
  done
fi
if [ -z "${GODOT:-}" ]; then
  echo "Godot not found. Install it from https://godotengine.org/download"
  echo "(or: brew install --cask godot), then re-run."
  exit 1
fi
echo "Using Godot: $GODOT"

# Fill the preset placeholders on a temporary basis; restore on exit.
cp game/export_presets.cfg /tmp/bananarc_preset.bak
trap 'cp /tmp/bananarc_preset.bak game/export_presets.cfg' EXIT
sed -i '' "s/TEAM_ID_PLACEHOLDER/${TEAM_ID}/" game/export_presets.cfg
sed -i '' "s/BUNDLE_ID_PLACEHOLDER/${BUNDLE_ID}/" game/export_presets.cfg

"$GODOT" --headless --path game --import
mkdir -p build/xcode
if ! "$GODOT" --headless --path game --export-release "iOS" \
    "$PWD/build/xcode/Bananarc.ipa"; then
  echo ""
  echo "Export failed. Most common cause: export templates not installed —"
  echo "open Godot -> Editor menu -> Manage Export Templates -> Download and Install."
  exit 1
fi

PROJ=$(find build/xcode -maxdepth 1 -name "*.xcodeproj" | head -1)
echo ""
echo "Generated: $PROJ"
echo "Opening in Xcode. In Signing & Capabilities, tick 'Automatically"
echo "manage signing' and pick your team, then choose a run destination:"
echo "  - your plugged-in iPhone (installs directly, no TestFlight needed)"
echo "  - an iOS Simulator"
echo "  - My Mac (Designed for iPad) to play it on the Mac itself"
open "$PROJ"
