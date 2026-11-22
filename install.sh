#!/usr/bin/env bash
# Liquid Glass for Omarchy - installer for everything that lives outside the
# theme directory: dependencies, the 4 plugins, the theme-set hooks and the
# shell profile. Idempotent; safe to re-run.
#
#   ./install.sh [--dry-run] [--yes] [--with-lua]
set -euo pipefail

REPO_URL="https://github.com/danluan/omarchy-liquid-glass-theme.git"
THEME_NAME="Liquid Glass"
THEME_DIR="$HOME/.config/omarchy/themes/liquid-glass"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"
HOOKS_DIR="$HOME/.config/omarchy/hooks/theme-set.d"
PROFILES_DIR="$HOME/.config/omarchy/shell-profiles"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PACMAN_DEPS=(jq 7zip cpio curl)
AUR_DEPS=(whitesur-gtk-theme whitesur-icon-theme apple_cursor)
# plugin id -> repository
PLUGINS=(
  "danluan.dock|liquid-dock-plugin"
  "danluan.apple-menu|apple-menu-plugin"
  "danluan.app-menu|app-menu-plugin"
  "danluan.control-center|control-center-plugin"
)

DRY=0
YES=0
WITH_LUA=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --yes|-y) YES=1 ;;
    --with-lua) WITH_LUA=1 ;;
    -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
run() {
  if (( DRY )); then printf '    [dry-run] %s\n' "$*"; else "$@"; fi
}
ask() { # ask "question" -> 0 if yes
  (( YES )) && return 0
  (( DRY )) && return 1
  local reply
  read -r -p "$1 [y/N] " reply || return 1
  [[ $reply =~ ^[Yy] ]]
}

NOCONF=(); (( YES )) && NOCONF=(--noconfirm)
(( DRY )) && say "Dry run: nothing will be changed"

# 1. Sanity checks ------------------------------------------------------------
say "Checking environment"
command -v omarchy >/dev/null || { echo "Omarchy not found (no 'omarchy' command). This theme needs Omarchy." >&2; exit 1; }
[[ -d $HERE/extras ]] || { echo "extras/ not found next to install.sh; run it from a full clone of the theme repo." >&2; exit 1; }

if [[ $HERE == "$THEME_DIR" ]]; then
  note "Running from the installed theme directory"
elif [[ -d $THEME_DIR ]]; then
  note "Running from $HERE; theme is already installed in $THEME_DIR"
else
  note "The theme itself is not installed yet (expected in $THEME_DIR)"
  if ask "Run 'omarchy theme install $REPO_URL' now?"; then
    run omarchy theme install "$REPO_URL"
  else
    echo "Install the theme first:  omarchy theme install $REPO_URL" >&2
    (( DRY )) || exit 1
  fi
fi

# 2. Dependencies -------------------------------------------------------------
say "Checking dependencies"
missing=()
for p in "${PACMAN_DEPS[@]}"; do pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p"); done
if (( ${#missing[@]} )); then
  note "Installing with pacman: ${missing[*]}"
  run sudo pacman -S --needed "${NOCONF[@]}" "${missing[@]}"
else
  note "pacman packages OK (${PACMAN_DEPS[*]})"
fi
missing=()
for p in "${AUR_DEPS[@]}"; do pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p"); done
if (( ${#missing[@]} )); then
  if command -v yay >/dev/null; then
    note "Installing with yay: ${missing[*]}"
    run yay -S --needed "${NOCONF[@]}" "${missing[@]}"
  else
    echo "    ! yay not found. Install these AUR packages manually: ${missing[*]}" >&2
  fi
else
  note "AUR packages OK (${AUR_DEPS[*]})"
fi

# 3. Plugins ------------------------------------------------------------------
# Plugins are only added, not enabled: the shell profile switched by the
# 51-liquid-glass-shell.sh hook places them on the bar / enables the dock while
# the theme is active, and restores your normal profile on other themes.
say "Installing plugins"
for entry in "${PLUGINS[@]}"; do
  id="${entry%%|*}"; repo="${entry##*|}"
  if [[ -d $PLUGINS_DIR/$id ]]; then
    note "$id already installed"
  else
    note "Adding $id"
    run omarchy plugin add "https://github.com/danluan/$repo.git" --yes
  fi
done

# 4. Hooks and profile --------------------------------------------------------
say "Installing theme-set hooks"
run mkdir -p "$HOOKS_DIR" "$PROFILES_DIR"
for hook in "$HERE"/extras/hooks/theme-set.d/*.sh; do
  dest="$HOOKS_DIR/$(basename "$hook")"
  note "$(basename "$hook") -> $dest"
  run install -m 755 "$hook" "$dest"
done

say "Installing shell profile"
if [[ -e $PROFILES_DIR/liquid-glass.json ]]; then
  note "$PROFILES_DIR/liquid-glass.json already exists; leaving it untouched"
else
  run install -m 644 "$HERE/extras/shell-profiles/liquid-glass.json" "$PROFILES_DIR/liquid-glass.json"
fi

# Omarchy ignores hyprland.lua, neovim.lua and vscode.json for themes that still
# have a .git directory (installed via 'omarchy theme install'), because Lua and
# VS Code extensions run code. Without them you lose the blur, animations and
# macOS title bars. Removing .git makes the theme "yours" so they are applied.
say "Checking Lua/VS Code support"
if [[ -d $THEME_DIR/.git ]]; then
  note "Omarchy will ignore hyprland.lua, neovim.lua and vscode.json while $THEME_DIR is a git clone."
  if (( WITH_LUA )); then
    note "Removing $THEME_DIR/.git (--with-lua); 'omarchy theme update' will no longer work for this theme"
    run rm -rf "$THEME_DIR/.git"
  else
    note "Review them, then re-run with --with-lua to trust this theme's Lua (removes its .git)."
  fi
else
  note "OK (theme directory is not a git clone)"
fi

# 5. Activate -----------------------------------------------------------------
say "Activating theme"
if ask "Apply the '$THEME_NAME' theme now?"; then
  run omarchy theme set "$THEME_NAME"
else
  note "Apply it later with:  omarchy theme set \"$THEME_NAME\""
fi

say "Done."
note "Optional: ~/.config/omarchy/plugins/danluan.control-center/install.sh integrates the control center with Super+Ctrl shortcuts (see its README)."
