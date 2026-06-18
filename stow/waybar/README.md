# waybar stow package (Omarchy desktop)

This package owns `~/.config/waybar/config.jsonc` and `style.css` on Omarchy.
It is intentionally conservative: use Omarchy theme colors, keep common laptop
modules visible, and avoid fragile custom scripts.

Edit in the repo, then reload:

```bash
dotfiles desktop reload waybar
```

If the helper is unavailable, run:

```bash
omarchy restart waybar
```

To restore/adapt a local pre-stow backup manually, copy from your backup into
`stow/waybar/.config/waybar/`, review the diff, then reload Waybar. Do not edit
or overwrite `~/.dotfiles-backup/...` directly.
