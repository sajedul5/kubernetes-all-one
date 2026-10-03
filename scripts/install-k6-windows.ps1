# =============================================================================
# Install k6 (Grafana load testing tool) on Windows 10/11 (PowerShell)
#
# Usage:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\scripts\install-k6-windows.ps1
#
# Uses winget; falls back to Chocolatey if winget is not available.
# =============================================================================
$ErrorActionPreference = "Stop"

function Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }

if (Get-Command k6 -ErrorAction SilentlyContinue) {
    Ok "k6 already installed: $(k6 version)"
    exit 0
}

if (Get-Command winget -ErrorAction SilentlyContinue) {
    Info "Installing k6 with winget ..."
    winget install -e --id GrafanaLabs.k6 --accept-source-agreements --accept-package-agreements
} elseif (Get-Command choco -ErrorAction SilentlyContinue) {
    Info "Installing k6 with Chocolatey ..."
    choco install k6 -y
} else {
    Fail "Neither winget nor choco found. Download the MSI from https://dl.k6.io/msi/k6-latest-amd64.msi"
}

$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [Environment]::GetEnvironmentVariable("Path", "User")

if (Get-Command k6 -ErrorAction SilentlyContinue) {
    Ok "k6 installed: $(k6 version)"
} else {
    Ok "k6 installed. Open a NEW terminal to use it."
}
Write-Host "  Try it: kubectl port-forward svc/nginx-service 8080:8080   (in another terminal)"
Write-Host "          k6 run load_testing\k6-nginx-test.js"
