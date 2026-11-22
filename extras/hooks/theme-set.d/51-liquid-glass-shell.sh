#!/bin/bash
# Liquid Glass (macOS) shell profile: bar layout + dock + clone plugins, active
# ONLY while the liquid-glass theme is set. Any other theme -> normal profile.
# Profiles: ~/.config/omarchy/shell-profiles/{normal,liquid-glass}.json
# Non-bar keys (idle, dock settings, lock-explorer config...) are carried over
# from the live shell.json so they stay in sync. Never fails the hook runner.

THEME="${1:-}"; THEME="${THEME,,}"; THEME="${THEME// /-}"
CFG="$HOME/.config/omarchy/shell.json"
PROF="$HOME/.config/omarchy/shell-profiles"
STATE="$HOME/.local/state/liquid-glass/shell-profile"
log() { echo "[liquid-glass-shell] $*" >&2; }

main() {
  command -v jq >/dev/null || { log "jq missing"; return; }
  [[ -f $CFG ]] || { log "no shell.json"; return; }
  mkdir -p "$PROF" "$(dirname "$STATE")"
  local target=normal active=normal
  [[ $THEME == liquid-glass ]] && target=liquid-glass
  # Infer the live profile from shell.json itself: a state file alone goes stale
  # when `dot apply` copies a shell.json over from another machine.
  if jq -e '[.bar.layout[]?[]?.id] | index("danluan.apple-menu") != null' "$CFG" >/dev/null 2>&1; then
    active=liquid-glass
  fi
  [[ $target == "$active" ]] && return
  [[ -f $PROF/$target.json ]] || { log "missing profile $target"; return; }
  jq -e . "$CFG" >/dev/null 2>&1 || { log "shell.json invalid, aborting"; return; }

  # 1. save live config as the active profile
  cp -f "$CFG" "$PROF/$active.json.tmp" && mv -f "$PROF/$active.json.tmp" "$PROF/$active.json"

  # 2. build target: profile's bar/enablement + live config's everything else
  local tmp="$CFG.tmp.$$"
  jq -S --slurpfile p "$PROF/$target.json" '
    def mac: ["danluan.apple-menu","danluan.dock","omarchy.menu","omarchy.dock"];
    def pick(k): ($p[0][k] // []);
    . as $c
    | ($p[0]) as $t
    | $c
    | .bar = $t.bar
    | .disabledPlugins = ((($c.disabledPlugins // []) - mac) + (pick("disabledPlugins") | map(select(. as $x | mac | index($x)))))
    | .cloneSourceRestores = ((($c.cloneSourceRestores // []) - mac) + (pick("cloneSourceRestores") | map(select(. as $x | mac | index($x)))))
    | .plugins = ((($c.plugins // []) | map(select(.id != "danluan.dock"))) + (pick("plugins") | map(select(.id == "danluan.dock"))))
    | if (.disabledPlugins | length) == 0 then del(.disabledPlugins) else . end
    | if (.cloneSourceRestores | length) == 0 then del(.cloneSourceRestores) else . end
  ' "$CFG" > "$tmp" && jq -e . "$tmp" >/dev/null 2>&1 || { rm -f "$tmp"; log "build failed"; return; }
  mv -f "$tmp" "$CFG"
  echo "$target" > "$STATE"
  log "shell profile: $active -> $target"
}
main
exit 0
