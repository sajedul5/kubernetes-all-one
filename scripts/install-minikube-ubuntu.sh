#!/usr/bin/env bash
# =============================================================================
# Install Docker + kubectl + Minikube on Ubuntu (22.04 / 24.04, amd64 or arm64)
#
# Usage:
#   chmod +x scripts/install-minikube-ubuntu.sh
#   ./scripts/install-minikube-ubuntu.sh            # install + start cluster
#   ./scripts/install-minikube-ubuntu.sh --no-start # install only
#
# Run as a normal user (NOT root). The script uses sudo when needed.
# Minikube's docker driver refuses to run as root.
# =============================================================================
set -euo pipefail

START_CLUSTER=true
[[ "${1:-}" == "--no-start" ]] && START_CLUSTER=false

CPUS="${MINIKUBE_CPUS:-2}"
MEMORY="${MINIKUBE_MEMORY:-4096}"

info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[ OK ]\033[0m $*"; }
fail() { echo -e "\033[1;31m[FAIL]\033[0m $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && fail "Do not run as root. Run as a normal user with sudo access."
command -v apt-get >/dev/null || fail "This script is for Ubuntu/Debian (apt) only."

case "$(uname -m)" in
  x86_64)        ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) fail "Unsupported CPU architecture: $(uname -m)" ;;
esac
info "Detected architecture: $ARCH"

# --- 1. Prerequisites --------------------------------------------------------
info "Installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y curl ca-certificates gnupg conntrack

# --- 2. Docker ---------------------------------------------------------------
if command -v docker >/dev/null; then
  ok "Docker already installed: $(docker --version)"
else
  info "Installing Docker Engine..."
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable --now docker
  ok "Docker installed: $(docker --version)"
fi

if ! id -nG "$USER" | grep -qw docker; then
  info "Adding $USER to the docker group..."
  sudo usermod -aG docker "$USER"
fi

# --- 3. kubectl --------------------------------------------------------------
if command -v kubectl >/dev/null; then
  ok "kubectl already installed: $(kubectl version --client 2>/dev/null | head -1)"
else
  info "Installing kubectl..."
  KVER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${KVER}/bin/linux/${ARCH}/kubectl"
  sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm -f /tmp/kubectl
  ok "kubectl installed: ${KVER}"
fi

# --- 4. Minikube -------------------------------------------------------------
if command -v minikube >/dev/null; then
  ok "Minikube already installed: $(minikube version --short)"
else
  info "Installing Minikube..."
  curl -fsSLo /tmp/minikube "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${ARCH}"
  sudo install -m 0755 /tmp/minikube /usr/local/bin/minikube
  rm -f /tmp/minikube
  ok "Minikube installed: $(minikube version --short)"
fi

# --- 5. Start cluster --------------------------------------------------------
if $START_CLUSTER; then
  info "Starting Minikube (driver=docker, cpus=$CPUS, memory=${MEMORY}MB)..."
  # 'sg docker' runs the command with the new docker group without re-login
  sg docker -c "minikube start --driver=docker --cpus=$CPUS --memory=$MEMORY"
  minikube config set driver docker >/dev/null
  info "Enabling addons: ingress, metrics-server, dashboard..."
  sg docker -c "minikube addons enable ingress"
  sg docker -c "minikube addons enable metrics-server"
  sg docker -c "minikube addons enable dashboard"
  kubectl get nodes
fi

echo
ok "All done!"
echo "  NOTE: log out and log back in (or run 'newgrp docker') so docker works without sudo."
echo "  Next: kubectl get nodes   |   minikube dashboard"
echo "  Learn: roadmap/roadmap.md"
