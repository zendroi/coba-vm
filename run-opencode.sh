#!/usr/bin/env bash
# Simple runner that ensures CLIProxyAPI config, starts bridge proxy if needed, and runs OpenCode.

set -euo pipefail

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
BRIDGE_PY="$WORKDIR/bridge_proxy.py"
BRIDGE_LOG="$HOME/bridge_proxy.log"
BRIDGE_PID_FILE="$HOME/.bridge_proxy.pid"
CLIPROXY_PID_FILE="$HOME/.cliproxyapi.pid"
CLIPROXY_BIN="$HOME/CLIProxyAPI/cliproxyapi"
CLIPROXY_CONFIG="$HOME/CLIProxyAPI/config.yaml"

ensure_config() {
  mkdir -p "$HOME/.cli-proxy-api"
  cat > "$HOME/.cli-proxy-api/config.yaml" <<'YAML'
providers:
  zumy:
    api_key: "" # kosongkan untuk akses localhost
    models:
      - alias: gpt-5.3-codex
        model: gpt-5.3-codex
      - alias: gpt-4o
        model: gpt-4o
YAML
  echo "Wrote $HOME/.cli-proxy-api/config.yaml"
}

is_port_open() {
  local host=$1 port=$2
  # try curl; fallback to /dev/tcp
  if command -v curl >/dev/null 2>&1; then
    curl -sS --connect-timeout 1 "http://$host:$port/" >/dev/null 2>&1 && return 0 || return 1
  else
    (echo >/dev/tcp/$host/$port) >/dev/null 2>&1 && return 0 || return 1
  fi
}

start_bridge() {
  if [ -f "$BRIDGE_PID_FILE" ]; then
    pid=$(cat "$BRIDGE_PID_FILE" 2>/dev/null || true)
    if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
      echo "Bridge proxy already running (pid $pid)"
      return
    fi
  fi
  echo "Starting bridge proxy... (logs: $BRIDGE_LOG)"
  nohup python3 "$BRIDGE_PY" --listen 8320 --target-host 127.0.0.1 --target-port 8317 >>"$BRIDGE_LOG" 2>&1 &
  echo $! > "$BRIDGE_PID_FILE"
  sleep 0.5
}

start_cliproxy_if_needed() {
  # If a process named cliproxyapi / CLIProxyAPI is running, keep it.
  if pgrep -f "cliproxyapi" >/dev/null 2>&1 || pgrep -f "CLIProxyAPI" >/dev/null 2>&1; then
    echo "CLIProxyAPI already running"
    return 0
  fi

  # Try to start from expected installation path
  if [ -x "$CLIPROXY_BIN" ]; then
    echo "Starting CLIProxyAPI from $CLIPROXY_BIN"
    nohup "$CLIPROXY_BIN" -config "$CLIPROXY_CONFIG" >>"$HOME/cliproxyapi.log" 2>&1 &
    echo $! > "$CLIPROXY_PID_FILE"
    # wait for port
    echo -n "Waiting for CLIProxyAPI to listen on 127.0.0.1:8317"
    for i in {1..20}; do
      if is_port_open 127.0.0.1 8317; then
        echo " - ready"
        return 0
      fi
      echo -n "."
      sleep 0.5
    done
    echo ""
    echo "CLIProxyAPI did not become reachable in time" >&2
    return 1
  else
    echo "CLIProxyAPI binary not found at $CLIPROXY_BIN; please start it manually." >&2
    return 2
  fi
}

echo "Ensuring CLIProxyAPI config..."
ensure_config

echo "Ensuring CLIProxyAPI is running..."
if is_port_open 127.0.0.1 8317; then
  echo "CLIProxyAPI reachable on 127.0.0.1:8317"
else
  start_cliproxy_if_needed || true
fi

echo "Checking bridge (127.0.0.1:8320)..."
if is_port_open 127.0.0.1 8320; then
  echo "Bridge already listening on 8320"
else
  start_bridge
fi

export LOCAL_ENDPOINT="http://127.0.0.1:8320"
echo "Set LOCAL_ENDPOINT=$LOCAL_ENDPOINT"

if [ -x "$HOME/.opencode/bin/opencode" ]; then
  echo "Running OpenCode with provided args..."
  exec env LOCAL_ENDPOINT="$LOCAL_ENDPOINT" "$HOME/.opencode/bin/opencode" "$@"
else
  echo "OpenCode not found at $HOME/.opencode/bin/opencode" >&2
  echo "If installed, run: $HOME/.opencode/bin/opencode [args]" >&2
  exit 2
fi
