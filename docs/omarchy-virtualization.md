# Omarchy Virtualization

Use this on Omarchy systems for normal libvirt/QEMU development VMs. Machine
specific raw-disk workflows, such as FORNAX booting an existing Windows NVMe,
belong in profile docs.

## What Is Managed

Shared Omarchy package declarations live in:

```text
packages/os-omarchy/pacman.txt
```

The shared toolkit is:

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

Shared Omarchy helpers live in:

```text
stow/os-omarchy/scripts/.local/bin/omarchy-debian-dev-vm
```

Profile-specific helpers live under the matching profile layer. FORNAX-specific
raw Windows disk helpers are documented in
[`profiles/fornax-windows-virtualization.md`](profiles/fornax-windows-virtualization.md).

## First-Time Host Setup

Install declared packages and stow helpers:

```bash
dotfiles update
```

Enable libvirt and add your user to the `libvirt` group:

```bash
sudo systemctl enable --now libvirtd.service
sudo usermod -aG libvirt "$USER"
```

Log out or reboot after changing group membership.

Enable the default NAT network:

```bash
sudo virsh -c qemu:///system net-start default
sudo virsh -c qemu:///system net-autostart default
```

If the default network does not exist, define it once:

```bash
tmp="$(mktemp)"
cat >"$tmp" <<'XML'
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
XML
sudo virsh -c qemu:///system net-define "$tmp"
rm -f "$tmp"
sudo virsh -c qemu:///system net-start default
sudo virsh -c qemu:///system net-autostart default
```

FORNAX has a profile helper that performs these steps:

```bash
fornax-libvirt-setup
```

## Health Checks

```bash
groups
virsh -c qemu:///system uri
virsh -c qemu:///system net-list --all
virt-host-validate
virt-manager -c qemu:///system
```

Expected basics:

- Your user is in the `libvirt` group.
- `qemu:///system` is reachable.
- The `default` network is active and autostarted.
- `virt-host-validate` passes QEMU hardware virtualization checks.

## Debian Development VM

Download a Debian netinst ISO into a local ISO directory:

```bash
mkdir -p "$HOME/VMs/iso"
```

Put the ISO there manually. Example filename:

```text
~/VMs/iso/debian-12.6.0-amd64-netinst.iso
```

Create a normal qcow2 VM, not a raw disk VM:

```bash
omarchy-debian-dev-vm --iso "$HOME/VMs/iso/debian-12.6.0-amd64-netinst.iso" --start-install
```

Defaults:

```text
name: debian-dev
memory: 8192 MiB
vcpus: 8
disk: 80 GiB qcow2
storage: ~/.local/share/libvirt/dev-vms/disks/debian-dev.qcow2
connection: qemu:///system
network: default NAT
firmware: UEFI
graphics: SPICE
video: virtio
```

Show current defaults:

```bash
omarchy-debian-dev-vm --print-defaults
```

Custom example:

```bash
omarchy-debian-dev-vm \
  --name debian-lab \
  --iso "$HOME/VMs/iso/debian-12.6.0-amd64-netinst.iso" \
  --memory 12288 \
  --vcpus 10 \
  --disk-size 120 \
  --start-install
```

Open the VM later:

```bash
virt-viewer -c qemu:///system debian-dev
virt-manager -c qemu:///system
```

Basic VM lifecycle:

```bash
virsh -c qemu:///system list --all
virsh -c qemu:///system start debian-dev
virsh -c qemu:///system shutdown debian-dev
virsh -c qemu:///system destroy debian-dev   # hard power off only if needed
```

Snapshot before risky changes:

```bash
virsh -c qemu:///system snapshot-create-as debian-dev before-risky-change
virsh -c qemu:///system snapshot-list debian-dev
```

## Recommended Debian Guest Setup

Inside the Debian VM:

```bash
sudo apt update
sudo apt install -y build-essential git curl ca-certificates openssh-server tmux ripgrep fd-find jq qemu-guest-agent spice-vdagent
sudo systemctl enable --now ssh qemu-guest-agent
ip addr
```

Then SSH from Omarchy:

```bash
ssh <vm-user>@<vm-ip>
```

## Removal

Destroy only disposable development VMs:

```bash
virsh -c qemu:///system shutdown debian-dev
virsh -c qemu:///system undefine debian-dev --remove-all-storage
```

Do not use `--remove-all-storage` on raw-disk VMs or any VM with important data.

## Recovery Notes

- Package declarations and helper scripts are in Git and recover with `dotfiles update`.
- System libvirt state is root-owned and must be recreated after reinstall.
- Normal development VMs use qcow2 files and are safe to back up as files while powered off.
- Raw physical disk VMs are advanced and machine-specific; keep those workflows in profile docs.
