#!/usr/bin/env bash

LLAMA_SERVER_BIN="llama-server"

# Model path and flags
MODEL_PATH="$HOME/models/Gemma 4/gemma-4-E4B-it-qat-UD-Q4_K_XL.gguf"
CTX_SIZE=65536
GPU_LAYERS=99
HOST="0.0.0.0"
PORT=6565
K_TYPE="q8_0"
V_TYPE="q8_0"

# Cleanup function that runs on exit or Ctrl+C
cleanup() {
  echo -e "\n\033[1;33m[!] Shutting down environment...\033[0m"

  # Stop Open WebUI container
  echo "Stopping Open WebUI container..."
  docker stop open-webui >/dev/null 2>&1

  # Kill llama-server process if running
  if [ -n "$LLAMA_PID" ] && kill -0 "$LLAMA_PID" 2>/dev/null; then
    echo "Stopping llama-server (PID: $LLAMA_PID)..."
    kill "$LLAMA_PID"
    wait "$LLAMA_PID" 2>/dev/null
  fi

  echo -e "\033[1;32m[✓] Everything stopped cleanly.\033[0m"
  exit 0
}

# Trap Ctrl+C (SIGINT) and termination (SIGTERM)
trap cleanup SIGINT SIGTERM EXIT

# 1. Start Open WebUI Docker container
echo -e "\033[1;34m[*] Starting Open WebUI Docker container...\033[0m"
docker start open-webui >/dev/null

# 2. Launch llama-server in the background
echo -e "\033[1;34m[*] Starting llama-server on port ${PORT}...\033[0m"
"$LLAMA_SERVER_BIN" \
  -m "$MODEL_PATH" \
  -c "$CTX_SIZE" \
  -ngl "$GPU_LAYERS" \
  -ctk "$K_TYPE" \
  -ctv "$V_TYPE" \
  -fa on \
  --host "$HOST" \
  --port "$PORT" &

# Store llama-server's process ID
LLAMA_PID=$!

echo -e "\033[1;32m[✓] Stack is running!\033[0m"
echo -e " -> Open WebUI: \033[4mhttp://localhost:3000\033[0m"
echo -e " -> llama-server: \033[4mhttp://127.0.0.1:${PORT}\033[0m"
echo -e "\033[1;30mPress Ctrl+C at any time to stop both services.\033[0m\n"

# Wait for llama-server process to keep script alive
wait "$LLAMA_PID"
