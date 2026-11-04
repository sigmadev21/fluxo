#!/usr/bin/env bash
#
# Fluxo uninstaller for Linux and macOS.
# Removes the container and the image. Docker itself is left untouched.
#
#   ./uninstall.sh              remove container + image
#   ./uninstall.sh --purge      also delete the downloaded folder
#
set -Eeuo pipefail

APP="fluxo"
IMAGE="fluxo:latest"
DIR="${FLUXO_DIR:-}"
PURGE=0
KEEP_IMAGE=0
ASSUME_YES=0

if [ -t 1 ]; then G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; N=$'\033[0m'; else G=""; Y=""; R=""; C=""; N=""; fi
log()  { printf '%s==>%s %s\n' "$C" "$N" "$*"; }
ok()   { printf '%s✔%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s!%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s✖ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }
trap 'die "Uninstall failed (line $LINENO). Check the output above."' ERR

while [ $# -gt 0 ]; do
  case "$1" in
    --purge)       PURGE=1; shift ;;
    --keep-image)  KEEP_IMAGE=1; shift ;;
    -d|--dir)      DIR="${2:?Missing value for $1}"; shift 2 ;;
    -y|--yes)      ASSUME_YES=1; shift ;;
    -h|--help)
      cat <<USAGE
Usage: ./uninstall.sh [options]

  --purge        Also delete the downloaded Fluxo folder (default: ~/fluxo)
  --keep-image   Remove only the container
  -d, --dir PATH Folder to delete with --purge
  -y, --yes      Don't ask for confirmation
  -h, --help     Show this help
USAGE
      exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

confirm() {
  [ "$ASSUME_YES" = 1 ] && return 0
  if ! { : </dev/tty; } 2>/dev/null; then return 0; fi
  local a; read -r -p "$1 [y/N] " a </dev/tty
  [[ "$a" =~ ^[Yy] ]]
}

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -z "$DIR" ]; then
  if [ -f "$HERE/index.html" ] && [ -f "$HERE/Dockerfile" ]; then DIR="$HERE"; else DIR="$HOME/fluxo"; fi
fi

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then SUDO="sudo"; fi
command -v docker >/dev/null 2>&1 || die "Docker is not installed, so there is no Fluxo container to remove."
if docker info >/dev/null 2>&1; then D=(docker)
elif [ -n "$SUDO" ] && $SUDO docker info >/dev/null 2>&1; then D=("$SUDO" docker)
else die "The Docker daemon is not running (or you lack permission)."; fi

msg="Remove the Fluxo container and image?"
[ "$KEEP_IMAGE" = 1 ] && msg="Remove the Fluxo container?"
confirm "$msg" || { warn "Cancelled."; exit 0; }

if "${D[@]}" inspect "$APP" >/dev/null 2>&1; then
  "${D[@]}" rm -f "$APP" >/dev/null
  ok "Container removed."
else
  warn "No container named '$APP' was found."
fi

if [ "$KEEP_IMAGE" = 0 ]; then
  if "${D[@]}" image inspect "$IMAGE" >/dev/null 2>&1; then
    "${D[@]}" rmi "$IMAGE" >/dev/null
    ok "Image removed."
  fi
fi

if [ "$PURGE" = 1 ]; then
  if [ -d "$DIR" ]; then
    if [ -f "$DIR/index.html" ] && [ -f "$DIR/Dockerfile" ]; then
      confirm "Delete the folder $DIR (including certificates)?" && { rm -rf "$DIR"; ok "Deleted $DIR"; }
    else
      warn "$DIR doesn't look like a Fluxo folder. Skipping."
    fi
  else
    warn "Folder $DIR not found."
  fi
fi

printf '\n   Your accounts and transactions are stored in your browser (Local Storage) and were NOT deleted.\n'
printf '   To erase them too, clear this site'"'"'s data in your browser settings.\n'
