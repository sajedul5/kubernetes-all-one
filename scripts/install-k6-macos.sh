#!/usr/bin/env bash
# =============================================================================
# Install k6 (Grafana load testing tool) on macOS using Homebrew
#
# Usage:
#   chmod +x scripts/install-k6-macos.sh
#   ./scripts/install-k6-macos.sh
# =============================================================================
set -euo pipefail

info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[ OK ]\033[0m $*"; }
fail() { echo -e "\033[1;31m[FAIL]\033[0m $*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "This script is for macOS only."

if command -v k6 >/dev/null; then
  ok "k6 already installed: $(k6 version)"
  exit 0
fi

if ! command -v brew >/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [[ -x /usr/local/bin/brew ]];    then eval "$(/usr/local/bin/brew shellenv)"; fi
fi

info "Installing k6..."
brew install k6

ok "k6 installed: $(k6 version)"
echo "  Try it: kubectl port-forward svc/nginx-service 8080:8080   (in another terminal)"
echo "          k6 run load_testing/k6-nginx-test.js"
