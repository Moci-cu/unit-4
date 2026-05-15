-- ══════════════════════════════════════════════
-- Hyprland Lua config — Unit-4 NieR
-- Hyprland 0.55.1 Lua API
-- ══════════════════════════════════════════════

local mainMod = "SUPER"
local superShift = "SUPER + SHIFT"
local altShift = "ALT + SHIFT"

hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QUICK_CONTROLS_STYLE", "Basic")

hl.monitor({
  output   = "",
  mode     = "preferred",
  position = "auto",
  scale    = 1,
})

hl.config({
  general = {
    gaps_in     = 4,
    gaps_out    = 8,
    border_size = 1,
    layout      = "dwindle",
  },
  decoration = {
    rounding = 0,
    blur = {
      enabled = false,
    },
  },
  animations = {
    -- enabled = false,
  },
  misc = {
    disable_hyprland_logo        = true,
    disable_splash_rendering     = true,
    mouse_move_enables_dpms      = true,
    key_press_enables_dpms       = true,
    animate_manual_resizes       = false,
    animate_mouse_windowdragging = false,
  },
  dwindle = {
    preserve_split = true,
  },
  master = {
    new_status = "master",
    mfact      = 0.55,
  },
  input = {
    kb_layout    = "us",
    kb_options   = "caps:escape",
    follow_mouse = 1,
    sensitivity  = 0,
    touchpad     = {
      natural_scroll       = true,
      tap_to_click         = true,
      drag_lock            = true,
      disable_while_typing = true,
      scroll_factor        = 1.0,
      clickfinger_behavior = true,
    },
  },
  xwayland = {
    force_zero_scaling = true,
  },
})

-- Window rules
hl.window_rule({
  match     = { class = "quickshell" },
  float     = true,
  pin       = true,
  no_blur   = true,
  no_shadow = true,
})
hl.window_rule({
  match      = { class = "Spotify" },
  workspace  = "special:spotify",
  fullscreen = true,
})

-- Layer rules
hl.layer_rule({ match = { namespace = "quickshell" }, no_anim = true })
hl.layer_rule({ match = { namespace = "notifications" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell-network" }, no_anim = true })
hl.layer_rule({ match = { namespace = "gtk4-layer-shell" }, no_anim = true })

-- Binds

-- Launcher
hl.bind(mainMod .. " + Super_L", hl.dsp.exec_cmd("qs ipc call menu toggle"), { description = "Toggle menu" })

-- Lock / Sleep
hl.bind(mainMod .. " + L", hl.dsp.global("quickshell:lock"), { description = "Lock" })
hl.bind(superShift .. " + L", hl.dsp.exec_cmd("hyprctl dispatch \"hl.dsp.global('quickshell:lock')\" && systemctl suspend"), { description = "Lock then sleep" })

-- Panels
hl.bind(mainMod .. " + R", hl.dsp.global("quickshell:syspanelToggle"), { description = "System panel" })
hl.bind(mainMod .. " + J", hl.dsp.exec_cmd("qs ipc call bar toggle"), { description = "Toggle bar" })
hl.bind(mainMod .. " + Z", hl.dsp.global("quickshell:lyricsToggle"), { description = "Lyrics" })
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("~/.config/quickshell/ctrl-toggle.sh"), { description = "Control Center" })

-- Apps
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("/usr/bin/kitty"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("/opt/zen-browser-bin/zen-bin"))
hl.bind(mainMod .. " + M",
  hl.dsp.exec_cmd("pgrep -x spotify >/dev/null && hyprctl dispatch togglespecialworkspace spotify || spotify"))
hl.bind(superShift .. " + BackSpace", hl.dsp.exec_cmd("pkill qs"), { description = "Restart QS" })
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("~/.config/quickshell/wallpaper.sh"))

-- Window management
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + Escape", hl.dsp.exit())
hl.bind(mainMod .. " + D", hl.dsp.window.fullscreen({ max = true }))
hl.bind(superShift .. " + W", hl.dsp.exec_cmd("hyprctl keyword general:layout dwindle"))

-- Focus
hl.bind("ALT + Tab", hl.dsp.window.cycle_next())
hl.bind(altShift .. " + Tab", hl.dsp.window.cycle_next({ cycle = "prev" }))
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Move windows
hl.bind(superShift .. " + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(superShift .. " + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(superShift .. " + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(superShift .. " + down", hl.dsp.window.move({ direction = "down" }))

-- Special workspace
hl.bind(superShift .. " + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))

-- Workspaces 1-10
for i = 1, 10 do
  local key = i % 10
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(superShift .. " + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scroll workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Audio
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))

-- Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("sh -c 'brightnessctl set 5%+; qs ipc call brightness increment'"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("sh -c 'brightnessctl set 5%-; qs ipc call brightness decrement'"))

-- Screenshot
hl.bind(altShift .. " + S", hl.dsp.exec_cmd("hyprshot -m region"))
hl.bind("Print", hl.dsp.exec_cmd("grim -g \"$(slurp)\" ~/Screenshots/$(date +%Y%m%d_%H%M%S).png"))

-- Autostart
hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user start quickshell.service")
  hl.exec_cmd("systemctl --user start quickshell-ctrl.service")
  hl.exec_cmd("systemctl --user start awww-daemon.service")
  hl.exec_cmd("systemctl --user start hypridle.service")
  hl.exec_cmd("systemctl --user start battery-warning.service")
  hl.exec_cmd("systemctl --user start udiskie.service")
  hl.exec_cmd("pkill dunst")
  hl.exec_cmd("pkill mako")
  hl.exec_cmd("pkill swaync")
  -- hl.exec_cmd("waybar")  -- using QML Bar
end)

-- User overrides
require("user")
