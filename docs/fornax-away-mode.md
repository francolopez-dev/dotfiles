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

What `dotfiles away on` does:

- Enables fornax OLED protection.
- Starts a user `systemd-inhibit` service that blocks sleep, idle sleep, and lid
  suspend.
- Locks the session.
- Turns the OLED display off with Hyprland DPMS.
- Reports Tailscale, Ollama, GPU, and tmux status.

Leave the laptop open and ventilated. The OLED can be off, but the machine still
needs airflow for GPU inference.

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
dotfiles away off
```

This stops the sleep inhibitor, restores normal OLED mode, restarts hypridle via
the OLED command, and turns displays back on when Hyprland is reachable.

## Power Loss

Away mode intentionally stays online if AC power is lost. Firmware and system
critical-battery handling may still shut the machine down to protect the battery.
