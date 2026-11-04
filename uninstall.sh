#!/usr/bin/env bash
# Remove the Fluxo container and image. Docker and browser data are kept.
set -Eeuo pipefail
PURGE=0
DIR="${FLUXO_DIR:-$HOME/fluxo}"
for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
    --dir) shift; DIR="${1:?Missing directory}" ;;
    --yes|-y) ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done
docker rm -f fluxo >/dev/null 2>&1 || true
docker rmi fluxo:latest >/dev/null 2>&1 || true
echo "Fluxo container and image removed. Docker and browser data were not changed."
if [ "$PURGE" -eq 1 ]; then
  if [ -f "$DIR/index.html" ] && [ -f "$DIR/Dockerfile" ]; then
    rm -rf -- "$DIR"
    echo "Deleted $DIR"
  else
    echo "Skipped folder removal: $DIR does not look like a Fluxo installation."
  fi
fi
