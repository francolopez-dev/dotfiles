# Omarchy Windows VM Workflow

## Purpose

Omarchy desktops install a shared libvirt/QEMU, virt-manager, SPICE, and RDP
toolkit. The default workflow is practical Windows VM usage without GPU
passthrough, Looking Glass, VFIO, bootloader changes, or automatic raw disk use.

Use this on FORNAX, NOX, and future Omarchy machines. It does not apply to
Debian/Ubuntu server profiles or macOS profiles.

## Installed Globally On Omarchy

Packages live in `packages/os-omarchy/pacman.txt`:

```text
qemu-desktop
libvirt
virt-manager
virt-viewer
virt-install
edk2-ovmf
swtpm
dnsmasq
spice-vdagent
spice-gtk
freerdp
remmina
osinfo-db
dmidecode
```

`qemu-desktop` is used because this workflow needs normal desktop VM support,
not the full QEMU package set. `virtio-win` is not declared because it is not
available from the configured pacman repositories; attach a trusted VirtIO ISO
manually when needed.

## First-Time Host Setup

After a fresh Omarchy install:

```bash
dotfiles update
omarchy-libvirt-setup
```

Log out or reboot afterward if the helper added your user to the `libvirt` group.

The helper is intentionally small and idempotent. It enables `libvirtd.service`,
adds your user to `libvirt`, starts the default NAT network, and enables network
autostart. If the default NAT network is missing, it defines the standard
libvirt NAT network.

Manual equivalent:

```bash
sudo systemctl enable --now libvirtd.service
sudo usermod -aG libvirt "$USER"
sudo virsh -c qemu:///system net-start default
sudo virsh -c qemu:///system net-autostart default
```

Check setup:

```bash
systemctl status libvirtd.service
groups
virsh -c qemu:///system net-list --all
virt-host-validate
```

## Create A Windows VM

Start the wizard:

```bash
omarchy-windows-vm-create
```

Or open `Create Windows VM` from the Omarchy app menu.

The wizard asks for VM name, Windows ISO path, RAM, vCPUs, storage mode, and an
optional VirtIO driver ISO. It creates the VM with UEFI, TPM 2.0, SPICE display,
QXL video, tablet input, default libvirt NAT, and VirtIO networking.

## Storage Choices

Local qcow2 image is the safe default. The wizard creates a qcow2 disk under:

```text
~/.local/share/libvirt/windows-vms/disks/
```

Raw disk mode is advanced and dangerous. It is available only when explicitly
chosen. The wizard shows `lsblk`, requires a stable `/dev/disk/by-id/...` path,
and requires typing this exact phrase:

```text
I understand this can destroy data
```

Raw disk safety rules:

- Disable Windows Fast Startup.
- Do not hibernate Windows.
- Fully shut down Windows before using the same install in a VM.
- Do not mount NTFS read/write in Linux while the VM uses the disk.
- Use stable `/dev/disk/by-id/...` paths, not `/dev/nvme0n1` or `/dev/sdX`.
- Back up important data before experimenting.

Inside Windows:

```powershell
powercfg /h off
shutdown /s /t 0
```

Windows Hello PIN may break when switching between native boot and a raw-disk VM
because TPM and hardware identity change. Password login is more reliable for
dual native/VM usage.

## VirtIO And SPICE Drivers

If Windows has no network during install, temporarily switch the NIC model to
`e1000e` in virt-manager or attach a VirtIO driver ISO and install `NetKVM`.
After VirtIO drivers are installed, switch back to VirtIO networking for better
performance.

Common VirtIO drivers:

- `NetKVM` for networking.
- `viostor` or `vioscsi` for storage if needed.
- balloon driver if desired.
- guest agent if desired.

The VirtIO ISO is not the same as SPICE guest tools. Install SPICE guest tools
inside Windows for better mouse integration, clipboard, dynamic resize, and
display behavior. Do not auto-download random Windows binaries from bootstrap.

