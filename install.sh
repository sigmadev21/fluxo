#!/usr/bin/env bash
#
# Fluxo installer for Linux and macOS.
# Installs Docker (if missing), downloads Fluxo and runs it in a container.
#
#   curl -fsSL https://raw.githubusercontent.com/sigmadev21/fluxo/main/install.sh | bash
#   ./install.sh --help
#
set -Eeuo pipefail

REPO_URL="https://github.com/sigmadev21/fluxo"
TARBALL_URL="https://codeload.github.com/sigmadev21/fluxo/tar.gz/HEAD"
APP="fluxo"
IMAGE="fluxo:latest"
PORT=8080
HTTPS_PORT=8443
USE_HTTPS=0
ACTION="install"
ASSUME_YES=0
INSTALL_DIR="${FLUXO_DIR:-$HOME/fluxo}"
SRC_DIR=""
SUDO=""
DOCKER=()

if [ -t 1 ]; then
  B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; N=$'\033[0m'
else
  B=""; G=""; Y=""; R=""; C=""; N=""
fi
log()  { printf '%s==>%s %s\n' "$C" "$N" "$*"; }
ok()   { printf '%s✔%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s!%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s✖ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }
trap 'die "Something went wrong (line $LINENO). Check the output above."' ERR

usage() {
  cat <<USAGE
${B}Fluxo installer${N}

Usage: ./install.sh [options]

  -p, --port N        HTTP port on this machine (default: 8080)
      --https         Serve over HTTPS with a self-signed certificate
      --https-port N  HTTPS port (default: 8443)
  -d, --dir PATH      Where to download Fluxo (default: ~/fluxo)
  -y, --yes           Don't ask for confirmation (for scripts)
      --update        Download the latest version and rebuild
      --status        Show the container status
      --uninstall     Remove the container and the image
      --purge         Uninstall and also delete the downloaded folder
  -h, --help          Show this help

Examples:
  ./install.sh
  ./install.sh --port 3000
  ./install.sh --https
  ./install.sh --update
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--port)       PORT="${2:?Missing value for $1}"; shift 2 ;;
    --https)         USE_HTTPS=1; shift ;;
    --https-port)    HTTPS_PORT="${2:?Missing value for $1}"; shift 2 ;;
    -d|--dir)        INSTALL_DIR="${2:?Missing value for $1}"; shift 2 ;;
    -y|--yes)        ASSUME_YES=1; shift ;;
    --update)        ACTION="update"; shift ;;
    --status)        ACTION="status"; shift ;;
    --uninstall)     ACTION="uninstall"; shift ;;
    --purge)         ACTION="purge"; shift ;;
    -h|--help)       usage; exit 0 ;;
    *)               die "Unknown option: $1 (try --help)" ;;
  esac
done

for p in "$PORT" "$HTTPS_PORT"; do
  [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le 65535 ] || die "Invalid port: $p"
done

confirm() {
  [ "$ASSUME_YES" = 1 ] && return 0
  # When piped from curl, stdin is the script, so ask through the terminal.
  if ! { : </dev/tty; } 2>/dev/null; then return 0; fi
  local a; read -r -p "$1 [y/N] " a </dev/tty
  [[ "$a" =~ ^[Yy] ]]
}

need() { command -v "$1" >/dev/null 2>&1 || die "'$1' is required but was not found."; }

detect_sudo() {
  if [ "$(id -u)" -eq 0 ]; then SUDO=""
  elif command -v sudo >/dev/null 2>&1; then SUDO="sudo"
  else SUDO=""; fi
}

pick_docker() {
  if docker info >/dev/null 2>&1; then DOCKER=(docker); return 0; fi
  if [ -n "$SUDO" ] && $SUDO docker info >/dev/null 2>&1; then DOCKER=("$SUDO" docker); return 0; fi
  return 1
}

