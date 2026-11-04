#!/usr/bin/env bash
# Update Fluxo while preserving its current published port and protocol.
set -Eeuo pipefail
APP=fluxo
DIR="${FLUXO_DIR:-$HOME/fluxo}"
[ -f "$DIR/install.sh" ] || { echo "Fluxo installation folder not found: $DIR" >&2; exit 1; }
port="$(docker port "$APP" 80/tcp 2>/dev/null | head -n1 | sed 's/.*://' || true)"
https="$(docker port "$APP" 443/tcp 2>/dev/null | head -n1 | sed 's/.*://' || true)"
args=(--dir "$DIR" --update --yes)
if [ -n "$https" ]; then args+=(--https --https-port "$https"); elif [ -n "$port" ]; then args+=(--port "$port"); fi
bash "$DIR/install.sh" "${args[@]}"
