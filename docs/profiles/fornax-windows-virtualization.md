# FORNAX Windows + Virtualization Runbook

## Purpose

FORNAX is the Omarchy laptop with Linux and an existing Windows installation on
separate internal NVMe disks. Do not rely on `/dev/nvmeXnY` numbering; it has
already changed across boots.

General Omarchy libvirt setup and normal Debian development VMs are documented in
[`../omarchy-virtualization.md`](../omarchy-virtualization.md). This document is
only for FORNAX-specific Windows/raw-disk and NVIDIA passthrough notes.

Use cases:

- Native boot into Windows for gaming.
- Optional Windows VM access for work apps such as Teams, Outlook, and Office.
- Regular Linux VMs, especially Ubuntu Server, for coding and disposable dev
  environments.
- Future GPU passthrough research, not automatic configuration.

This repo declares VM tooling in profile package manifests. It does not create
VMs, mount NTFS, edit fstab, edit bootloader entries, or bind GPUs to VFIO.

## FORNAX Hardware Summary

Observed from `lscpu`, `lspci`, and `lsblk`:

```text
CPU:          Intel Core Ultra 9 275HX, 24 cores, VT-x present
iGPU:         Intel Arrow Lake-S Graphics, PCI 00:02.0, driver i915
dGPU:         NVIDIA GeForce RTX 5080 Max-Q / Mobile, PCI 02:00.0, driver nvidia
dGPU audio:   NVIDIA HD Audio, PCI 02:00.1, driver snd_hda_intel
Linux SSD:    currently nvme0n1, LUKS + btrfs, mounted as Linux root/home
Windows SSD:  currently nvme1n1, existing Windows install, NTFS label Windows-SSD
IOMMU group:  NVIDIA 02:00.0 and 02:00.1 are isolated together in group 12
```

Stable Windows disk path observed on FORNAX:

```text
/dev/disk/by-id/nvme-WD_PC_SN8000S_SDEPNRK-1T00-1101_25100E4A5Y08
```

Re-check this path before using it. Do not rely on `/dev/nvme0n1` or
`/dev/nvme1n1` staying the same across boots.

## Recommended Approach

Best default plan:

- Use native Windows boot for gaming.
- Use normal libvirt/QEMU VMs for Ubuntu Server and disposable coding systems.
- If Windows VM access is needed, first use the non-GPU-passthrough raw Windows
  disk VM for work apps only.
- Treat NVIDIA GPU passthrough as an explicit boot-mode experiment, not the
  default VM path.

Why:

- The NVIDIA RTX 5080 Mobile is currently used by Linux via the `nvidia` driver.
- Laptop hybrid graphics and display routing make GPU passthrough more fragile
  than on a desktop with a spare GPU.
- Raw Windows disk VM access already carries filesystem, activation, and driver
  risk. Adding GPU passthrough increases complexity significantly.
- Native Windows boot remains the cleanest path for gaming and anti-cheat.

## Safety Rules

- Do not write to the Windows disk from Linux unless intentional.
- Do not mount Windows read/write while also using it in a VM.
- Disable Windows Fast Startup before any shared/raw disk VM experiment.
- Do not hibernate Windows if Linux or a VM will access the disk.
- Be careful with BitLocker if enabled; recovery keys may be required after
  firmware, boot, TPM, Secure Boot, or VM hardware changes.
- Prefer native boot for gaming.
- Raw disk VM access is advanced, risky, and not automatic.
- GPU passthrough is not automatic. Use it only from an explicit VFIO boot mode.

## Stowed FORNAX Files

The recoverable profile state lives under `stow/profile-fornax-omarchy/`:

```text
stow/profile-fornax-omarchy/libvirt/.config/libvirt/libvirt.conf
stow/profile-fornax-omarchy/scripts/.local/bin/fornax-virt-status
stow/profile-fornax-omarchy/scripts/.local/bin/fornax-libvirt-setup
stow/profile-fornax-omarchy/scripts/.local/bin/fornax-gpu-passthrough-status
stow/profile-fornax-omarchy/scripts/.local/bin/fornax-windows-raw-nvme-define
stow/profile-fornax-omarchy/scripts/.local/share/applications/fornax-virt-manager-system.desktop
stow/profile-fornax-omarchy/scripts/.local/share/applications/fornax-windows-raw-nvme.desktop
```

`libvirt.conf` sets the user-level libvirt default URI to `qemu:///system` on
FORNAX only. Root-owned libvirt state under `/etc/libvirt` and bootloader state
under `/boot` are intentionally not normal Stow targets; recreate them with the
profile scripts after reinstall.

After a fresh FORNAX reinstall:

```bash
dotfiles update
fornax-libvirt-setup
```

Then log out or reboot so the `libvirt` group membership applies.

Status/audit command:

