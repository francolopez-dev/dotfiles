-- Shared Omarchy 4 autostart additions.

-- User wrappers must take precedence over stock Omarchy commands.
local user_bin = (os.getenv("HOME") or "") .. "/.local/bin"
local kept = {}
for entry in (os.getenv("PATH") or "/usr/local/bin:/usr/bin"):gmatch("[^:]+") do
  if entry ~= user_bin then table.insert(kept, entry) end
end
table.insert(kept, 1, user_bin)
hl.env("PATH", table.concat(kept, ":"))

o.exec_on_start("omarchy-quick-surfaces-daemon")

require("default.hypr.require_optional").module("hypr.profile")
