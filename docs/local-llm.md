# Local LLM + OpenCode

OpenCode uses Ollama inference hosts over Tailscale. Git is the source of truth:
add hosts and models to the stowed OpenCode config, then run `dotfiles update`
on each machine.

Short answer: after the config is committed and pushed, every managed machine
gets the same OpenCode model catalog on its next `dotfiles update`. OpenCode
must be installed on that machine, `dotfiles apply` must successfully stow the
config, and any already-running OpenCode session must be restarted because
OpenCode reads config only at startup.

This repo intentionally does not keep a project-level `opencode.jsonc` at the
repo root. Project config merges with global config and can keep old providers
visible, so the managed fleet catalog lives only in the global stow layer unless
a specific project needs an override.

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

Check the current catalog from any managed machine:

```bash
dotfiles llm models
opencode models ollama-fornax
```

If `opencode models ollama-fornax` does not show the new model after a Git pull,
quit and restart OpenCode. If the command itself does not see the provider, run:

```bash
dotfiles apply
opencode models ollama-fornax
```

If old providers still appear inside one project, check for project-local config
and remove it unless that project intentionally owns overrides:

```bash
ls -la opencode.json opencode.jsonc .opencode/opencode.json 2>/dev/null
```

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

CLI-only one-shot use:

```bash
opencode run -m ollama-fornax/qwen2.5-coder:14b "Explain this repo's bootstrap flow"
```

CLI-only interactive use:

```bash
opencode --model ollama-fornax/qwen2.5-coder:14b
```

Inside the TUI, model selection is still `/models`. The selected model is stored
by OpenCode as the last-used model, so you do not need to pass `--model` every
time once selected.

## Change Or Add A Model

Use this when you want to test a new model or permanently add one to the fleet.

1. Find candidate model names from the Ollama library:

   ```bash
   # Browser/search reference, not a command requirement:
   # https://ollama.com/search?c=tools
   # Good search terms: qwen coder, deepseek coder, tools, function calling
   ```

2. Test-pull it manually on the target inference host:

   ```bash
   OLLAMA_HOST=http://100.98.153.75:11434 ollama pull <model>
   OLLAMA_HOST=http://100.98.153.75:11434 ollama list
   ```

3. Try a direct prompt before adding it to Git:

   ```bash
   OLLAMA_HOST=http://100.98.153.75:11434 ollama run <model> "Say ready in one sentence."
   ```

4. Add the model to the host provider in:

   ```text
   stow/global/opencode/.config/opencode/opencode.json
   ```

   Example:

   ```json
   "models": {
     "qwen2.5-coder:14b": {
       "name": "Qwen 2.5 Coder 14B - fornax",
       "tool_call": true,
       "limit": { "context": 65536, "output": 8192 }
     },
     "new-model:tag": {
       "name": "New Model - fornax",
       "tool_call": true,
       "limit": { "context": 65536, "output": 8192 }
     }
   }
   ```

5. Validate locally:

   ```bash
   jq empty stow/global/opencode/.config/opencode/opencode.json
   dotfiles llm models
   OPENCODE_CONFIG=stow/global/opencode/.config/opencode/opencode.json opencode models ollama-fornax
   ```

6. Commit and push. On every other machine:

   ```bash
   dotfiles update
   opencode models ollama-fornax
   ```

7. Pull declared models on the inference host:

   ```bash
   dotfiles llm sync
   dotfiles llm doctor
   ```

Remove a model by deleting it from the provider's `models` map and committing the
change. This removes it from OpenCode's model picker after `dotfiles update`; it
does not delete the local Ollama model files. Delete those manually on the host:

```bash
OLLAMA_HOST=http://100.98.153.75:11434 ollama rm <model>
```

## Download Models

Preferred managed path on an inference host:

```bash
dotfiles llm sync
```

Manual path for one model:

```bash
OLLAMA_HOST=http://100.98.153.75:11434 ollama pull qwen2.5-coder:14b
```

List installed models:

```bash
OLLAMA_HOST=http://100.98.153.75:11434 ollama list
```

List loaded models and GPU residency:

```bash
OLLAMA_HOST=http://100.98.153.75:11434 ollama ps
```

Unload a model:

```bash
OLLAMA_HOST=http://100.98.153.75:11434 ollama stop qwen2.5-coder:14b
```

## Select Models In OpenCode

Non-interactive command:

```bash
opencode run -m ollama-fornax/qwen2.5-coder:14b "Summarize the current repo."
```

Interactive command:

```bash
opencode --model ollama-fornax/qwen2.5-coder:14b
```

Inside OpenCode:

```text
/models
```

If you add a model while OpenCode is already open, quit and restart OpenCode.
Config is not hot-reloaded.

## Add Another Ollama Host

Use this for future GPU desktops, laptops, or always-on machines. Model placement
can differ by host capacity.

