# FORNAX Windows Raw Disk Notes

Global Omarchy Windows VM creation, RDP, virt-manager, and libvirt setup are
documented in [`../omarchy-virtualization.md`](../omarchy-virtualization.md).

FORNAX has an existing Windows install on a separate internal NVMe disk. If that
install is used from a VM, choose raw disk mode manually in
`omarchy-windows-vm-create`. Raw disk mode is never automatic.

Before using the FORNAX Windows disk in a VM:

- Disable Windows Fast Startup.
- Do not hibernate Windows.
- Fully shut down Windows before booting the same install in a VM.
- Do not mount the Windows NTFS partition read/write in Linux while the VM uses the disk.
- Use a stable `/dev/disk/by-id/...` path, not `/dev/nvme0n1`.
- Back up important data.

Identify stable disk paths:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINT
sudo blkid
ls -l /dev/disk/by-id/ | grep -i nvme
```

Native Windows boot remains the preferred path for gaming. Detecting the
Windows install on the second NVMe and adding it to the Omarchy boot menu is
covered in [`../omarchy-dualboot-windows.md`](../omarchy-dualboot-windows.md)
(`omarchy-windows-boot-detect`). GPU passthrough, Looking Glass, and VFIO GPU
configuration are not part of the default dotfiles workflow.
