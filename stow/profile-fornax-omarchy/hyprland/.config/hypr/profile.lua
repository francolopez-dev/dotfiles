-- Omarchy 4 profile behavior for fornax.

hl.config({ misc = { vrr = 1 } })

o.exec_on_start("sh -lc 'sleep 1; powerprofilesctl set balanced'")
o.exec_on_start("sh -lc 'command -v hypridle >/dev/null || exit 0; mkdir -p ~/.local/state/omarchy/indicators; : > ~/.local/state/omarchy/indicators/stay-awake; exec hypridle'")
