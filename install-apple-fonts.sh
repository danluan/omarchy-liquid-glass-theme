#!/bin/bash
# Installs Apple's SF Pro and SF Mono into ~/.local/share/fonts/apple, straight
# from Apple's developer CDN. The AUR apple-fonts package breaks whenever Apple
# re-publishes the DMGs (new checksums, new package layout), so this extracts
# them itself: DMG -> .pkg (xar) -> Payload (gzip'd cpio) -> fonts.
#
# Needs 7zip (7z), cpio and curl. Safe to re-run; skips fonts already present.
# Run by hooks/theme-set.d/50-liquid-glass-appearance.sh when missing.
set -euo pipefail

DEST="$HOME/.local/share/fonts/apple"
BASE="https://devimages-cdn.apple.com/design/resources/download"

have() { fc-list : family 2>/dev/null | grep -i "^$1" >/dev/null; }

if have "SF Pro" && have "SF Mono"; then
  echo "SF Pro and SF Mono already installed"
  exit 0
fi

for cmd in 7z cpio curl; do
  command -v "$cmd" >/dev/null || { echo "missing $cmd (install 7zip/cpio/curl)" >&2; exit 1; }
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$DEST"

fetch() { # <name e.g. SF-Pro>
  local name=$1 dir="$work/$1"
  mkdir -p "$dir/dmg" "$dir/pkg" "$dir/out"
  echo "Downloading $name.dmg from Apple..."
  curl -fsSL --retry 3 -o "$dir/$name.dmg" "$BASE/$name.dmg"
  7z x -y -o"$dir/dmg" "$dir/$name.dmg" >/dev/null
  local pkg
  pkg=$(find "$dir/dmg" -maxdepth 3 -name '*.pkg' | head -1)
  [[ -n $pkg ]] || { echo "$name: no .pkg inside the DMG" >&2; return 1; }
  7z x -y -o"$dir/pkg" "$pkg" >/dev/null
  local payload
  payload=$(find "$dir/pkg" -name Payload -type f | head -1)
  [[ -n $payload ]] || { echo "$name: no Payload inside the .pkg" >&2; return 1; }
  (cd "$dir/out" && { gzip -dc "$payload" 2>/dev/null || cat "$payload"; } | cpio -idm --quiet)
  find "$dir/out" -type f \( -name '*.otf' -o -name '*.ttf' \) -exec cp -f {} "$DEST/" \;
  echo "$name installed"
}

have "SF Pro" || fetch SF-Pro
have "SF Mono" || fetch SF-Mono
fc-cache -f "$DEST" >/dev/null
echo "Done: $(find "$DEST" -type f | wc -l) font files in $DEST"