```bash
fornax-virt-status
```

## Package Layer

Reusable virtualization packages are declared in the Omarchy OS layer so normal
development VMs are available on any Omarchy machine:

```text
packages/os-omarchy/pacman.txt
```

Current toolkit:

```text
qemu-full
libvirt
virt-manager
edk2-ovmf
swtpm
dnsmasq
iptables
virt-viewer
virt-install
guestfs-tools
spice-vdagent
dmidecode
osinfo-db
```

Notes:

- `dnsmasq` and `iptables` support libvirt default NAT networking.
- `edk2-ovmf` provides UEFI firmware for modern guests.
- `swtpm` supports Windows 11 style TPM-backed VM setups.
- `virt-install` gives a repeatable CLI path for Debian/Ubuntu Server VMs.
- `osinfo-db` provides guest OS metadata used by `virt-install`.
- `guestfs-tools` is useful for inspecting VM disk images; use carefully.
- `spice-vdagent` is mainly for Linux guests, not the Windows host.

## Identify Disks

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
findmnt
ls -l /dev/disk/by-id/
sudo blkid
```

Current observed high-level layout on FORNAX:

```text
nvme0n1  Linux disk
nvme1n1  Windows disk
```

This is informational only. Use `/dev/disk/by-id/...` for VM definitions.

## Check Virtualization Support

```bash
lscpu | grep -i virtualization
lsmod | grep kvm
systemd-detect-virt
virt-host-validate
```

Expected CPU capability:

```text
Virtualization: VT-x
```

If `virt-host-validate` reports IOMMU warnings, that matters mostly for GPU or
PCI passthrough. Regular VMs can still work with CPU virtualization alone.

## Install/Status Commands

```bash
pacman -Q qemu-full libvirt virt-manager edk2-ovmf swtpm dnsmasq iptables virt-viewer virt-install guestfs-tools spice-vdagent dmidecode
systemctl status libvirtd.service
groups
virsh --version
virt-manager --version
virt-install --version
```

## Enable Libvirt

Enable libvirt with the stowed FORNAX helper:

```bash
fornax-libvirt-setup
```

Logout or reboot after adding the user to the `libvirt` group. Until then,
`virt-manager` may not work without elevated privileges.

## Default Libvirt Network

`fornax-libvirt-setup` defines the default NAT network if needed, starts it, and
marks it for autostart.

Confirm networking after starting it:

```bash
virsh net-list --all
ip addr show virbr0
```

## Launch Tools

```bash
virt-manager -c qemu:///system
virsh list --all
```

FORNAX also has profile-only desktop launchers for `Virt Manager (System)` and
`Windows Raw NVMe VM`.

## Ubuntu Server VM For Coding

This is the safest first VM workflow. It uses a normal qcow2 disk image on the
Linux SSD and does not touch the Windows disk.

Create a VM storage directory:

```bash
mkdir -p "$HOME/VMs/iso" "$HOME/VMs/disks"
```

Download an Ubuntu Server ISO manually into `~/VMs/iso/`, then create a VM:

```bash
virt-install \
  --name ubuntu-server-dev \
  --memory 8192 \
  --vcpus 8 \
  --cpu host-passthrough \
  --disk path="$HOME/VMs/disks/ubuntu-server-dev.qcow2",size=80,bus=virtio,format=qcow2 \
  --cdrom "$HOME/VMs/iso/ubuntu-24.04.2-live-server-amd64.iso" \
  --os-variant ubuntu24.04 \
  --network network=default,model=virtio \
  --graphics spice \
  --video virtio \
  --boot uefi
```

Adjust the ISO filename for the release you downloaded. If `ubuntu24.04` is not
known on the machine, list known variants:

```bash
osinfo-query os | grep -i ubuntu
```

Useful Ubuntu VM commands:

```bash
virsh list --all
virsh start ubuntu-server-dev
virsh shutdown ubuntu-server-dev
virt-viewer ubuntu-server-dev
virsh console ubuntu-server-dev
```

Recommended coding setup inside the Ubuntu VM:

```bash
sudo apt update
sudo apt install -y build-essential git curl ca-certificates openssh-server tmux ripgrep fd-find jq
sudo systemctl enable --now ssh
ip addr
```

Then connect from FORNAX:

```bash
ssh <vm-user>@<vm-ip>
```

Snapshot before risky changes:

```bash
virsh snapshot-create-as ubuntu-server-dev before-risky-change
virsh snapshot-list ubuntu-server-dev
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

## Raw Windows NVMe VM Experiment

Raw disk access means the VM points at the physical Windows SSD. This is useful
for experimenting with work-app access, but it can corrupt data if Windows is
hibernated, Fast Startup is enabled, or Linux has the NTFS partition mounted.

Before any attempt:

