-- Liquid Glass (macOS Tahoe) Hyprland tuning. Loaded ONLY while this theme is
-- current (default/hypr/omarchy.lua requires omarchy.current.theme.hyprland
-- BEFORE ~/.config/hypr/*.lua and the bar-glassy toggle), so the user's
-- looknfeel.lua and toggles load afterwards and would override it. Anything
-- they may override is therefore re-applied in a config.reloaded handler.

local active_border_color = "rgba(ffffff30)"
local inactive_border_color = "rgba(ffffff14)"

local function liquid_glass_decoration()
  hl.config({
    general = {
      gaps_in = 6,
      gaps_out = 11,
      border_size = 1,
      col = {
        active_border = active_border_color,
        inactive_border = inactive_border_color,
      },
    },

    group = {
      col = {
        border_active = active_border_color,
        border_inactive = inactive_border_color,
      },
    },

    decoration = {
      rounding = 14,
      rounding_power = 3, -- squircle-ish corners
      active_opacity = 1.0,
      inactive_opacity = 1.0,

      shadow = {
        enabled = true,
        range = 36,
        render_power = 3,
        offset = { 0, 8 },
        color = "rgba(00000055)",
        color_inactive = "rgba(00000030)",
      },

      blur = {
        enabled = true,
        size = 9,
        passes = 3,
        vibrancy = 0.25,
        vibrancy_darkness = 0.2,
        contrast = 1.0,
        brightness = 1.0,
        noise = 0.01,
        popups = true,
        special = true,
        xray = false,
        new_optimizations = true,
      },
    },
  })
end

liquid_glass_decoration()

-- Apple-like curves: fast start, smooth settle, no overshoot.
hl.curve("apple", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1 } } })
hl.curve("spring", { type = "bezier", points = { { 0.32, 0.72 }, { 0, 1 } } })
hl.curve("appleIn", { type = "bezier", points = { { 0.4, 0 }, { 1, 1 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "spring" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "spring", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "appleIn", style = "popin 92%" })
hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "apple" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "apple" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 3, bezier = "apple" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2.5, bezier = "apple" })
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "apple" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3.5, bezier = "spring", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.5, bezier = "apple", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "spring", style = "slide" })

-- Blur translucent Omarchy shell surfaces (skip fully transparent regions).
hl.layer_rule({
  match = { namespace = "^(omarchy-bar|omarchy-dock|omarchy-dock-apps|omarchy-menu|omarchy-notifications|omarchy-osd|omarchy-polkit|omarchy-reminders|omarchy-clipboard|omarchy-emojis|omarchy-image-selector|omarchy-keyboard-panel|omarchy-network-qr)$" },
  blur = true,
  ignore_alpha = 0.1,
})

-- User looknfeel.lua (rounding) and the Glassy bar toggle (blur) load after
-- this file; re-apply once the whole config has loaded.
hl.on("config.reloaded", liquid_glass_decoration)
hl.on("hyprland.start", liquid_glass_decoration)

-- ---------------------------------------------------------------------------
-- macOS-style title bars (hyprbars via omarchy-hyprland-titlebars).
-- Omarchy's workspace-modes loads the plugin and adds its own right-aligned
-- glyph buttons AFTER this file, so: (1) wrap add_button once the plugin is
-- loaded to swap in traffic lights, (2) re-apply the bar options on reload.
-- Only this theme loads this file, so other themes keep the stock bars.
-- ---------------------------------------------------------------------------
local function liquid_glass_titlebar_options()
  if not hl.plugin or not hl.plugin.hyprbars then
    return
  end
  hl.config({
    plugin = {
      hyprbars = {
        bar_height = 30,
        bar_color = "rgb(1f1f21)",
        bar_color_inactive = "rgb(1c1c1e)",
        col = { text = "rgb(f5f5f7)" },
        bar_text_font = "SF Pro Text",
        bar_text_size = 13,
        bar_text_weight = 500,
        bar_text_align = "center",
        bar_buttons_alignment = "left",
        bar_part_of_window = true,
        bar_precedence_over_border = true,
        bar_padding = 12,
        bar_button_padding = 8,
        button_rounding = 6,
        icon_on_hover = true,
        inactive_button_color = "rgb(4d4d4f)",
      },
    },
  })
end

local function liquid_glass_traffic_lights(plugin)
  if plugin.__liquid_glass then
    return
  end
  plugin.__liquid_glass = true
  local original_add_button = plugin.add_button
  local added = false
  plugin.add_button = function()
    if added then
      return
    end
    added = true
    local window = [[window = "address:%WINDOW%"]]
    for _, button in ipairs({
      { bg = "rgb(ff5f57)", icon = "×", action = "hyprctl dispatch 'hl.dsp.window.close({ " .. window .. " })'" },
      { bg = "rgb(febc2e)", icon = "−", action = "omarchy-hyprland-window-minimize %WINDOW%" },
      { bg = "rgb(28c840)", icon = "+", action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\", " .. window .. " })'" },
    }) do
      original_add_button({
        bg_color = button.bg,
        fg_color = "rgb(4a1a17)",
        size = 12,
        icon = button.icon,
        action = button.action,
      })
    end
  end
end

do
  local original_load = hl.plugin.load
  hl.plugin.load = function(...)
    local result = original_load(...)
    if hl.plugin.hyprbars then
      liquid_glass_traffic_lights(hl.plugin.hyprbars)
    end
    return result
  end
end
if hl.plugin.hyprbars then
  liquid_glass_traffic_lights(hl.plugin.hyprbars)
end

hl.on("config.reloaded", liquid_glass_titlebar_options)
hl.on("hyprland.start", liquid_glass_titlebar_options)
