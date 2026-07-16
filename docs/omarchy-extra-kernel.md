# Adding an Extra Kernel to Omarchy (and the fornax bass fix)

Sometimes a laptop is newer than the Linux kernel. A piece of hardware — a
speaker amp, a wifi chip — has no driver in the stock Arch kernel yet, and no
setting or app can fix that, because drivers live *inside* the kernel. The fix
is to boot a kernel that already has the driver, then go back to stock once
the driver reaches the official kernel (they always do, eventually).

This guide covers the general recipe and the concrete case it was written for:
no bass on fornax (Lenovo Legion Pro 7 16IAX10H).

Safety model, in one line: the stock `linux` kernel is never removed, so a bad
extra kernel costs you one reboot + one arrow key at the boot menu, never the
system.

## The fornax case: speakers with no bass

Symptoms: sound is thin/tinny, only highs; volume, EQ, and sound settings
change nothing; firmware and Omarchy updates do not help.

Cause: the laptop has 2 tweeters (driven by the Realtek ALC287 codec — these
work) and 2 woofers driven by an Awinic AW88399 smart amp over I2C (ACPI id
`AWDZ8399`). The stock kernel has no glue driver connecting that amp to the
sound card, and the amp firmware (`aw88399_acf.bin`) is not in linux-firmware.
The woofers are simply never powered on.

Quick diagnosis on any suspect Lenovo:

```bash
# Amp present in ACPI? (this is the smoking gun)
ls /sys/bus/acpi/devices/ | grep -i AWDZ
# Codec subsystem id (quirk tables key on this):
cat /sys/class/sound/hwC1D0/subsystem_id
# Did the codec pick a real fixup, or a blank one?
journalctl -k -b | grep 'picked fixup'
```

Fix (one command, then reboot):

```bash
sudo fornax-audio-setup
```

It installs the firmware blob (checksum-verified), adds the CachyOS kernel
repo, installs `linux-cachyos` (a prebuilt kernel that ships the community
AW88399 driver), and makes it the default boot entry. Health check afterwards:

```bash
fornax-audio-check
```

Exit path — once the stock Arch kernel gains the AW88399 driver (the patch
series is being upstreamed; test by booting the stock `linux` entry after a
`dotfiles update` and running `fornax-audio-check`):

```bash
sudo fornax-audio-setup --revert
```

This fix is manual opt-in for fornax only. It is not in any package list and
never runs from bootstrap or `dotfiles update`. After a rebuild of fornax,
bootstrap normally, then run `sudo fornax-audio-setup` once.

Background and upstream status:
<https://github.com/nadimkobeissi/16iax10h-linux-sound-saga>

## The general recipe: any extra kernel on Omarchy

Omarchy is a desktop layer on top of Arch; it does not care which kernel
boots. Kernels are just pacman packages, and Omarchy's boot tooling
(mkinitcpio + Limine via `limine-entry-tool`) picks up any installed kernel
automatically. So adding a kernel is four steps:

1. **Add the repo that ships the kernel** (skip if it is in AUR or official
   repos). Trust its signing key, then append the repo at the *end* of
   `/etc/pacman.conf` so official repos keep priority for everything else:

   ```ini
   [cachyos]
   Include = /etc/pacman.d/cachyos-mirrorlist
   ```

2. **Install the kernel and its headers** (headers are what lets DKMS build
   the NVIDIA module for it):

   ```bash
   sudo pacman -Sy
   sudo pacman -S linux-cachyos linux-cachyos-headers
   ```

   Watch the post-install hooks: you should see DKMS build NVIDIA, a UKI
   built into `/boot/EFI/Linux/`, and `Updated: /boot/limine.conf`. That
   means the boot entry exists. Nothing else to wire up.

3. **Choose the default kernel** in `/etc/default/limine`. `BOOT_ORDER`
   controls the generated Limine default selection. Put the wanted kernel first,
   regenerate the boot config, then reboot:

   ```bash
   BOOT_ORDER="linux-cachyos, *, *fallback, Snapshots"
   sudo limine-update
   ```

   Do not judge this by the first visible kernel block in `/boot/limine.conf`;
   Limine may still list `//linux` before `//linux-cachyos`. Check the generated
   `default_entry` and the running kernel instead:

   ```bash
   grep '^default_entry:' /boot/limine.conf
   reboot
   uname -r
   ```

   If `uname -r` contains `cachyos`, the CachyOS kernel is the active default.

4. **Keep the stock kernel installed.** It stays in the boot menu as the
   fallback. If the extra kernel ever fails to boot, select `linux` at the
   menu and you are on a fully stock system again.

Removing an extra kernel is the same in reverse: restore `BOOT_ORDER`, remove
the kernel packages, remove the repo block from `/etc/pacman.conf`, remove its
keyring/mirrorlist packages, then `sudo limine-update` and reboot.

Things to know:

- Both kernels update automatically through `pacman -Syu` like any package.
- Third-party firmware blobs (like `aw88399_acf.bin`) are not owned by any
  package; pacman will never update or remove them. Track them in a script or
  doc (here: `fornax-audio-setup`).
- Snapshots keep working; limine-snapper entries are per-kernel.
- A repo added at the end of `pacman.conf` cannot override official packages;
  only packages that exist nowhere else (like the kernel) come from it.