- Back up important Windows data.
- Save the BitLocker recovery key if BitLocker is enabled.
- Disable Windows Fast Startup.
- Fully shut down Windows, do not hibernate it.
- Confirm Linux has not mounted any Windows partition.
- Use a stable `/dev/disk/by-id/...` path.

Audit stable paths:

```bash
ls -l /dev/disk/by-id/ | grep -i nvme
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
findmnt | grep -iE 'ntfs|Windows-SSD|nvme0n1' || true
```

Observed FORNAX Windows disk path:

```text
/dev/disk/by-id/nvme-WD_PC_SN8000S_SDEPNRK-1T00-1101_25100E4A5Y08
```

Do not run this until the safety checklist above is complete. Use the stowed
helper to create a UEFI Windows VM definition that points at the physical
Windows disk:

```bash
fornax-windows-raw-nvme-define
```

The helper refuses to continue if the stable Windows disk path is missing, if
any partition on that disk is mounted, or if the VM already exists. It requires
typing `DEFINE` before running `virt-install`.

Important Windows raw-disk caveats:

- Windows may not boot without VirtIO storage/network drivers.
- Windows activation may react to switching between native and VM hardware.
- Windows Update or vendor tools may install drivers that are bad for the other
  boot mode.
- Do not use this VM and native Windows concurrently.
- Do not mount the NTFS partitions in Linux while the VM exists or runs.

If Windows needs VirtIO drivers, attach the VirtIO ISO in `virt-manager` and
install drivers from inside Windows. Keep that as a manual step.

## GPU Passthrough Research

GPU passthrough is not the recommended first option on FORNAX. Native Windows
boot is better for gaming. If used, prefer a boot-time VFIO mode over live
detach/reattach.

Known GPU devices:

```text
02:00.0 NVIDIA RTX 5080 Mobile          vendor:device 10de:2c59
02:00.1 NVIDIA HD Audio Controller      vendor:device 10de:22e9
00:02.0 Intel integrated graphics       vendor:device 8086:7d67
```

The theoretical passthrough target is the NVIDIA device pair `02:00.0` and
`02:00.1`, while Linux remains on the Intel iGPU. This only works well if the
laptop firmware and display routing allow the NVIDIA GPU to be detached from the
host cleanly.

Current status helper:

```bash
fornax-gpu-passthrough-status
```

The raw Windows VM helper can define a GPU-attached variant only when both NVIDIA
devices are already bound to `vfio-pci`:

```bash
fornax-windows-raw-nvme-define --with-nvidia
```

If either device is still bound to Linux drivers such as `nvidia` or
`snd_hda_intel`, the helper refuses to define the passthrough VM. This is
intentional: bootloader/UKI changes should be tested manually and kept
recoverable.

Audit IOMMU support and device grouping:

```bash
lscpu | grep -i virtualization
sudo dmesg | grep -iE 'DMAR|IOMMU'
find /sys/kernel/iommu_groups/ -maxdepth 3 -type l | sort
lspci -nnk -s 02:00.0
lspci -nnk -s 02:00.1
lspci -nnk -s 00:02.0
```

If IOMMU is not enabled, the usual Intel kernel parameters are:

```text
intel_iommu=on iommu=pt
```

Do not make those the default from this repo. The active boot path is Limine with
a UKI, and `/boot/limine.conf` is auto-generated. Test any VFIO boot mode
manually and keep the normal Omarchy entry bootable.

Passthrough normally requires the NVIDIA GPU and its audio function to bind to
`vfio-pci` before the host NVIDIA driver claims them:

```text
vfio-pci.ids=10de:2c59,10de:22e9
```

Do not apply that blindly on FORNAX. Because the host currently uses the
`nvidia` driver, an incorrect VFIO bind can break the graphical session or leave
the laptop without expected display outputs.

Research checklist before attempting GPU passthrough:

- Confirm the Intel iGPU can drive the internal display and your normal desktop.
- Confirm the NVIDIA GPU and NVIDIA audio are isolated in a safe IOMMU group.
- Confirm external display ports are not required by the Linux host while the
  NVIDIA GPU is assigned to the guest.
- Prepare SSH access or another recovery path before changing kernel args.
- Expect anti-cheat limitations even with passthrough.
- Consider Looking Glass only after basic passthrough works.

## Recovery / Rollback

Disable libvirt if it is no longer needed:

```bash
sudo systemctl disable --now libvirtd.service
sudo gpasswd -d "$USER" libvirt
```

Remove packages only after checking whether anything else depends on them:

```bash
sudo pacman -Rns virt-manager libvirt qemu-full edk2-ovmf swtpm dnsmasq iptables virt-viewer virt-install guestfs-tools spice-vdagent dmidecode
```

Be careful with package removal if other packages depend on these packages or
if VM definitions/storage are still in use.