1. Install and apply dotfiles on the host:

   ```bash
   dotfiles update
   ```

2. Confirm Tailscale is connected and get the IP:

   ```bash
   tailscale status
   tailscale ip -4
   ```

3. Add a provider to `stow/global/opencode/.config/opencode/opencode.json`:

   ```json
   "ollama-hostname": {
     "npm": "@ai-sdk/openai-compatible",
     "name": "Ollama - hostname",
     "options": {
       "baseURL": "http://100.x.y.z:11434/v1",
       "timeout": false,
       "headerTimeout": 60000,
       "chunkTimeout": 120000
     },
     "models": {
       "model:tag": {
         "name": "Model - hostname",
         "tool_call": true,
         "limit": { "context": 65536, "output": 8192 }
       }
     }
   }
   ```

4. Commit and push the config.

5. On the new host:

   ```bash
   dotfiles update
   dotfiles llm setup-host
   dotfiles llm sync
   dotfiles llm doctor
   ```

6. On any client:

   ```bash
   dotfiles update
   opencode models ollama-hostname
   opencode --model ollama-hostname/model:tag
   ```

## Add A macOS M2 As An Ollama Endpoint

Use this when the Mac should serve smaller local models to the rest of the
tailnet. Apple Silicon unified memory is useful, but an M2 is usually a smaller
endpoint than fornax for coding agents. Prefer 7B-14B models first.

1. Install Ollama on the Mac:

   ```bash
   brew install ollama
   ```

2. Start the service once manually or with Homebrew services:

   ```bash
   brew services start ollama
   ```

3. Confirm Tailscale IP:

   ```bash
   tailscale status
   tailscale ip -4
   ```

4. Configure the Ollama app/service to listen on the Tailscale IP. For the GUI
   app/service on macOS, set launchd environment variables and restart Ollama:

   ```bash
   launchctl setenv OLLAMA_HOST "100.x.y.z:11434"
   launchctl setenv OLLAMA_CONTEXT_LENGTH "65536"
   launchctl setenv OLLAMA_NUM_PARALLEL "1"
   launchctl setenv OLLAMA_MAX_LOADED_MODELS "1"
   launchctl setenv OLLAMA_FLASH_ATTENTION "1"
   launchctl setenv OLLAMA_KEEP_ALIVE "15m"
   launchctl setenv OLLAMA_NO_CLOUD "1"
   brew services restart ollama
   ```

   If using the Ollama desktop app instead of `brew services`, quit and reopen
   the app after setting the variables.

5. Verify from the Mac:

   ```bash
   curl http://100.x.y.z:11434/api/version
   OLLAMA_HOST=http://100.x.y.z:11434 ollama list
   ```

6. Add the Mac as a provider in the global OpenCode config:

   ```json
   "ollama-lamac": {
     "npm": "@ai-sdk/openai-compatible",
     "name": "Ollama - lamac",
     "options": { "baseURL": "http://100.x.y.z:11434/v1" },
     "models": {
       "qwen2.5-coder:7b": {
         "name": "Qwen 2.5 Coder 7B - lamac",
         "tool_call": true,
         "limit": { "context": 65536, "output": 8192 }
       }
     }
   }
   ```

7. Pull the model on the Mac:

   ```bash
   OLLAMA_HOST=http://100.x.y.z:11434 ollama pull qwen2.5-coder:7b
   OLLAMA_HOST=http://100.x.y.z:11434 ollama ps
   ```

8. On another machine, after the config is committed and pulled:

   ```bash
   dotfiles update
   curl http://100.x.y.z:11434/api/version
   opencode models ollama-lamac
   opencode --model ollama-lamac/qwen2.5-coder:7b
   ```

If `curl` fails from another machine, check that Tailscale is connected on both
machines and that Ollama is listening on the Tailscale IP rather than only
`127.0.0.1`.

## Look Here When Something Breaks

OpenCode catalog:

```bash
opencode models
opencode models ollama-fornax
```

Ollama API reachability:

```bash
dotfiles llm status
curl http://100.98.153.75:11434/api/version
```

Installed models:

```bash
OLLAMA_HOST=http://100.98.153.75:11434 ollama list
```

Loaded model, context, and GPU split:

```bash
OLLAMA_HOST=http://100.98.153.75:11434 ollama ps
nvidia-smi          # NVIDIA hosts
```

Linux Ollama service:

```bash
systemctl status ollama.service --no-pager
systemctl cat ollama.service
journalctl -u ollama.service -n 80 --no-pager
```

macOS Ollama service:

```bash
brew services list | grep ollama
launchctl getenv OLLAMA_HOST
launchctl getenv OLLAMA_CONTEXT_LENGTH
```

Tailscale:

```bash
tailscale status
tailscale ip -4
tailscale ping <host-or-ip>
```

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
