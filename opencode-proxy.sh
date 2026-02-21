#!/usr/bin/env bash
# Wrapper kecil untuk menjalankan OpenCode melalui CLIProxyAPI lokal
set -euo pipefail

export OPENAI_API_KEY=kodek
export OPENAI_BASE_URL=http://localhost:8317/v1

exec "$HOME/.opencode/bin/opencode" "$@"
