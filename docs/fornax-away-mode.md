# Fornax Away Mode

Use this before leaving fornax running unattended for a weekend or long remote
work session. It protects the OLED panel and keeps the machine reachable.

## Enable

```bash
dotfiles update
dotfiles apply
dotfiles llm setup-host
dotfiles llm sync
dotfiles away on
```

## Quick Screen Off

For day-to-day OLED protection while you are still nearby, use the direct screen
command instead of full away mode:

```bash
dotfiles screen off
```

This sends Hyprland DPMS off immediately. It does not change Omarchy's Stay
Awake toggle and it does not inhibit sleep. Any local keyboard, mouse, touchpad,
or lan-mouse input can wake the panel again.

If you are switching to another machine and want to prevent lan-mouse input from
waking the OLED, pause lan-mouse at the same time:

```bash
dotfiles screen off --pause-lanmouse
```

Bring the panel and lan-mouse back with:

```bash
dotfiles screen on --resume-lanmouse
```

Check the state with:

```bash
dotfiles screen status
```

Use Omarchy's menu-bar `Stay Awake` toggle when you want the machine to remain
awake according to Omarchy 4's shell/idle policy. Use `dotfiles screen off` when
you want the OLED panel dark now. Use `dotfiles away on` when leaving fornax
unattended for a long remote session.

Quick screen-off variations:

| Command | Behavior | When to use |
| --- | --- | --- |
| `dotfiles screen off` | Turns displays off now. | You are nearby and normal wake-on-input is fine. |
| `dotfiles screen off --lock` | Locks first, then turns displays off. | You are stepping away briefly. |
| `dotfiles screen off --pause-lanmouse` | Turns displays off and stops lan-mouse. | You are moving to another computer and do not want remote/edge input waking the OLED. |
| `dotfiles screen on` | Turns displays back on. | You are back at the laptop. |
| `dotfiles screen on --resume-lanmouse` | Turns displays on and starts lan-mouse. | You paused KVM sharing earlier. |
| `dotfiles screen status` | Shows DPMS, lan-mouse, and Stay Awake state. | Check what mode the machine is in. |

If this is the first time after adding a new model, run the LLM checks before
`dotfiles away on`:

```bash
dotfiles llm status
dotfiles llm sync
dotfiles llm doctor
```

What `dotfiles away on` does:

- Enables fornax OLED protection.
- Starts a user `systemd-inhibit` service that blocks sleep, idle sleep, and lid
  suspend.
- Locks the session.
- Turns the OLED display off with Hyprland DPMS.
- Reports Tailscale, Ollama, GPU, and tmux status.

`dotfiles away on` is stronger than `dotfiles screen off`: it also starts a
sleep/idle inhibitor and enables the repo's Fornax OLED protection mode.

Away mode variations:

| Command | Behavior | When to use |
| --- | --- | --- |
| `dotfiles away on` | Enables OLED protection, starts sleep/idle inhibitor, locks, turns display off, keeps lan-mouse as-is. | Long remote session where KVM sharing should remain available. |
| `dotfiles away on --pause-lanmouse` | Same as above, then stops lan-mouse. | Safest OLED mode when another machine or edge movement might wake the panel. |
| `dotfiles away off` | Stops sleep/idle inhibitor, disables OLED protection, turns display on, keeps lan-mouse as-is. | Return from away mode without changing KVM state. |
| `dotfiles away off --resume-lanmouse` | Same as above, then starts lan-mouse. | Return from `away on --pause-lanmouse`. |
| `dotfiles away status` | Shows away mode, OLED mode, Tailscale, Ollama, GPU, and tmux state. | Verify remote-readiness and thermal/model state. |

Leave the laptop open and ventilated. The OLED can be off, but the machine still
needs airflow for GPU inference.

## Weekend Checklist

Run this before walking away:

```bash
dotfiles update
dotfiles apply
dotfiles llm setup-host
dotfiles llm sync
dotfiles llm doctor
dotfiles away on --pause-lanmouse
```

Then verify from another machine before leaving:

```bash
ssh fornax true
curl http://100.98.153.75:11434/api/version
opencode models ollama-fornax
```

Check GPU residency after starting the model you plan to use:

```bash
opencode run -m ollama-fornax/qwen2.5-coder:14b "Say ready."
OLLAMA_HOST=http://100.98.153.75:11434 ollama ps
nvidia-smi
```

If `nvidia-smi` shows LM Studio or another `llama-server` using most VRAM, unload
that model in LM Studio before expecting Ollama to stay fully on GPU.

Recommended physical setup:

- Keep fornax plugged into AC power.
- Keep the lid open for airflow.
- Leave the OLED off through `dotfiles away on --pause-lanmouse` when you do not
  need KVM input, or `dotfiles away on` when lan-mouse should remain available.
- Keep Tailscale connected.
- Keep long-running work inside tmux.

## Reconnect

From another managed machine:

```bash
ssh fornax
tmux ls
ta <session>
```

Or work through an always-on server/session if your project lives there:

```bash
ssh domum-core
t
```

## Status

```bash
dotfiles away status
dotfiles llm doctor
ollama ps
```

## Disable

```bash
dotfiles away off --resume-lanmouse
```

This stops the sleep inhibitor, restores normal OLED mode, restarts hypridle via
the OLED command, and turns displays back on when Hyprland is reachable. On
Omarchy 4, the immediate display action is still Hyprland DPMS; Omarchy's
menu-bar Stay Awake toggle remains independent.

## Command Reference

| Command | Use |
| --- | --- |
| `dotfiles screen off` | Turn displays off now. |
| `dotfiles screen off --lock` | Lock, then turn displays off. |
| `dotfiles screen off --pause-lanmouse` | Turn displays off and stop lan-mouse to avoid remote input wakeups. |
| `dotfiles screen on` | Turn displays back on. |
| `dotfiles screen on --resume-lanmouse` | Turn displays on and restart lan-mouse. |
| `dotfiles screen status` | Show monitor DPMS state, lan-mouse state, and Omarchy Stay Awake state. |
| `dotfiles away on` | Long-session Fornax mode: OLED off, sleep inhibited, remote access checked. |
| `dotfiles away on --pause-lanmouse` | Long-session Fornax mode plus lan-mouse stopped to prevent remote wakeups. |
| `dotfiles away off` | Stop long-session away mode and turn displays on. |
| `dotfiles away off --resume-lanmouse` | Stop away mode, turn displays on, and restart lan-mouse. |

## Power Loss

Away mode intentionally stays online if AC power is lost. Firmware and system
critical-battery handling may still shut the machine down to protect the battery.
