# LM Studio Integration Guide for opencode

This guide explains how to configure `opencode` to use a remote machine running [LM Studio](https://lmstudio.ai/) as its AI backend. This allows you to offload heavy model computations to a dedicated machine with a powerful GPU.

## Architecture Overview

```text
[Remote Machine (LM Studio)] <--- Local Network (HTTP) ---> [Local Machine (opencode)]
      - Running LM Studio Server                      - Reads environment variables
      - API Endpoint: http://<ip>:1234/v1            - Uses OpenAI-compatible protocol
```

---

## Phase 1: Configure LM Studio (The Provider)

1.  **Open LM Studio** on your dedicated machine.
2.  **Download a Model**: Search for a model (see "Recommended Models" below) and download it.
3.  **Start the Local Server**:
    *   Click the **`<->` (Local Server)** icon in the left sidebar.
    *   Select your downloaded model from the dropdown menu at the top.
    *   **Crucial**: Note the **Server Port** (default is `1234`).
    *   **Crucial**: Note the **Local IP Address** of this machine (e.g., `192.168.1.50`). You can find this by running `ip route` or `ifconfig` in the terminal.
    *   Ensure **"CORS"** is enabled if you encounter connection issues.
4.  **Verify Connectivity**:
    From your *local* machine's terminal, test if you can reach the server:
    ```bash
    curl http://<REMOTE_IP>:1234/v1/models
    ```
    *Replace `<REMOTE_IP>` with the actual IP of the LM Studio machine.*

---

## Phase 2: Configure Environment Variables (The Client)

To use the remote model, `opencode` needs to know where to send requests. We will use a `.env` file to keep your configuration clean and secure.

### 1. Create a Local `.env` File
Create a file named `.env` in your home directory (or a dedicated configuration directory like `~/.config/opencode/.env`). **Do NOT commit this file to Git.**

```bash
# Example ~/.env content
# ---------------------------------------------------------
# LM STUDIO CONFIGURATION
# ---------------------------------------------------------
export OPENAI_API_BASE="http://<REMOTE_IP>:1234/v1"
export OPENAI_API_KEY="lm-studio-is-awesome" # LM Studio doesn't require a real key, but opencode might expect one.
export AI_MODEL_NAME="name-of-your-model-in-lm-studio"
# ---------------------------------------------------------
```

### 2. Automate Loading (Shell Integration)

To make these variables available every time you open a terminal, add a snippet to your shell configuration file.

#### For Zsh (`~/.zshrc`) or Bash (`~/.bashrc`):
Add this to the end of your file:

```bash
# Load local environment variables if the file exists
if [ -f "$HOME/.env" ]; then
    source "$HOME/.env"
fi

# Alternative: If you put it in a specific config folder:
# [ -f "$HOME/.config/opencode/.env" ] && source "$HOME/.config/opencode/.env"
```

**Note:** After saving the file, run `source ~/.zshrc` (or `~/.bashrc`) to apply changes immediately.

---

## Phase 3: Recommended Models

When using LM Studio, your choice of model depends on whether you need coding expertise or general reasoning.

### 1. For Coding (The "Heavy Lifters")
Use these models for refactoring, debugging, and writing new logic.
*   **DeepSeek-Coder-V2**: Currently one of the best open-source coding models. Extremely capable at complex logic.
*   **Qwen2.5-Coder**: Excellent performance-to-size ratio. Great for smaller, faster machines.
*   **CodeLlama**: Meta's specialized coding model. Very stable and well-supported.

### 2. For General Use / Reasoning
Use these for documentation, high-level architecture discussions, or explaining code.
*   **Llama-3.1 (8B or 70B)**: The industry standard for general-purpose open-weights models.
*   **Mistral-Nemo**: Excellent reasoning and instruction following.

### 3. Where to find the latest models
*   **[Hugging Face](https://huggingface.co/models)**: The "GitHub of AI". Look for models with "GGUF" in the name for maximum compatibility with LM Studio.
*   **LM Studio Search**: Use the built-in search within the LM Studio app to find curated versions of popular models.

---

## Troubleshooting

*   **Connection Refused**: Double-check the IP address and ensure LM Studio's server is actually running and "Listening".
*   **Timeout Errors**: Ensure your local machine and the LM Studio machine are on the same subnet/Wi-Fi.
*   **Model Not Found**: In `opencode`, ensure the `AI_MODEL_NAME` exactly matches the identifier provided by the LM Studio `/v1/models` endpoint.
```bash
# Run this to see exact model name
curl http://<REMOTE_IP>:1234/v1/models
```
