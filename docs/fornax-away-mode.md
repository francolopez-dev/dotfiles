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
dotfiles away on
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
- Leave the OLED off through `dotfiles away on`, not by relying on manual screen
  toggles.
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
dotfiles away off
```

This stops the sleep inhibitor, restores normal OLED mode, restarts hypridle via
the OLED command, and turns displays back on when Hyprland is reachable.

## Power Loss

Away mode intentionally stays online if AC power is lost. Firmware and system
critical-battery handling may still shut the machine down to protect the battery.
