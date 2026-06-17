# Lenovo Work Laptop Notes

Target profile: `laptop-work-omarchy`.

Observed hardware:

- Hostname: `lenovo`
- Chassis: laptop
- Model: Lenovo Legion Pro 7 16IAX10H
- OS as reported by `hostnamectl`: Arch Linux
- Kernel observed during testing: 7.0.9-arch2-1
- GPU: Intel Arrow Lake-S iGPU + NVIDIA RTX 5080 Mobile
- Ethernet: Intel I226-V rev 04
- Wi-Fi: Intel Wi-Fi 7 AX1775/AX1790/BE20/BE401/BE1750

Observed hardware behavior during Omarchy testing:

- Built-in Intel I226-V Ethernet can intermittently freeze.
- USB Ethernet adapter has been reliable.
- Wi-Fi appears usable in testing.
- `nmcli` was missing during initial testing.
- Omarchy desktop/laptop profiles install `networkmanager` so NetworkManager CLI tools are available.
- Omarchy desktop/laptop profiles install `tailscale` so the declared Tailscale service has a matching package.
- Friendly service `tailscale` maps to `tailscaled.service` on Omarchy/Arch.
- First Tailscale use still requires authentication:
  `sudo systemctl enable --now tailscaled` and `sudo tailscale up`.
- If the built-in Ethernet remains unstable, keep that interface disabled and use USB Ethernet or Wi-Fi.

These are operational notes only. The dotfiles bootstrap does not automate driver, kernel, or NetworkManager changes for this issue.
