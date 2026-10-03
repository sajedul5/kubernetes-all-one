#!/usr/bin/env bash
# =============================================================================
# Install Docker Desktop + kubectl + Minikube on macOS (Intel or Apple Silicon)
#
# Usage:
#   chmod +x scripts/install-minikube-macos.sh
#   ./scripts/install-minikube-macos.sh            # install + start cluster
#   ./scripts/install-minikube-macos.sh --no-start # install only
#
# Uses Homebrew (installs it if missing).
# =============================================================================
set -euo pipefail

START_CLUSTER=true
[[ "${1:-}" == "--no-start" ]] && START_CLUSTER=false

CPUS="${MINIKUBE_CPUS:-2}"
MEMORY="${MINIKUBE_MEMORY:-4096}"

info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[ OK ]\033[0m $*"; }
fail() { echo -e "\033[1;31m[FAIL]\033[0m $*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "This script is for macOS only."
info "Detected architecture: $(uname -m)"

# --- 1. Homebrew -------------------------------------------------------------
if ! command -v brew >/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Make brew available in this shell (Apple Silicon vs Intel path)
  if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [[ -x /usr/local/bin/brew ]];    then eval "$(/usr/local/bin/brew shellenv)"; fi
fi
ok "Homebrew: $(brew --version | head -1)"

# --- 2. Docker Desktop -------------------------------------------------------
if command -v docker >/dev/null; then
  ok "Docker already installed: $(docker --version)"
else
  info "Installing Docker Desktop..."
  brew install --cask docker
fi

if ! docker info >/dev/null 2>&1; then
  info "Starting Docker Desktop (first start can take ~1 minute)..."
  open -a Docker
  for _ in $(seq 1 60); do
    docker info >/dev/null 2>&1 && break
    sleep 3
  done
  docker info >/dev/null 2>&1 || fail "Docker is not running. Open Docker Desktop, accept the terms, then re-run this script."
fi
ok "Docker is running"

# --- 3. kubectl + Minikube ---------------------------------------------------
info "Installing kubectl and minikube..."
brew install kubectl minikube
ok "kubectl:  $(kubectl version --client 2>/dev/null | head -1)"
ok "minikube: $(minikube version --short)"

# --- 4. Start cluster --------------------------------------------------------
if $START_CLUSTER; then
  info "Starting Minikube (driver=docker, cpus=$CPUS, memory=${MEMORY}MB)..."
  minikube start --driver=docker --cpus="$CPUS" --memory="$MEMORY"
  minikube config set driver docker >/dev/null
  info "Enabling addons: ingress, metrics-server, dashboard..."
  minikube addons enable ingress
  minikube addons enable metrics-server
  minikube addons enable dashboard
  kubectl get nodes
fi

echo
ok "All done!"
echo "  NOTE (macOS + docker driver): to reach Ingress/LoadBalancer run 'minikube tunnel'"
echo "        in a separate terminal and use 127.0.0.1 in /etc/hosts."
echo "  Next: kubectl get nodes   |   minikube dashboard"
echo "  Learn: roadmap/roadmap.md"
