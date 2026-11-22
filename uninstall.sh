#!/usr/bin/env bash
# Removes what install.sh set up outside the theme directory: the two theme-set
# hooks and the liquid-glass shell profile. Plugins and AUR packages are kept
# unless --purge is given.
#
#   ./uninstall.sh [--dry-run] [--yes] [--purge]
set -euo pipefail

HOOKS_DIR="$HOME/.config/omarchy/hooks/theme-set.d"
PROFILES_DIR="$HOME/.config/omarchy/shell-profiles"
PLUGIN_IDS=(danluan.dock danluan.apple-menu danluan.app-menu danluan.control-center)
DEFAULT_THEME="Tokyo Night"

DRY=0; YES=0; PURGE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --yes|-y) YES=1 ;;
    --purge) PURGE=1 ;;
    -h|--help) sed -n '2,6p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
run() { if (( DRY )); then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }

command -v omarchy >/dev/null || { echo "Omarchy not found." >&2; exit 1; }
(( DRY )) && say "Dry run: nothing will be changed"

# 1. Switch away first, so the hooks restore GTK/fonts/bar before being removed.
current="$(omarchy theme current 2>/dev/null || true)"
if [[ $current == "Liquid Glass" ]]; then
  say "Liquid Glass is the current theme; switching away"
  target="$DEFAULT_THEME"
  if (( ! YES && ! DRY )); then
    echo "Available themes:"; omarchy theme list | sed 's/^/    /'
    read -r -p "Switch to which theme? [$DEFAULT_THEME] " reply || true
    [[ -n ${reply:-} ]] && target="$reply"
  fi
  run omarchy theme set "$target"
else
  note "Current theme is '${current:-unknown}', no switch needed"
fi

# 2. Hooks and profile
say "Removing hooks and profile"
for f in "$HOOKS_DIR/50-liquid-glass-appearance.sh" "$HOOKS_DIR/51-liquid-glass-shell.sh" "$PROFILES_DIR/liquid-glass.json"; do
  if [[ -e $f ]]; then note "rm $f"; run rm -f "$f"; else note "$f not present"; fi
done

# 3. Optional purge
if (( PURGE )); then
  say "Purging plugins"
  for id in "${PLUGIN_IDS[@]}"; do
    if [[ -d $HOME/.config/omarchy/plugins/$id ]]; then run omarchy plugin remove "$id" --yes; else note "$id not installed"; fi
  done
  note "AUR packages (whitesur-gtk-theme, whitesur-icon-theme, apple_cursor) were left alone; remove with: yay -Rns <pkg>"
else
  note "Plugins and AUR packages kept (use --purge to remove the plugins)"
fi
say "Done. The theme directory itself can be removed with: omarchy theme remove \"Liquid Glass\""
