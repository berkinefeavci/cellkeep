#!/bin/bash
# Usage: Tools/update-cask.sh <version> <path/to/Cellkeep-<version>.dmg>
# Rewrites Packaging/homebrew/cellkeep.rb for a new release: version and the DMG's SHA-256.
# Run it after release.sh with the exact DMG you upload to the GitHub release.
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1:?usage: Tools/update-cask.sh <version> <dmg>}"
dmg="${2:?usage: Tools/update-cask.sh <version> <dmg>}"
[[ "$version" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]] || { echo "not a version: $version" >&2; exit 2; }
[[ -f "$dmg" ]] || { echo "no such file: $dmg" >&2; exit 2; }
[[ "$(basename "$dmg")" == "Cellkeep-$version.dmg" ]] || { echo "expected Cellkeep-$version.dmg, got $(basename "$dmg")" >&2; exit 2; }
sha="$(shasum -a 256 "$dmg" | awk '{print $1}')"
cask=Packaging/homebrew/cellkeep.rb
sed -i.bak -E "s/^  version \"[^\"]+\"/  version \"$version\"/; s/^  sha256 \"[0-9a-f]{64}\"/  sha256 \"$sha\"/" "$cask"
rm -f "$cask.bak"
grep -q "^  version \"$version\"" "$cask" && grep -q "^  sha256 \"$sha\"" "$cask"
printf 'Cask updated: version %s, sha256 %s\n' "$version" "$sha"