install_docker() {
  case "$(uname -s)" in
    Linux)
      grep -qi microsoft /proc/version 2>/dev/null &&
        warn "WSL detected. Docker Desktop for Windows with WSL integration is the recommended setup."
      if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO" ]; then
        die "Installing Docker needs root. Install 'sudo' or run this script as root."
      fi
      if [ -f /etc/arch-release ]; then
        log "Installing Docker with pacman..."
        $SUDO pacman -Sy --noconfirm docker
      elif [ -f /etc/alpine-release ]; then
        log "Installing Docker with apk..."
        $SUDO apk add --no-cache docker
        $SUDO rc-update add docker default || true
        $SUDO service docker start || true
      else
        need curl
        log "Installing Docker Engine with the official script (get.docker.com)..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        $SUDO sh /tmp/get-docker.sh
        rm -f /tmp/get-docker.sh
      fi
      if command -v systemctl >/dev/null 2>&1; then $SUDO systemctl enable --now docker || true; fi
      if [ "$(id -u)" -ne 0 ]; then
        $SUDO usermod -aG docker "$USER" || true
        warn "You were added to the 'docker' group. Log out and back in to use Docker without sudo."
      fi
      ;;
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        log "Installing Docker Desktop with Homebrew..."
        brew install --cask docker
        open -a Docker || true
      else
        die "Install Docker Desktop from https://www.docker.com/products/docker-desktop/ and run this script again."
      fi
      ;;
    *) die "Unsupported system: $(uname -s). Install Docker manually and run this script again." ;;
  esac
  ok "Docker installed."
}

wait_for_docker() {
  log "Waiting for the Docker daemon..."
  for _ in $(seq 1 60); do
    pick_docker && { ok "Docker is ready."; return 0; }
    sleep 2
  done
  die "The Docker daemon is not responding. Start Docker (Docker Desktop on macOS) and run this script again."
}

fetch_source() {
  if [ -f ./index.html ] && [ -f ./Dockerfile ] && grep -q "Fluxo" ./index.html; then
    SRC_DIR="$(pwd)"; log "Using the current folder: $SRC_DIR"; return
  fi
  SRC_DIR="$INSTALL_DIR"
  if [ -d "$SRC_DIR/.git" ] && command -v git >/dev/null 2>&1; then
    log "Updating $SRC_DIR..."
    git -C "$SRC_DIR" pull --ff-only
  elif command -v git >/dev/null 2>&1 && [ ! -e "$SRC_DIR" ]; then
    log "Cloning $REPO_URL into $SRC_DIR..."
    git clone --depth 1 "$REPO_URL" "$SRC_DIR"
  else
    need curl; need tar
    log "Downloading Fluxo into $SRC_DIR..."
    mkdir -p "$SRC_DIR"
    curl -fsSL "$TARBALL_URL" | tar -xz --strip-components=1 -C "$SRC_DIR"
  fi
  [ -f "$SRC_DIR/Dockerfile" ] || die "Dockerfile not found in $SRC_DIR."
}

port_busy() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

lan_ip() {
  local ip=""
  if command -v hostname >/dev/null 2>&1; then ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"; fi
  if [ -z "$ip" ] && command -v ipconfig >/dev/null 2>&1; then ip="$(ipconfig getifaddr en0 2>/dev/null || true)"; fi
  printf '%s' "$ip"
}

make_certs() {
  local dir="$SRC_DIR/certs" ip; ip="$(lan_ip)"
  mkdir -p "$dir"
  if [ -f "$dir/fluxo.crt" ] && [ -f "$dir/fluxo.key" ]; then ok "Reusing existing certificate."; return; fi
  log "Creating a self-signed certificate..."
  "${DOCKER[@]}" run --rm -v "$dir:/certs" alpine/openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
    -keyout /certs/fluxo.key -out /certs/fluxo.crt -subj "/CN=fluxo.local" \
    -addext "subjectAltName=DNS:localhost,DNS:fluxo.local,IP:127.0.0.1${ip:+,IP:$ip}"
  ok "Certificate created in $dir"
}

