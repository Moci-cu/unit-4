-- ══════════════════════════════════════════════
-- User overrides (converted from user.conf)
-- Loaded via require("user") from hyprland.lua
-- ══════════════════════════════════════════════

-- Animations
hl.curve("specialWorkSwitch", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("emphasizedAccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("emphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })

hl.animation({ leaf = "layersIn", enabled = true, speed = 5, bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 4, bezier = "emphasizedAccel", style = "slide" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 5, bezier = "standard" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "emphasizedDecel" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "emphasizedAccel" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 6, bezier = "standard" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "standard" })
hl.animation({
  leaf = "specialWorkspace",
  enabled = true,
  speed = 4,
  bezier = "specialWorkSwitch",
  style =
  "slidefadevert 15%"
})
hl.animation({ leaf = "fade", enabled = true, speed = 6, bezier = "standard" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 6, bezier = "standard" })
hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "standard" })

-- Decoration & animation override
hl.config({
  decoration = {
    blur = {
      enabled = true,
      new_optimizations = true,
    },
    shadow = {
      enabled = false,
    },
  },
  animations = {
    enabled = true,
  },
})

-- Extra binds
hl.bind("SUPER + ALT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + ALT + Space", hl.dsp.window.resize({ x = 1100, y = 980 }))
hl.bind("SUPER + ALT + Space", hl.dsp.window.center())

hl.bind("SUPER + ALT + H", hl.dsp.window.resize({ x = -30, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + ALT + J", hl.dsp.window.resize({ x = 0, y = 30, relative = true }), { repeating = true })
hl.bind("SUPER + ALT + K", hl.dsp.window.resize({ x = 0, y = -30, relative = true }), { repeating = true })
hl.bind("SUPER + ALT + L", hl.dsp.window.resize({ x = 30, y = 0, relative = true }), { repeating = true })
hl.bind("CTRL + ALT + H", hl.dsp.focus({ direction = "left" }))
hl.bind("CTRL + ALT + J", hl.dsp.focus({ direction = "down" }))
hl.bind("CTRL + ALT + K", hl.dsp.focus({ direction = "up" }))
hl.bind("CTRL + ALT + L", hl.dsp.focus({ direction = "right" }))
