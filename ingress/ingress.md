# Kubernetes Ingress & NGINX Ingress Controller

This guide explains the **Ingress** concept in Kubernetes and how to set up the **NGINX Ingress Controller** for both **Minikube (local)** and **production environments** (e.g., AWS, GCP, Azure).

---

## What is Ingress?

- An **Ingress** is a Kubernetes object that manages **external access** to services in a cluster, typically over HTTP or HTTPS.
- It provides **routing rules** to map incoming traffic (based on host/path) to internal services.
- It’s like a smart reverse proxy for your cluster.

> An Ingress **does not work by itself** — it needs an **Ingress Controller**.

---

## What is an Ingress Controller?

An **Ingress Controller** is the actual component that implements the rules defined in the Ingress resource. It:

- Watches Ingress resources in the cluster
- Provisions a **load balancer or reverse proxy** (e.g., NGINX)
- Routes traffic to the appropriate services

Popular Ingress controllers:

- `ingress-nginx` (community-maintained, NGINX-based)
- `Traefik`
- `HAProxy`
- `Istio Gateway` (in service meshes)

---

## Difference: Ingress vs Ingress Controller

| Ingress (Resource)        | Ingress Controller (Component)        |
|---------------------------|----------------------------------------|
| Defines HTTP rules        | Implements the rules                   |
| Written in YAML           | Runs as a Pod in the cluster           |
| Passive (declarative)     | Active (routes live traffic)           |
| Needs a controller to work| NGINX, Traefik, HAProxy, etc.          |

---

## Setup: NGINX Ingress Controller on Minikube

### 1. Enable Addon (Easiest Way)

    minikube addons enable ingress
    minikube tunnel
    kubectl get pods -n ingress-nginx
    kubectl get svc -n ingress-nginx

## NGINX Ingress Controller in Production (Cloud)
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.2/deploy/static/provider/cloud/deploy.yaml


## Common Troubleshooting Commands

| Task                       | Minikube                         | Production Cloud              |
| -------------------------- | -------------------------------- | ----------------------------- |
| Install Ingress Controller | `minikube addons enable ingress` | Apply NGINX manifest          |
| External Access            | `minikube tunnel` + `/etc/hosts` | LoadBalancer IP auto-assigned |
| Service Type               | ClusterIP (backend)              | ClusterIP + Ingress           |
| DNS/Host-based Routing     | Supported                        | Supported                     |
