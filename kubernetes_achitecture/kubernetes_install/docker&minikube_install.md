# Docker, Minikube & Kubernetes Installation Guide - Ubuntu 24.04

## Prerequisites

### System Requirements
- **OS**: Ubuntu 24.04 LTS (Noble Numbat)
- **RAM**: Minimum 4GB (8GB+ recommended for Kubernetes)
- **CPU**: 2+ cores (4+ cores recommended)
- **Storage**: 20GB+ free space
- **Network**: Internet connection for downloads

### Update System

# Update package list and upgrade system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release


## Step 1: Install Docker

### 1.1 Remove Old Docker Versions

# Remove old Docker versions if any
sudo apt remove -y docker docker-engine docker.io containerd runc


### 1.2 Add Docker Repository

# Create keyrings directory
sudo mkdir -p /etc/apt/keyrings

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null


### 1.3 Install Docker Engine

# Update package index
sudo apt update

# Install Docker Engine, CLI, and containerd
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group
sudo usermod -aG docker $USER

# Apply group changes (logout/login or use newgrp)
newgrp docker


### 1.4 Verify Docker Installation

# Check Docker version
docker --version

# Test Docker with hello-world
docker run hello-world

# Check Docker service status
sudo systemctl status docker


## Step 2: Install kubectl (Kubernetes CLI)

### 2.1 Download and Install kubectl

# Download kubectl binary
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Validate the binary (optional)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# Install kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Alternative: Install via package manager
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubectl


### 2.2 Verify kubectl Installation

# Check kubectl version
kubectl version --client

# Enable kubectl autocompletion
echo 'source <(kubectl completion bash)' >>~/.bashrc
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -o default -F __start_kubectl k' >>~/.bashrc
source ~/.bashrc


## Step 3: Install Minikube

### 3.1 Download and Install Minikube

# Download Minikube binary
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# Install Minikube
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Clean up downloaded file
rm minikube-linux-amd64


### 3.2 Verify Minikube Installation

# Check Minikube version
minikube version

# Check available drivers
minikube config view


## Step 4: Start Minikube Cluster

### 4.1 Start Minikube with Docker Driver

# Start Minikube cluster with Docker driver
minikube start --driver=docker

# Set Docker as default driver for future starts
minikube config set driver docker

# Verify cluster status
minikube status

# Get cluster info
kubectl cluster-info


### 4.2 Alternative Startup Options

# Start with specific resources
minikube start --driver=docker --memory=4096 --cpus=2

# Start with specific Kubernetes version
minikube start --driver=docker --kubernetes-version=v1.31.0

# Start with multiple nodes
minikube start --driver=docker --nodes=3


## Step 5: Verify Kubernetes Installation

### 5.1 Basic Cluster Verification

# Check cluster nodes
kubectl get nodes

# Check system pods
kubectl get pods -A

# Check cluster components
kubectl get componentstatuses

# Get cluster information
kubectl cluster-info dump --output-directory=/tmp/cluster-info


### 5.2 Deploy Test Application

# Create a test deployment
kubectl create deployment nginx --image=nginx

# Expose the deployment
kubectl expose deployment nginx --port=80 --type=NodePort

# Get service details
kubectl get services

# Access the application
minikube service nginx --url


### 6 Enable Useful Addons

# List available addons
minikube addons list

# Enable dashboard
minikube addons enable dashboard

# Enable metrics server
minikube addons enable metrics-server

# Enable ingress
minikube addons enable ingress

# Access dashboard
minikube dashboard


## Step 7: Useful Commands and Operations

### 7.1 Minikube Management

# Stop Minikube
minikube stop

# Start Minikube
minikube start

# Delete cluster
minikube delete

# SSH into Minikube node
minikube ssh

# Get Minikube IP
minikube ip

# View logs
minikube logs


### 7.2 Kubectl Basic Commands

# Get resources
kubectl get pods
kubectl get services
kubectl get deployments
kubectl get nodes

# Describe resources
kubectl describe pod <pod-name>
kubectl describe service <service-name>

# View logs
kubectl logs <pod-name>
kubectl logs -f <pod-name>  # Follow logs

# Execute commands in pods
kubectl exec -it <pod-name> -- /bin/bash

# Port forwarding
kubectl port-forward pod/<pod-name> 8080:80



#### Minikube Start Issues

# Clean up and restart
minikube delete
minikube start --driver=docker --force

# Check system resources
free -h
df -h


#### kubectl Context Issues

# Check current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context minikube


### 8 Log Locations

# Docker logs
sudo journalctl -u docker.service

# Minikube logs
minikube logs

# Kubectl logs
kubectl logs -n kube-system <pod-name>


## Useful Resources

- [Official Kubernetes Documentation](https://kubernetes.io/docs/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

**Note**: This guide is specifically for Ubuntu 24.04. Commands may vary slightly for other Ubuntu versions or Linux distributions.