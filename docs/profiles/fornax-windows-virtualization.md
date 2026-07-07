# FORNAX Windows + Virtualization Runbook

## Purpose

FORNAX is the Omarchy laptop with Linux on `nvme1n1` and an existing Windows
installation on `nvme0n1`.

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
CPU:       Intel Core Ultra 9 275HX, 24 cores, VT-x present
iGPU:      Intel Arrow Lake-S Graphics, PCI 00:02.0, driver i915
dGPU:      NVIDIA GeForce RTX 5080 Max-Q / Mobile, PCI 02:00.0, driver nvidia
dGPU audio: NVIDIA HD Audio, PCI 02:00.1, driver snd_hda_intel
Linux SSD: nvme1n1, LUKS + btrfs, mounted as Linux root/home
Windows SSD: nvme0n1, existing Windows install, NTFS label Windows-SSD
```

Stable Windows disk path observed on FORNAX:

```text
/dev/disk/by-id/nvme-WD_PC_SN8000S_SDEPNRK-1T00-1101_25100E4A5Y08
```

Re-check this path before using it. Do not rely on `/dev/nvme0n1` staying the
same across boots.

## Recommended Approach

Best default plan:

- Use native Windows boot for gaming.
- Use normal libvirt/QEMU VMs for Ubuntu Server and disposable coding systems.
- If Windows VM access is needed, first try a non-GPU-passthrough raw Windows
  disk VM for work apps only.
- Treat GPU passthrough as a separate research project.

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
- GPU passthrough is future research and not automatic.

## Profile Packages

Virtualization packages are declared in the profile layer, not global or OS
layers:

```text
packages/profile-fornax-omarchy/pacman.txt
packages/profile-nox-omarchy/pacman.txt
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
```

Notes:

- `dnsmasq` and `iptables` support libvirt default NAT networking.
- `edk2-ovmf` provides UEFI firmware for modern guests.
- `swtpm` supports Windows 11 style TPM-backed VM setups.
- `virt-install` gives a repeatable CLI path for Ubuntu Server VMs.
- `guestfs-tools` is useful for inspecting VM disk images; use carefully.
- `spice-vdagent` is mainly for Linux guests, not the Windows host.

## Identify Disks

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
findmnt
ls -l /dev/disk/by-id/
sudo blkid
```

Expected high-level layout on FORNAX:

```text
nvme1n1  Linux disk
nvme0n1  Windows disk
```

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

This repo does not currently manage profile-specific system services. Enable
libvirt manually if VM management is needed:

```bash
sudo systemctl enable --now libvirtd.service
sudo usermod -aG libvirt "$USER"
```

Logout or reboot after adding the user to the `libvirt` group. Until then,
`virt-manager` may not work without elevated privileges.

## Default Libvirt Network

```bash
sudo virsh net-list --all
sudo virsh net-start default
sudo virsh net-autostart default
```

Confirm networking after starting it:

```bash
virsh net-list --all
ip addr show virbr0
```

## Launch Tools

```bash
virt-manager
virsh list --all
```

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

Do not run this until the safety checklist above is complete. This example
creates a UEFI Windows VM definition that points at the physical Windows disk:

```bash
virt-install \
  --name windows-raw-nvme \
  --memory 16384 \
  --vcpus 12 \
  --cpu host-passthrough \
  --import \
  --disk path=/dev/disk/by-id/nvme-WD_PC_SN8000S_SDEPNRK-1T00-1101_25100E4A5Y08,bus=virtio,format=raw,cache=none,io=native \
  --os-variant win11 \
  --network network=default,model=virtio \
  --graphics spice \
  --video virtio \
  --boot uefi \
  --features smm=on \
  --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb
```

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
boot is better for gaming.

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

Do not add those from this repo yet. First audit the active bootloader and test
manually.

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
