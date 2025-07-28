# Quick Docker, Minikube & Kubernetes Setup - Ubuntu 24.04

## Prerequisites

    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release


## Install Docker

# Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc

# Add Docker repository
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    newgrp docker

# Verify
    docker --version
    docker run hello-world


## Install kubectl

# Download and install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify
    kubectl version --client


## Install Minikube

# Download and install
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64

# Start cluster
    minikube start --driver=docker
    minikube config set driver docker

# Verify
    minikube status
    kubectl get nodes


## Enable Addons

    minikube addons enable dashboard
    minikube addons enable metrics-server
    minikube addons enable ingress


# Deploy test app
    kubectl create deployment nginx --image=nginx
    kubectl expose deployment nginx --port=80 --type=NodePort
    kubectl get services

# Access app
    minikube service nginx --url

# Access dashboard
    minikube dashboard



# Minikube
    minikube start/stop/delete
    minikube ip
    minikube ssh

# kubectl
    kubectl get pods/services/deployments
    kubectl logs <pod-name>
    kubectl exec -it <pod-name> -- /bin/bash


## Troubleshooting

# Restart everything
    minikube delete
    minikube start --driver=docker --force

# Check resources
    free -h
    df -h
