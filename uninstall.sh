#!/usr/bin/env bash
# Remove the Fluxo container and image. Docker and browser data are kept.
set -Eeuo pipefail
PURGE=0
DIR="${FLUXO_DIR:-$HOME/fluxo}"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --purge) PURGE=1; shift ;;
    --dir) DIR="${2:?Missing directory}"; shift 2 ;;
    --yes|-y) shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
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
