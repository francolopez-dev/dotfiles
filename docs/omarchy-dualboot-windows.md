# Omarchy Windows Dual Boot (Native)

Optional workflow for booting an existing native Windows install from the
Omarchy boot menu, typically when Windows lives on a second NVMe disk (the
FORNAX layout). The daily driver remains Linux plus Windows VMs
([`omarchy-virtualization.md`](omarchy-virtualization.md)); this only adds an
easy native boot option on machines where Windows is actually detected.

Nothing here runs automatically. `dotfiles update` and bootstrap never touch
boot entries. The helper is detect-only by default and every write requires
typed confirmation.

## Safety Model

- Detection only by default; `--apply` is a separate, confirmed step.
- Linux/Omarchy always stays the default boot entry.
- UEFI boot order is never changed. `efibootmgr -o` is never run.
- EFI partitions are only mounted read-only during detection.
- Windows NTFS partitions are never mounted and never written.
- The Windows EFI partition is never written; entries go into the Linux
  bootloader config only.
- The edited config is backed up first and the exact change is printed.
- Existing boot entries are never deleted or rewritten.
- No fstab, greetd, Plymouth, lockscreen, or boot logo changes.
- Machines without Windows: the helper prints
  `No Windows Boot Manager detected.` and exits without side effects.

## Check The Current Bootloader First

Omarchy 2.0+ installs use Limine. Installs from before 2.0 use systemd-boot.
Do not assume; check on the actual machine:

```bash
bootctl status || true
sudo ls /boot /boot/loader/entries 2>/dev/null
sudo find /boot -maxdepth 3 -name 'limine.conf' -o -name 'loader.conf'
```

- `limine.conf` present (commonly `/boot/limine.conf` or
  `/boot/EFI/limine/limine.conf`): Limine.
- `loader/loader.conf` present and `bootctl status` reports systemd-boot:
  systemd-boot.
- Neither: use the UEFI firmware boot menu fallback below.

## Detect Windows Boot Manager

Preferred: run the helper (installed on all Omarchy machines via
`stow/os-omarchy/scripts/.local/bin/omarchy-windows-boot-detect`, also in the
app menu as `Windows Boot Detection`):

```bash
omarchy-windows-boot-detect
```

It detects the bootloader, enumerates every EFI System Partition, temporarily
mounts unmounted ones read-only, looks for `EFI/Microsoft/Boot/bootmgfw.efi`,
and prints disk, partition, PARTUUID, EFI path, and the exact entry `--apply`
would write. Manual equivalent:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,UUID,MOUNTPOINTS
sudo blkid
efibootmgr -v || true
sudo find /boot -maxdepth 4 -type f | sort
# For an unmounted second ESP (example device):
sudo mount -o ro /dev/nvme1n1p1 /mnt
sudo find /mnt -ipath '*microsoft/boot/bootmgfw.efi'
sudo umount /mnt
```

## Add Windows With The Helper

```bash
omarchy-windows-boot-detect            # detect and report only
omarchy-windows-boot-detect --dry-run  # same, explicit no-write preview
omarchy-windows-boot-detect --apply    # confirmed write, with backup
```

In `--apply` mode the helper shows the exact file and entry, asks for a typed
`yes`, backs up the config first, appends the entry, and prints rollback
commands. If several Windows candidates exist it lists them and asks which one
to use; it never guesses silently. It refuses to write anything it cannot
verify will boot.

Files it can change, only after confirmation:

- Limine: appends one `/Windows` block to `limine.conf` and writes a
  `limine.conf.bak.<timestamp>` backup next to it.
- systemd-boot (same-ESP Windows only): creates
  `<esp>/loader/entries/windows.conf` and backs up the previous
  `loader/entries/` directory. It never edits `loader.conf`.

## Manual Method: Limine (Omarchy 2.0+)

Limine chainloads EFI binaries across disks, so this works when Windows is on
a second NVMe. Find the Windows ESP PARTUUID (the EFI System Partition on the
Windows disk, vfat, ~100–500 MB — not the NTFS partition):

```bash
sudo blkid   # note PARTUUID of the Windows disk's EFI partition
```

Back up and edit the Limine config (path varies; check both):

```bash
sudo cp -p /boot/limine.conf /boot/limine.conf.bak.$(date +%Y%m%d)
sudo nano /boot/limine.conf
```

Append at the end, keeping every existing entry untouched:

```text
/Windows
    protocol: efi_chainload
    path: guid(xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx):/EFI/Microsoft/Boot/bootmgfw.efi
