-- Input for fornax.

hl.config({
  input = {
    kb_options = "compose:caps,altwin:swap_alt_win",
    touchpad = {
      natural_scroll = true,
      disable_while_typing = true,
      clickfinger_behavior = true,
      scroll_factor = 0.4,
    },
  },
})

o.bind("SUPER + SHIFT + ESCAPE", "Reset input stack", "sh -lc 'voxtype record cancel; hyprctl dispatch submap reset; pkill fcitx5; uwsm-app -- fcitx5 --disable notificationitem'")
