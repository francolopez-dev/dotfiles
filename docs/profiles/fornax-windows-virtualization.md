# FORNAX Windows + Virtualization Runbook

## Purpose

FORNAX is the Omarchy laptop with Linux on `nvme1n1` and an existing Windows
installation on `nvme0n1`.

Current intent:

- Use native Windows boot for gaming when needed.
- Keep Linux as the primary Omarchy environment.
- Optionally explore Windows VM access later for work apps such as Teams,
  Outlook, and Office.
- Do not automatically modify the Windows disk, bootloader, VM definitions, or
  filesystem mounts from this repo.

Known disk interpretation:

```text
nvme1n1  Omarchy/Linux disk
nvme0n1  Existing Windows disk
```

## Safety Rules

- Do not write to the Windows disk from Linux unless intentional.
- Do not mount Windows read/write while also using it in a VM.
- Disable Windows Fast Startup before any shared/raw disk VM experiment.
- Do not hibernate Windows if Linux or a VM will access the disk.
- Be careful with BitLocker if enabled; recovery keys may be required after
  firmware, boot, TPM, or VM hardware changes.
- Prefer native boot for gaming.
- Raw disk VM access is advanced, risky, and not automatic.
- Gaming in a VM is outside this first implementation.

## Identify Disks

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINT
findmnt
ls -l /dev/disk/by-id/
sudo blkid
```

## Check Virtualization Support

```bash
lscpu | grep -i virtualization
lsmod | grep kvm
systemd-detect-virt
virt-host-validate
```

## Install/Status Commands

FORNAX virtualization packages are declared in
`packages/profile-fornax-omarchy/pacman.txt`.

```bash
pacman -Q qemu-full libvirt virt-manager edk2-ovmf swtpm dnsmasq virt-viewer
systemctl status libvirtd.service
groups
virsh --version
virt-manager --version
```

## Enable Libvirt

This repo does not currently manage profile-specific system services for
FORNAX. Enable libvirt manually if VM management is needed:

```bash
sudo systemctl enable --now libvirtd.service
sudo usermod -aG libvirt "$USER"
```

Logout or reboot after adding the user to the `libvirt` group. Until then,
`virt-manager` may not work without elevated privileges.

## Launch Tools

```bash
virt-manager
virsh list --all
```

## Default Libvirt Network

Libvirt's default NAT network needs `dnsmasq`, which is declared for FORNAX.

```bash
sudo virsh net-list --all
sudo virsh net-start default
sudo virsh net-autostart default
```

## Native Boot Into Windows

The safest manual method is usually the firmware boot menu. This repo does not
change bootloader configuration automatically.

Audit the current boot setup before using any one-time boot command:

```bash
bootctl status 2>/dev/null || true
efibootmgr -v
ls /boot
find /boot -maxdepth 3 -type f | sort
```

Only document or use a one-time boot command after confirming the active
bootloader and firmware entries on FORNAX.

## Raw Windows Disk VM Experiment

Raw disk access is advanced and risky. Do not automate it from this repo.

Identify stable disk paths before any experiment:

```bash
ls -l /dev/disk/by-id/ | grep -i nvme
ls -l /dev/disk/by-id/ | grep -i windows
```

If ever creating a VM that points at the physical Windows disk, use a stable
`/dev/disk/by-id/...` path, not `/dev/nvme0n1`.

Before experimenting:

- Disable Fast Startup in Windows first.
- Fully shut down Windows.
- Do not hibernate Windows.
- Do not mount NTFS partitions in Linux while testing.
- Snapshot or back up important data first if possible.
- Expect Windows activation and drivers to react badly when switching between
  native hardware and VM hardware.
- Gaming in a VM generally needs GPU passthrough and is outside this first
  implementation.

## Future GPU Passthrough Notes

Treat GPU passthrough as future research only.

Topics to audit later:

- IOMMU support and firmware settings.
- `vfio` binding strategy.
- Whether FORNAX has a usable dedicated GPU for passthrough.
- Looking Glass for low-latency guest display.
- Anti-cheat limitations for games.
- Laptop hybrid graphics complexity.

## Recovery / Rollback

Disable libvirt if it is no longer needed:

```bash
sudo systemctl disable --now libvirtd.service
sudo gpasswd -d "$USER" libvirt
```

Remove packages only after checking whether anything else depends on them:

```bash
sudo pacman -Rns virt-manager libvirt qemu-full edk2-ovmf swtpm dnsmasq virt-viewer
```

Be careful with package removal if other packages depend on these packages or
if VM definitions/storage are still in use.
