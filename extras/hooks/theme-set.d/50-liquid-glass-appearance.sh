#!/bin/bash
# Liquid Glass (macOS) appearance: GTK/icon/cursor/fonts, active ONLY while the
# liquid-glass theme is set. Entering saves the normal values to
# ~/.local/state/liquid-glass/normal.env; any other theme restores them.
# Never fails the hook runner.

THEME="${1:-}"
THEME="${THEME,,}"; THEME="${THEME// /-}"
STATE="$HOME/.local/state/liquid-glass"
ENVF="$STATE/normal.env"
FC="$HOME/.config/fontconfig/conf.d/60-liquid-glass.conf"
GTK4="$HOME/.config/gtk-4.0"
WS="/usr/share/themes/WhiteSur-Dark/gtk-4.0"
S=org.gnome.desktop.interface
KEYS=(gtk-theme icon-theme color-scheme cursor-theme cursor-size font-name document-font-name monospace-font-name)

log() { echo "[liquid-glass] $*" >&2; }
gget() { gsettings get "$S" "$1" 2>/dev/null; }
gset() { gsettings set "$S" "$1" "$2" 2>/dev/null || log "gsettings $1 failed"; }

fc_refresh() { fc-cache -f >/dev/null 2>&1 || true; }

apply() {
  mkdir -p "$STATE"

  # First activation on a new machine: fetch SF Pro / SF Mono from Apple in the
  # background, then re-run this hook so the fonts get applied.
  local fonts="$HOME/.config/omarchy/themes/liquid-glass/install-apple-fonts.sh"
  if [[ -x $fonts ]] && ! { fc-list : family | grep -qi '^SF Pro' && fc-list : family | grep -qi '^SF Mono'; } \
     && [[ ! -e $STATE/fonts-installing ]]; then
    touch "$STATE/fonts-installing"
    setsid -f bash -c '
      if "$1" >"$2/fonts-install.log" 2>&1; then
        notify-send "Liquid Glass" "SF Pro and SF Mono installed" 2>/dev/null
        [[ $(omarchy theme current 2>/dev/null) == "Liquid Glass" ]] && "$3" liquid-glass
      else
        notify-send -u critical "Liquid Glass" "Failed to install Apple fonts, see $2/fonts-install.log" 2>/dev/null
      fi
      rm -f "$2/fonts-installing"' _ "$fonts" "$STATE" "$0" >/dev/null 2>&1 </dev/null
  fi
  if [[ ! -f $ENVF ]]; then
    {
      for k in "${KEYS[@]}"; do
        v=$(gget "$k")
        # If a previous run left macOS values in place, fall back to Omarchy defaults.
        case "$k:$v" in
          gtk-theme:*WhiteSur*) v="'Adwaita-dark'" ;;
          icon-theme:*WhiteSur*) v="'Yaru-blue'" ;;
          cursor-theme:*macOS*) v="'default'" ;;
          font-name:*SF*) v="'Adwaita Sans 11'" ;;
          document-font-name:*SF*) v="'Adwaita Sans 12'" ;;
          monospace-font-name:*SF*) v="'Adwaita Mono 11'" ;;
        esac
        printf '%s=%q\n' "${k//-/_}" "$v"
      done
      # GTK4 css files that were real files (restored on exit)
      for f in gtk.css gtk-dark.css; do
        if [[ -e $GTK4/$f && ! -L $GTK4/$f ]]; then cp -p "$GTK4/$f" "$STATE/gtk4-$f.normal"; fi
      done
    } > "$ENVF.tmp" && mv "$ENVF.tmp" "$ENVF"
  fi

  gset gtk-theme "'WhiteSur-Dark'"
  gset icon-theme "'WhiteSur-dark'"
  gset color-scheme "'prefer-dark'"
  gset cursor-theme "'macOS'"
  gset cursor-size 24
  gset font-name "'SF Pro Text 11'"
  gset document-font-name "'SF Pro Text 11'"
  # monospace is pinned by 50-omarchy.conf, so SF Mono (if installed) goes via GTK only.
  if fc-list : family 2>/dev/null | grep -qi '^SF Mono'; then gset monospace-font-name "'SF Mono 11'"; fi
  hyprctl setcursor macOS 24 >/dev/null 2>&1 || log "hyprctl setcursor failed"

  # libadwaita / GTK4 apps ignore gtk-theme; WhiteSur ships GTK4 css to link in.
  if [[ -f $WS/gtk.css ]]; then
    mkdir -p "$GTK4"
    for f in gtk.css gtk-dark.css; do
      [[ -e $WS/$f ]] && ln -sfn "$WS/$f" "$GTK4/$f"
    done
  fi

  # Fontconfig: SF Pro for sans/system-ui, SF Mono for monospace only if present.
  mkdir -p "$(dirname "$FC")"
  {
    echo '<?xml version="1.0"?>'
    echo '<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">'
    echo '<!-- Managed by 50-liquid-glass-appearance.sh; exists only while the liquid-glass theme is active. -->'
    echo '<fontconfig>'
    # /etc/fonts/conf.d/50-omarchy.conf rewrites sans-serif/system-ui to
    # "Liberation Sans" before user conf.d runs, so match that.
    echo '  <match target="pattern"><test qual="any" name="family"><string>Liberation Sans</string></test><edit name="family" mode="prepend_first" binding="strong"><string>SF Pro Text</string><string>SF Pro Display</string></edit></match>'
    echo '</fontconfig>'
  } > "$FC"
  fc_refresh
}

restore() {
  [[ -f $ENVF ]] || { rm -f "$FC"; return 0; }
  # shellcheck disable=SC1090
  source "$ENVF"
  # gtk/icon theme: omarchy-theme-set-gnome has already set the new theme's own
  # values; only undo ours if they are still the WhiteSur ones.
  [[ $(gget gtk-theme) == *WhiteSur* ]] && gset gtk-theme "${gtk_theme:-'Adwaita-dark'}"
  [[ $(gget icon-theme) == *WhiteSur* && ${icon_theme:-} != *WhiteSur* && -n ${icon_theme:-} ]] && gset icon-theme "$icon_theme"
  gset color-scheme "${color_scheme:-'prefer-dark'}"
  gset cursor-theme "${cursor_theme:-'default'}"
  gset cursor-size "${cursor_size:-24}"
  gset font-name "${font_name:-'Adwaita Sans 11'}"
  gset document-font-name "${document_font_name:-'Adwaita Sans 12'}"
  gset monospace-font-name "${monospace_font_name:-'Adwaita Mono 11'}"
  local ct=${cursor_theme//\'/}
  hyprctl setcursor "${ct:-default}" "${cursor_size:-24}" >/dev/null 2>&1 || log "hyprctl setcursor failed"

  for f in gtk.css gtk-dark.css; do
    if [[ -L $GTK4/$f ]]; then
      rm -f "$GTK4/$f"
      [[ -f $STATE/gtk4-$f.normal ]] && cp -p "$STATE/gtk4-$f.normal" "$GTK4/$f"
    fi
    rm -f "$STATE/gtk4-$f.normal"
  done
  rm -f "$FC"; rmdir "$(dirname "$FC")" 2>/dev/null; fc_refresh
  rm -f "$ENVF"
}

if [[ $THEME == liquid-glass ]]; then apply; else restore; fi
exit 0
