# Lenovo Work Laptop

## Identity

- Hostname: `lenovo`
- Profile: `laptop-work-omarchy`
- Model: Lenovo Legion Pro 7 16IAX10H
- CPU: Intel Core Ultra 9
- GPU: NVIDIA RTX 5080 Mobile
- Platform: Omarchy / Arch Linux

## Network Hardware

- Built-in Ethernet: Intel I226-V
- Built-in Ethernet status: unstable during real-world testing
- Wi-Fi: Intel Wi-Fi 7
- Wi-Fi status: stable during testing
- USB Ethernet: reliable during testing

## Bootstrap Notes

- Initial bootstrap failed before package installation because the
  `laptop-work-omarchy` profile referenced `wallpapers` and `themes` stow
  packages that were present locally but not tracked for fresh clones.
- Tailscale package was present, and manual enable worked:
  `sudo systemctl enable --now tailscaled`.
- NetworkManager package was present, but NetworkManager was not enabled or
  running. `nmcli` returned: `Error: NetworkManager is not running`.
- Recovery Pack setup is currently blocked until Age recipients and at least
  one out-of-band Age bootstrap identity are configured.

## Operational Notes

- Prefer Wi-Fi or USB Ethernet until the Intel I226-V instability is resolved.
- Do not restore Tailscale machine state. Rejoin the tailnet through normal
  login after bootstrap.
- Do not automatically enable NetworkManager from dotfiles until the expected
  Omarchy network stack is confirmed on this machine.
- Run `./bootstrap.sh --dry-run --profile laptop-work-omarchy` before real
  bootstrap after profile or stow-package changes.
