# Kubernetes Namespaces

Namespaces in Kubernetes provide **logical isolation** for resources within a cluster. They help organize workloads, enforce security boundaries, and manage multi-tenant environments effectively.

---

## What is a Namespace?

A **Namespace** is a Kubernetes object that groups and isolates resources such as Pods, Services, ConfigMaps, and Deployments within the same cluster.

---

## Why Use Namespaces?

| Benefit                      | Description                                                      |
|------------------------------|------------------------------------------------------------------|
| Isolation                    | Separate environments (e.g., dev, staging, prod)                 |
| Organization                 | Group related resources (e.g., by team or app)                   |
| Access Control               | Apply RBAC rules per namespace                                   |
| Quotas & Limits              | Enforce resource usage per namespace                             |
| Multi-Tenancy                | Support for different users/apps sharing the same cluster        |

---

## When to Use Namespaces

 Use when you have:
- Multiple teams sharing a cluster
- Separate environments (dev/stg/prod)
- Names that may overlap between projects
- Resource quotas and isolation needs

 Avoid if:
- You have a small cluster with 1–2 apps
- No need for isolation or RBAC

---

## Default Namespaces

| Namespace         | Purpose                                                                 |
|------------------|-------------------------------------------------------------------------|
| `default`         | The default namespace for objects with no other namespace              |
| `kube-system`     | System components like kube-dns, kube-proxy, etc.                      |
| `kube-public`     | Readable by all users; used for public cluster info                    |
| `kube-node-lease` | Used for node heartbeats (since K8s v1.13+)                            |

---

| Action                          | Command                                                   |
| ------------------------------- | --------------------------------------------------------- |
| List all namespaces             | `kubectl get namespaces` or `kubectl get ns`              |
| Create a namespace              | `kubectl create namespace <name>`                         |
| Delete a namespace              | `kubectl delete namespace <name>`                         |
| View resources in a namespace   | `kubectl get pods -n <namespace>`                         |
| Set default namespace (kubectl) | `kubectl config set-context --current --namespace=<name>` |
| Apply resource to a namespace   | `kubectl apply -f <file> -n <namespace>`                  |
| Switch namespace (in context)   | `kubens <namespace>` (via `kubectx` plugin)               |


## Example Workflow
# Create
    kubectl create namespace dev

# Deploy to it
    kubectl apply -f nginx-deployment.yaml -n dev

# View running pods
    kubectl get pods -n dev

# Delete everything
    kubectl delete namespace dev
