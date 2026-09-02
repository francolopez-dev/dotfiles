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

The reusable Dockurr launcher lives in the Omarchy stow layer:

```text
stow/os-omarchy/windows-dockurr/.local/bin/omarchy-windows-dockurr-rdp
stow/os-omarchy/windows-dockurr/.local/share/applications/windows-vm.desktop
```

After `dotfiles apply`, these appear as:

```text
~/.local/bin/omarchy-windows-dockurr-rdp
~/.local/share/applications/windows-vm.desktop
```

The desktop entry intentionally uses the user-owned wrapper instead of editing
the packaged `/usr/bin/omarchy-windows-vm` command.

## Local Files Not In Git

Omarchy 4.0.2 and later protect the live Compose file at:

```text
/var/lib/omarchy/windows/docker-compose.yml
```

It is root-owned and must not be edited or copied into Git. RDP credentials remain
in the private per-user `~/.config/windows/credentials` file.

The persistent Windows data is also local and must not be committed:

```text
~/.windows
~/Windows
```

## First-Time Use On A New Omarchy Machine

Install or create the Omarchy Windows VM through Omarchy first:

```bash
omarchy-windows-vm install
```

Then apply dotfiles:

```bash
dotfiles apply
```

The wrapper starts the VM through Omarchy's protected privileged action. It does
not require membership in the root-equivalent `docker` group and does not modify
the root-owned Compose file. Before startup it explicitly clears inherited
setgid bits and normalizes `~/.windows` and `~/Windows` to mode `0700`, which
Omarchy's protected bind-mount helper requires when recreating its mount anchors
after a reboot.

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

`Super+W` and `Super+Q` are protected for the Dockurr FreeRDP window (`xfreerdp`
titled `Windows VM - Omarchy`) by `omarchy-close-window` and
`omarchy-quit-app`, so accidental close-window/quit-app keystrokes do not
terminate the RDP client.

The wrapper starts the existing container if needed, waits for an authenticated
RDP probe instead of a container log message, then connects with `xfreerdp3`
using supported FreeRDP 3 options:

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
/auth-pkg-list:!kerberos
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

Check the VM through Omarchy:

```bash
omarchy-windows-vm status
```

Check RDP reachability:

```bash
nc -zv 127.0.0.1 3389
```

## Rollback

To stop using the stowed launcher wrapper on one machine:

```bash
stow --dir=~/dotfiles/stow/os-omarchy --target=$HOME --delete windows-dockurr
```

The packaged launcher remains at `/usr/bin/omarchy-windows-vm`; run it directly
or reinstall the `omarchy` package if it is missing.

## Safety Rules

- Do not bypass `/usr/bin/omarchy-windows-vm` with direct Docker commands.
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
