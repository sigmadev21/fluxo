#!/usr/bin/env bash
#
# Fluxo updater for Linux and macOS.
# Downloads the latest version, rebuilds the image and restarts the container,
# keeping the same ports and HTTP/HTTPS mode you installed with.
#
#   ./update.sh
#   curl -fsSL https://raw.githubusercontent.com/sigmadev21/fluxo/main/update.sh | bash
#
set -Eeuo pipefail

APP="fluxo"
IMAGE="fluxo:latest"
INSTALLER_URL="https://raw.githubusercontent.com/sigmadev21/fluxo/main/install.sh"
DIR="${FLUXO_DIR:-}"

if [ -t 1 ]; then G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; N=$'\033[0m'; else G=""; Y=""; R=""; C=""; N=""; fi
log()  { printf '%s==>%s %s\n' "$C" "$N" "$*"; }
ok()   { printf '%s✔%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s!%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s✖ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }
trap 'die "Update failed (line $LINENO). Check the output above."' ERR

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--dir)  DIR="${2:?Missing value for $1}"; shift 2 ;;
    -h|--help) printf 'Usage: ./update.sh [--dir PATH]\n\nUpdates Fluxo to the latest version and keeps your ports and HTTPS mode.\n'; exit 0 ;;
    *)         die "Unknown option: $1" ;;
  esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -z "$DIR" ]; then
  if [ -f "$HERE/index.html" ] && [ -f "$HERE/Dockerfile" ]; then DIR="$HERE"; else DIR="$HOME/fluxo"; fi
fi

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then SUDO="sudo"; fi
command -v docker >/dev/null 2>&1 || die "Docker is not installed. Run install.sh first."
if docker info >/dev/null 2>&1; then D=(docker)
elif [ -n "$SUDO" ] && $SUDO docker info >/dev/null 2>&1; then D=("$SUDO" docker)
else die "The Docker daemon is not running (or you lack permission)."; fi

flags=()
if "${D[@]}" inspect "$APP" >/dev/null 2>&1; then
  http_port="$("${D[@]}" port "$APP" 80/tcp 2>/dev/null | head -n1 | sed 's/.*://' || true)"
  https_port="$("${D[@]}" port "$APP" 443/tcp 2>/dev/null | head -n1 | sed 's/.*://' || true)"
  if [ -n "$https_port" ]; then flags+=(--https --https-port "$https_port"); log "Keeping HTTPS on port $https_port"
  elif [ -n "$http_port" ]; then flags+=(--port "$http_port"); log "Keeping HTTP on port $http_port"; fi
else
  warn "No existing Fluxo container found. A fresh install with default settings will be done."
fi

installer="$DIR/install.sh"
[ -f "$installer" ] || installer="$HERE/install.sh"
if [ ! -f "$installer" ]; then
  command -v curl >/dev/null 2>&1 || die "curl is required to download the installer."
  installer="$(mktemp "${TMPDIR:-/tmp}/fluxo-install.XXXXXX")"; curl -fsSL "$INSTALLER_URL" -o "$installer"
fi

old_id="$("${D[@]}" image inspect -f '{{.Id}}' "$IMAGE" 2>/dev/null || true)"

log "Updating Fluxo in $DIR..."
# Run from a neutral folder so the installer fetches the latest source into $DIR.
( cd /tmp && bash "$installer" --update --yes --dir "$DIR" ${flags[@]+"${flags[@]}"} )

new_id="$("${D[@]}" image inspect -f '{{.Id}}' "$IMAGE" 2>/dev/null || true)"
if [ -n "$old_id" ] && [ "$old_id" = "$new_id" ]; then
  ok "You were already on the latest version."
else
  ok "Fluxo updated."
fi
printf '   Your accounts and transactions live in your browser, so nothing was lost.\n'
