# Omarchy Dockurr Windows VM

## Purpose

Omarchy's built-in Windows VM uses the `dockurr/windows` container and connects
over RDP. This workflow keeps the Windows installation and data in the existing
Dockurr storage volume while improving FreeRDP quality, text clarity, scrolling,
window animation smoothness, and perceived responsiveness.

This is separate from the libvirt workflow in
[`omarchy-virtualization.md`](omarchy-virtualization.md). Use this document only
for the Omarchy-provided Dockurr container under `~/.config/windows/`.

## Managed Files

The reusable Dockurr tuning lives in the Omarchy stow layer:

```text
stow/os-omarchy/windows-dockurr/.local/bin/omarchy-windows-dockurr-rdp
stow/os-omarchy/windows-dockurr/.local/bin/omarchy-windows-dockurr-tune
stow/os-omarchy/windows-dockurr/.local/share/applications/windows-vm.desktop
```

After `dotfiles apply`, these appear as:

```text
~/.local/bin/omarchy-windows-dockurr-rdp
~/.local/bin/omarchy-windows-dockurr-tune
~/.local/share/applications/windows-vm.desktop
```

The desktop entry intentionally uses the user-owned wrapper instead of editing
Omarchy source under `~/.local/share/omarchy/`.

## Local Files Not In Git

Do not commit the live Compose file:

```text
~/.config/windows/docker-compose.yml
```

It contains machine-local settings and may contain the Windows username/password.
The tuning helper edits it in place and creates a timestamped backup before any
change.

The persistent Windows data is also local and must not be committed:

```text
~/.windows
~/Windows
```

## First-Time Use On A New Omarchy Machine

Install or create the Omarchy Windows VM through Omarchy first. Confirm that the
compose file exists and that storage points at the existing Dockurr storage path:

```bash
docker compose -f ~/.config/windows/docker-compose.yml config
```

Then apply dotfiles and tune the local compose file:

```bash
dotfiles apply
omarchy-windows-dockurr-tune
docker compose -f ~/.config/windows/docker-compose.yml up -d --no-deps windows
```

`omarchy-windows-dockurr-tune` preserves existing environment variables,
credentials, volumes, ports, devices, capabilities, storage paths, and networking.
It only updates `CPU_CORES` and `RAM_SIZE` after validating the compose file and
checking that the storage mount is recognizable.

## Resource Policy

The tuning helper uses simple host-resource rules:

- CPU cores: about half of logical CPUs, minimum 4 when possible, while leaving
  cores for Linux.
- RAM: about one third of host RAM, normally in the 8G-16G range, while leaving
  at least 6G for Linux.

For example, a 24-thread, 30 GiB RAM host is tuned to:

```yaml
RAM_SIZE: "12G"
CPU_CORES: "12"
```

If the host is smaller, the helper chooses lower values rather than starving
Linux.

## RDP Wrapper

Launch Windows from the app menu entry named `Windows`, or run:

```bash
omarchy-windows-dockurr-rdp launch --keep-alive
```

The app menu entry uses `--keep-alive` by default. Closing the RDP client does
not stop the Docker Windows VM; shut down from inside the Windows Start menu
when you intentionally want to stop Windows.

For a one-off session where closing RDP should stop the VM, run:

```bash
omarchy-windows-dockurr-rdp launch
```

`Super+W` is protected for the Dockurr FreeRDP window (`xfreerdp` titled
`Windows VM - Omarchy`) by `omarchy-close-window`, so accidental close-window
keystrokes do not terminate the RDP client.

The wrapper starts the existing container if needed, then connects with
`xfreerdp3` using supported FreeRDP 3 options:

```text
+dynamic-resolution
/bpp:32
/network:auto
/gfx:AVC444:on,AVC420:on,progressive:on,small-cache:on,frame-ack:on
/cache:bitmap:on,glyph:on,offscreen:on,persist
+aero
+window-drag
+menu-anims
/sound
/microphone
/clipboard
```

It passes arguments through FreeRDP `/args-from:stdin` so the password is not
shown in the process list.

If glyph caching causes visual artifacts, edit the stowed wrapper and remove
`glyph:on` from the `/cache:` option, then run `dotfiles apply`.

## Validate FreeRDP Capabilities

Before adding or changing RDP flags, inspect the installed client:

```bash
xfreerdp3 /version
xfreerdp3 /help
xfreerdp3 /buildconfig
```

Use only options listed by the installed client. Do not add deprecated RemoteFX
flags or unsupported display options.

## Verify Runtime State

Check the compose project and container:

```bash
docker compose -f ~/.config/windows/docker-compose.yml config
docker compose -f ~/.config/windows/docker-compose.yml ps
docker inspect omarchy-windows
```

Check KVM and QEMU resource allocation:

```bash
docker exec omarchy-windows sh -c 'ls -l /dev/kvm; ps -ef | grep qemu-system-x86_64 | grep -v grep'
```

Look for:

```text
accel=kvm
-enable-kvm
-smp <CPU_CORES>
-m <RAM_SIZE>
```

Check RDP reachability:

```bash
nc -zv 127.0.0.1 3389
```

## Rollback

The tuning helper prints the backup path. Restore it, then recreate only the
Windows service from the same Compose file:

```bash
cp ~/.config/windows/docker-compose.yml.bak.TIMESTAMP ~/.config/windows/docker-compose.yml
docker compose -f ~/.config/windows/docker-compose.yml up -d --no-deps windows
```

To stop using the stowed launcher wrapper on one machine:

```bash
stow --dir=~/dotfiles/stow/os-omarchy --target=$HOME --delete windows-dockurr
```

Then reinstall or refresh Omarchy's original Windows launcher if needed.

## Safety Rules

- Do not run `docker compose down -v` for this VM unless intentionally deleting
  all Windows data.
- Do not change `VERSION`, storage volumes, credentials, or networking unless
  fixing a specific problem.
- Do not reinstall or recreate the VM for graphics tuning.
- Do not attempt VirGL, `virtio-gpu-gl`, QXL, GPU passthrough, or arbitrary QEMU
  display arguments for this Dockurr workflow.
- Do not install random GPU drivers inside Windows. The guest does not have a
  passed-through physical GPU.

## Windows-Side Visual Settings

Inside Windows, open **Adjust the appearance and performance of Windows**.

Recommended custom balance:

- Disable animations, fades, transparency, and unnecessary shadows.
- Keep `Smooth edges of screen fonts` enabled.
- Use custom visual effects instead of disabling everything globally.
- Confirm the RDP display resolution matches the Linux display.
- Avoid random GPU driver installers; this VM uses virtual display hardware.

These settings reduce perceived lag while preserving text clarity.
