-- Personal Hyprland look and feel for Omarchy 4.

hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 6,
    border_size = 2,
    col = {
      active_border = "rgba(50fa7bff)",
      inactive_border = "rgba(44475aaa)",
    },
  },

  decoration = {
    rounding = 8,
    dim_inactive = true,
    dim_strength = 0.08,
    shadow = {
      enabled = true,
      range = 6,
      render_power = 3,
      color = "rgba(1a1a1acc)",
    },
    blur = {
      enabled = true,
      size = 3,
      passes = 2,
      brightness = 0.65,
      contrast = 0.80,
      noise = 0.02,
    },
  },
})

hl.curve("expo", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("smoothOut", { type = "bezier", points = { { 0.36, 0 }, { 0.66, -0.56 } } })
hl.curve("snap", { type = "bezier", points = { { 0.1, 1 }, { 0.1, 1 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 3.5, bezier = "expo", style = "popin 80%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.5, bezier = "expo", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "smoothOut", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "expo" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "expo" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 2.5, bezier = "expo" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.8, bezier = "smoothOut" })
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "expo" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3.5, bezier = "expo", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "smoothOut", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, bezier = "expo" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.5, bezier = "smoothOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "expo", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "expo", style = "slidevert" })