remove_container() { "${DOCKER[@]}" rm -f "$APP" >/dev/null 2>&1 || true; }

run_container() {
  remove_container
  local args=(run -d --name "$APP" --restart unless-stopped --security-opt no-new-privileges)
  if [ "$USE_HTTPS" = 1 ]; then
    port_busy "$HTTPS_PORT" && die "Port $HTTPS_PORT is already in use. Try: ./install.sh --https --https-port 9443"
    make_certs
    args+=(-p "$HTTPS_PORT:443"
           -v "$SRC_DIR/nginx-ssl.conf:/etc/nginx/conf.d/default.conf:ro"
           -v "$SRC_DIR/certs:/etc/nginx/certs:ro")
  else
    port_busy "$PORT" && die "Port $PORT is already in use. Try: ./install.sh --port 3000"
    args+=(-p "$PORT:80")
  fi
  "${DOCKER[@]}" "${args[@]}" "$IMAGE" >/dev/null
}

wait_healthy() {
  log "Starting Fluxo..."
  # Ask nginx directly instead of waiting for Docker's slower periodic health check.
  for _ in $(seq 1 30); do
    if "${DOCKER[@]}" exec "$APP" wget -qO- http://127.0.0.1/healthz >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  "${DOCKER[@]}" logs --tail 30 "$APP" || true
  die "Fluxo did not respond in time."
}

summary() {
  local ip scheme port; ip="$(lan_ip)"
  if [ "$USE_HTTPS" = 1 ]; then scheme=https; port=$HTTPS_PORT; else scheme=http; port=$PORT; fi
  printf '\n%s🎉 Fluxo is running!%s\n\n' "$B" "$N"
  printf '   On this computer:  %s%s://localhost:%s%s\n' "$B" "$scheme" "$port" "$N"
  if [ -n "$ip" ]; then
    printf '   On your network:   %s://%s:%s\n' "$scheme" "$ip" "$port"
    if [ "$scheme" = http ]; then
      warn "Sign-in needs a secure context. Over plain HTTP it only works on localhost."
      warn "For other devices, reinstall with: ./install.sh --https"
    else
      warn "The certificate is self-signed: accept the browser warning once per device."
    fi
  fi
  printf '\n   Update:     ./install.sh --update\n   Status:     ./install.sh --status\n   Uninstall:  ./install.sh --uninstall\n\n'
  printf '   Your data stays in your browser (Local Storage), not in the container.\n\n'
}

main() {
  detect_sudo
  case "$ACTION" in
    status)
      pick_docker || die "Docker is not installed or not running."
      "${DOCKER[@]}" ps -a --filter "name=^${APP}$" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
      exit 0 ;;
    uninstall|purge)
      pick_docker || die "Docker is not installed or not running."
      remove_container; "${DOCKER[@]}" rmi "$IMAGE" >/dev/null 2>&1 || true
      ok "Container and image removed."
      if [ "$ACTION" = purge ] && [ -d "$INSTALL_DIR" ]; then
        confirm "Delete $INSTALL_DIR?" && rm -rf "$INSTALL_DIR" && ok "Deleted $INSTALL_DIR"
      fi
      exit 0 ;;
  esac

  printf '%s💧 Fluxo installer%s\n\n' "$B" "$N"
  if ! command -v docker >/dev/null 2>&1; then
    confirm "Docker was not found. Install it now?" || die "Docker is required. Aborting."
    install_docker
  fi
  wait_for_docker
  fetch_source

  log "Building the image..."
  local out
  if ! out="$("${DOCKER[@]}" build -t "$IMAGE" "$SRC_DIR" 2>&1)"; then
    printf '%s\n' "$out" | tail -n 25 >&2
    die "The image build failed (see the last lines above)."
  fi
  ok "Image built."

  run_container
  wait_healthy
  summary
}

main
