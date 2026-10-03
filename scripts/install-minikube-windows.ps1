# =============================================================================
# Install Docker Desktop + kubectl + Minikube on Windows 10/11 (PowerShell)
#
# Usage (open PowerShell as Administrator):
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\scripts\install-minikube-windows.ps1            # install + start cluster
#   .\scripts\install-minikube-windows.ps1 -NoStart   # install only
#
# Requires: winget (built into Windows 10 1809+ / Windows 11 "App Installer").
# Docker Desktop needs WSL2 enabled (the script enables it if missing).
# Using WSL Ubuntu instead? Run scripts/install-minikube-ubuntu.sh inside WSL.
# =============================================================================
param(
    [switch]$NoStart,
    [int]$Cpus = 2,
    [int]$Memory = 4096
)
$ErrorActionPreference = "Stop"

function Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path", "User")
}

function Install-WingetPackage($id, $cmd) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Ok "$cmd already installed"
        return
    }
    Info "Installing $id ..."
    winget install -e --id $id --accept-source-agreements --accept-package-agreements
    Refresh-Path
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Fail "Please run PowerShell as Administrator." }
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Fail "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
}

# --- 1. WSL2 (needed by Docker Desktop) --------------------------------------
wsl --status *> $null
if ($LASTEXITCODE -ne 0) {
    Info "Enabling WSL2 ..."
    wsl --install --no-distribution
    Write-Host "WSL2 was enabled. RESTART Windows, then run this script again." -ForegroundColor Yellow
    exit 0
}
Ok "WSL2 is available"

# --- 2. Docker Desktop, kubectl, Minikube ------------------------------------
Install-WingetPackage "Docker.DockerDesktop" "docker"
Install-WingetPackage "Kubernetes.kubectl"   "kubectl"
Install-WingetPackage "Kubernetes.minikube"  "minikube"

# --- 3. Make sure Docker is running ------------------------------------------
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Info "Starting Docker Desktop (first start can take ~1 minute) ..."
    $dd = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dd) { Start-Process $dd }
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 3
        docker info *> $null
        if ($LASTEXITCODE -eq 0) { break }
    }
    docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        Fail "Docker is not running. Open Docker Desktop, finish setup, then re-run this script."
    }
}
Ok "Docker is running"

# --- 4. Start cluster --------------------------------------------------------
if (-not $NoStart) {
    Info "Starting Minikube (driver=docker, cpus=$Cpus, memory=${Memory}MB) ..."
    minikube start --driver=docker --cpus=$Cpus --memory=$Memory
    minikube config set driver docker | Out-Null
    Info "Enabling addons: ingress, metrics-server, dashboard ..."
    minikube addons enable ingress
    minikube addons enable metrics-server
    minikube addons enable dashboard
    kubectl get nodes
}

Write-Host ""
Ok "All done!"
Write-Host "  NOTE: open a NEW terminal so PATH changes apply."
Write-Host "  For Ingress/LoadBalancer run 'minikube tunnel' in a separate admin terminal"
Write-Host "  and add '127.0.0.1 nginx.example.com' to C:\Windows\System32\drivers\etc\hosts"
Write-Host "  Learn: roadmap\roadmap.md"