```

Use the PARTUUID from `blkid`. `efi_chainload` is the canonical protocol name
(`efi` is an accepted alias). Do not change `default_entry` or `timeout`;
Limine defaults to the first entry, so Omarchy stays the default. If BitLocker
is enabled in Windows, have the recovery key ready — boot-path changes can
trigger BitLocker validation on the next Windows boot.

Omarchy manages Limine (including snapshot entries via limine-snapper-sync)
and a major update may regenerate `limine.conf`. Keep the backup and re-add
the block if the entry disappears after an update.

## Manual Method: systemd-boot (pre-2.0 Omarchy)

systemd-boot can only launch EFI binaries from its own ESP. That splits into
two cases:

Windows on the same ESP as systemd-boot: it is normally auto-detected and
already shown in the boot menu. If not, create the entry (no `loader.conf`
changes):

```bash
sudo cp -a /boot/loader/entries /boot/loader/entries.bak.$(date +%Y%m%d)
sudo tee /boot/loader/entries/windows.conf <<'EOF'
title   Windows Boot Manager
efi     /EFI/Microsoft/Boot/bootmgfw.efi
EOF
```

Windows on a different ESP/disk: a loader entry pointing at the other disk
will not work — do not write one. Working alternatives, safest first:

1. UEFI firmware boot menu (below). Zero changes, always works.
2. The existing `Windows Boot Manager` NVRAM entry: `efibootmgr -v` usually
   shows one that Windows setup created; it is selectable from the firmware
   boot menu already.
3. A manual NVRAM entry if none exists. Appends only; never reorders:

   ```bash
   sudo efibootmgr --create --disk /dev/nvme1n1 --part 1 \
     --label "Windows Boot Manager" \
     --loader '\EFI\Microsoft\Boot\bootmgfw.efi'
   ```

   Never run `efibootmgr -o` afterwards; new entries must not be promoted to
   first in the boot order.
4. Copying `EFI/Microsoft/` from the Windows ESP onto the Linux ESP makes the
   same-ESP method work, but the copy goes stale when Windows updates its boot
   files and it doubles boot-critical state. Not recommended; prefer options
   1–3, or Limine after an Omarchy 2.0 upgrade.

## UEFI Firmware Boot Menu Fallback

The zero-risk option on every machine: keep Omarchy first in the firmware
boot order and use the one-time boot menu when native Windows is needed. The
key is vendor-specific — commonly F12, F11, Esc, or F8 — shown briefly at
power-on or listed in the vendor manual. This needs no config changes at all
and is the recommended path whenever the bootloader situation is unclear.

## Keeping Linux The Default

- The helper and the manual steps never touch `default_entry` (Limine),
  `loader.conf` (systemd-boot), or UEFI boot order.
- After adding an entry, reboot once and confirm Omarchy still auto-boots.
- If Windows ever hijacks the boot order (Windows updates can do this), fix
  it from Linux with `efibootmgr -o` placing the Linux entry first, or from
  the firmware setup UI. That is the only situation where reordering is
  appropriate.

## Rollback

- Limine: `sudo cp /boot/limine.conf.bak.<timestamp> /boot/limine.conf`, or
  delete the `/Windows` block at the end of `limine.conf`.
- systemd-boot: `sudo rm /boot/loader/entries/windows.conf` (the backup
  directory `entries.bak.<timestamp>` keeps the prior state).
- Manual NVRAM entry: `sudo efibootmgr -b <BootXXXX number> -B` deletes only
  that entry. Verify the number with `efibootmgr -v` first.
- Worst case: the firmware boot menu still boots Omarchy directly, and the
  Omarchy ISO provides recovery.

## FORNAX: Windows On A Second NVMe

FORNAX has Omarchy on one NVMe and a full Windows install on a second NVMe
with its own EFI partition (VM raw-disk notes:
[`profiles/fornax-windows-virtualization.md`](profiles/fornax-windows-virtualization.md)).

Identify both ESPs — device names like `/dev/nvme0n1` can swap between boots
depending on enumeration order, so identify by content and address by
PARTUUID, never by device name:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,UUID,MOUNTPOINTS
sudo blkid
ls -l /dev/disk/by-id/ | grep -i nvme
```

- Linux ESP: the vfat partition mounted at `/boot` (or `/efi`).
- Windows ESP: the vfat partition on the other disk, next to the large NTFS
  partition, containing `EFI/Microsoft/`.

Then run `omarchy-windows-boot-detect` and, if the report looks right,
`--apply`. On Limine the resulting `guid(<PARTUUID>)` entry is stable across
device renames. Cross-boot hygiene (Fast Startup off, no hibernation, never
share the disk between native boot and a running VM) is covered in the FORNAX
VM notes linked above.

## Why This Never Runs Automatically

Bootloader edits are the one place where a bad automatic change can make a
machine unbootable. Windows presence also varies per machine, and Windows
updates occasionally rewrite boot state on their own. So this stays a manual,
per-machine decision: `dotfiles update` only ships the helper and this
runbook, and the helper defaults to detection with confirmed, backed-up,
append-only writes behind `--apply`.