## Recommended virt-manager Settings

Display:

- SPICE.
- Listen type: none/local.
- OpenGL off by default; test it manually only if stable.

Video:

- QXL first for stability.
- Try VirtIO video manually if QXL performs poorly.
- Try 3D acceleration only if it is supported and stable.

Input:

- Tablet input.
- Avoid USB passthrough of physical keyboard/mouse unless intentionally needed.
- Release keys: `Ctrl + Alt` and `Ctrl + Alt + G`.

Network:

- Default libvirt NAT network.
- VirtIO model after drivers are installed.
- Temporary `e1000e` fallback if Windows lacks VirtIO drivers.

Resolution:

- Start at `1920x1080`.
- Avoid large high-DPI or 4K console resolutions until performance is acceptable.

## Start Or Connect Without virt-manager

Default VM name is `windows`:

```bash
omarchy-windows-vm start
omarchy-windows-vm rdp
omarchy-windows-vm console
omarchy-windows-vm ip
```

Use another VM name:

```bash
omarchy-windows-vm start work-windows
omarchy-windows-vm rdp work-windows
```

Optional local config, not committed:

```bash
mkdir -p ~/.config/dotfiles
$EDITOR ~/.config/dotfiles/windows-vm.conf
```

Example:

```bash
WINDOWS_VM_NAME="windows"
WINDOWS_VM_RDP_USER=""
WINDOWS_VM_RDP_CLIENT="remmina"
```

## RDP And Remmina

RDP often feels better than the virt-manager console after Windows is installed.
Enable Remote Desktop inside Windows, then run:

```bash
omarchy-windows-vm rdp
```

FreeRDP command:

```bash
xfreerdp /u:USERNAME /v:VM_IP /dynamic-resolution /clipboard
```

Find the VM IP:

```bash
virsh -c qemu:///system net-dhcp-leases default
omarchy-windows-vm ip
```

Or from inside Windows:

```powershell
ipconfig
```

Do not store Windows passwords in Git.

## Manual virt-manager

Open `Virtual Machines` from the app menu or run:

```bash
virt-manager -c qemu:///system
```

Use virt-manager for manual changes such as temporary `e1000e` networking,
attaching a VirtIO ISO, display tweaks, or boot order changes.

## App Menu Entries

Global Omarchy launchers:

- `Virtual Machines`: opens virt-manager.
- `Windows VM`: starts/connects to the default Windows VM.
- `Create Windows VM`: opens the Windows VM wizard in a terminal.
- `Windows Boot Detection`: read-only native dual-boot detection report
  ([`omarchy-dualboot-windows.md`](omarchy-dualboot-windows.md)).

## Not Included

GPU passthrough, Looking Glass, and VFIO GPU configuration are intentionally not
part of this default workflow. Use native Windows boot for gaming; adding a
native Windows entry to the boot menu is covered in
[`omarchy-dualboot-windows.md`](omarchy-dualboot-windows.md).

This repo also does not auto-mount Windows NTFS partitions, edit fstab, modify
bootloader configuration, create Windows VMs automatically, or automatically
consume raw disks.

## Emergency: VM Captures Keyboard/Mouse

- Press `Ctrl + Alt`.
- Try `Ctrl + Alt + G`.
- Switch to TTY with `Ctrl + Alt + F3` if needed.
- Stop the VM from a terminal.

```bash
virsh -c qemu:///system list --all
virsh -c qemu:///system shutdown VM_NAME
virsh -c qemu:///system destroy VM_NAME
```

`destroy` force powers off the VM. It does not delete it.

## Removal

Stop libvirt if no longer needed:

```bash
sudo systemctl disable --now libvirtd.service
```

Remove packages only after checking dependencies and VM state:

```bash
sudo pacman -Rns qemu-desktop libvirt virt-manager virt-viewer virt-install edk2-ovmf swtpm dnsmasq spice-vdagent spice-gtk freerdp remmina osinfo-db dmidecode
```
