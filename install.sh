#!/usr/bin/env bash
# Fluxo installer for Linux and macOS.
set -Eeuo pipefail
APP=fluxo
IMAGE=fluxo:latest
PORT=8080
HTTPS_PORT=8443
HTTPS=0
DIR="${FLUXO_DIR:-$HOME/fluxo}"
for arg in "$@"; do
  case "$arg" in
    --https) HTTPS=1 ;;
    --update|--yes) ;;
    --port) shift; PORT="${1:?Missing port}" ;;
    --https-port) shift; HTTPS_PORT="${1:?Missing HTTPS port}" ;;
    --dir) shift; DIR="${1:?Missing directory}" ;;
    --help|-h) echo "Usage: ./install.sh [--port PORT] [--https] [--https-port PORT] [--dir PATH]"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done
if ! command -v docker >/dev/null 2>&1; then
  if [ "$(uname -s)" = Linux ]; then
    echo "Installing Docker Engine..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo systemctl enable --now docker
  else
    echo "Install Docker Desktop first: https://www.docker.com/products/docker-desktop/" >&2
    exit 1
  fi
fi
docker info >/dev/null 2>&1 || { echo "Start Docker and try again." >&2; exit 1; }
if [ -f ./index.html ] && [ -f ./Dockerfile ]; then DIR="$PWD"; else
  mkdir -p "$DIR"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL https://codeload.github.com/sigmadev21/fluxo/tar.gz/HEAD | tar -xz --strip-components=1 -C "$tmp"
  cp -a "$tmp/." "$DIR/"
fi
docker build -t "$IMAGE" "$DIR"
docker rm -f "$APP" >/dev/null 2>&1 || true
args=(run -d --name "$APP" --restart unless-stopped --security-opt no-new-privileges)
if [ "$HTTPS" -eq 1 ]; then
  mkdir -p "$DIR/certs"
  if [ ! -f "$DIR/certs/fluxo.crt" ]; then
    docker run --rm -v "$DIR/certs:/certs" alpine/openssl req -x509 -nodes -newkey rsa:2048 -days 825 -keyout /certs/fluxo.key -out /certs/fluxo.crt -subj "/CN=fluxo.local" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
  fi
  args+=(-p "$HTTPS_PORT:443" -v "$DIR/nginx-ssl.conf:/etc/nginx/conf.d/default.conf:ro" -v "$DIR/certs:/etc/nginx/certs:ro")
  url="https://localhost:$HTTPS_PORT"
else
  args+=(-p "$PORT:80")
  url="http://localhost:$PORT"
fi
docker "${args[@]}" "$IMAGE" >/dev/null
echo "Fluxo is running at $url"
echo "Update: ./update.sh | Uninstall: ./uninstall.sh"
