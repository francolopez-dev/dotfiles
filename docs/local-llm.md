# Local LLM + OpenCode

OpenCode uses Ollama inference hosts over Tailscale. Git is the source of truth:
add hosts and models to the stowed OpenCode config, then run `dotfiles update`
on each machine.

## Architecture

```text
any managed machine
  opencode
    -> ollama-fornax  http://100.98.153.75:11434/v1
    -> ollama-<future-host>  http://<tailscale-ip>:11434/v1
```

There is no gateway or automatic failover. The model picker shows each host as a
separate provider, and you choose the machine you know is online.

## Where To Edit

Edit the fleet catalog here:

```text
stow/global/opencode/.config/opencode/opencode.json
```

Add a new Ollama host as a provider named `ollama-<hostname>`. The provider URL
must use the host's Tailscale IPv4 address and the OpenAI-compatible `/v1`
suffix.

## Host Setup

On a host that has an `ollama-<hostname>` provider entry:

```bash
dotfiles update
dotfiles llm setup-host
dotfiles llm sync
dotfiles llm doctor
```

`setup-host` writes a systemd override for `ollama.service` so the API binds to
the declared Tailscale IP, uses a 64k context window, and keeps only one large
model loaded at a time. `sync` pulls the models assigned to the current host.

## Client Use

On any managed machine:

```bash
dotfiles update
dotfiles llm status
opencode
```

In OpenCode, use `/models` and select `ollama-fornax/qwen2.5-coder:14b` or any
future `ollama-<host>/<model>` entry.

## Model Rules

- Prefer models that support tool calling.
- Use at least 64k context for OpenCode agentic coding work.
- On fornax's 16 GB RTX 5080 Laptop GPU, start with 7B-14B quantized coding
  models. Larger 32B models are only promoted after `ollama ps` proves they stay
  fully on GPU at the configured context.
- Verify `ollama ps` shows `100% GPU` and `CONTEXT 65536` before leaving long
  sessions running.

## Useful Commands

```bash
dotfiles llm models
dotfiles llm status
dotfiles llm sync
dotfiles llm doctor
ollama ps
opencode models ollama-fornax
```

LM Studio stays optional for manual model experiments. Ollama is the managed
path because it is service-oriented, CLI-friendly, and reproducible through Git.
