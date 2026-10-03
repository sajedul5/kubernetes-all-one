#!/usr/bin/env bash
# =============================================================================
# Install k6 (Grafana load testing tool) on Ubuntu / Debian
#
# Usage:
#   chmod +x scripts/install-k6-ubuntu.sh
#   ./scripts/install-k6-ubuntu.sh
# =============================================================================
set -euo pipefail

info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[ OK ]\033[0m $*"; }
fail() { echo -e "\033[1;31m[FAIL]\033[0m $*" >&2; exit 1; }

command -v apt-get >/dev/null || fail "This script is for Ubuntu/Debian (apt) only."

if command -v k6 >/dev/null; then
  ok "k6 already installed: $(k6 version)"
  exit 0
fi

info "Installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y gnupg ca-certificates curl

info "Adding the official k6 apt repository..."
sudo gpg -k >/dev/null 2>&1 || true
sudo gpg --no-default-keyring \
  --keyring /usr/share/keyrings/k6-archive-keyring.gpg \
  --keyserver hkp://keyserver.ubuntu.com:80 \
  --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" \
  | sudo tee /etc/apt/sources.list.d/k6.list >/dev/null

info "Installing k6..."
sudo apt-get update -y
sudo apt-get install -y k6

ok "k6 installed: $(k6 version)"
echo "  Try it: kubectl port-forward svc/nginx-service 8080:8080   (in another terminal)"
echo "          k6 run load_testing/k6-nginx-test.js"
