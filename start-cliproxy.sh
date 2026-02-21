#!/usr/bin/env bash

mkdir -p /home/codespace/.cli-proxy-api
if [ -f /home/codespace/.cliproxyapi.pid ]; then
  pid=$(cat /home/codespace/.cliproxyapi.pid || true)
  if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid" || true
    sleep 0.5
  fi
fi
nohup /home/codespace/CLIProxyAPI/cliproxyapi -config /home/codespace/CLIProxyAPI/config.yaml > /home/codespace/cliproxyapi.log 2>&1 &
echo $! > /home/codespace/.cliproxyapi.pid
# wait up to 10s
for i in $(seq 1 20); do
  if curl -sS --connect-timeout 1 http://127.0.0.1:8317/ >/dev/null 2>&1; then
    echo "ready"
    break
  fi
  sleep 0.5
done
printf "log head:\n"
head -n 80 /home/codespace/cliproxyapi.log || true
