# Kubernetes Services – ClusterIP, NodePort, LoadBalancer

This guide explains the three primary types of **Kubernetes Services** using the `nginx-services.yaml` file. Services are used to expose Pods within or outside the Kubernetes cluster.

---

## What is a Kubernetes Service?

A **Service** in Kubernetes is an abstraction that defines a logical set of Pods and a policy to access them.

### Why use a Service?

- Pods are **ephemeral** – IPs change when recreated
- Services provide a **stable access point**
- Enable **load balancing** across Pods

---

## Common Service Types

| Type          | Accessible From | Use Case |
|---------------|------------------|----------|
| **ClusterIP** (default) | Internal only (inside cluster) | Microservice-to-microservice communication |
| **NodePort**           | Exposes on each Node's IP:Port | Access from outside the cluster (dev/test) |
| **LoadBalancer**       | External IP via cloud provider | Production-ready external access (AWS, GCP, etc.) |

---

## About `nginx-services.yaml`

This file defines different Service types for an NGINX Deployment:

- A `ClusterIP` Service to expose NGINX internally
- A `NodePort` Service for external access on a specific port
- A `LoadBalancer` Service (for cloud environments)

> Edit the file to switch between types or define multiple Service objects.

---

##  Apply the Service

    kubectl apply -f nginx-services.yaml

| Task                           | Command                                       |
| ------------------------------ | --------------------------------------------- |
| Apply Service                  | `kubectl apply -f nginx-services.yaml`        |
| View Services                  | `kubectl get svc`                             |
| Describe a Service             | `kubectl describe svc <service-name>`         |
| Delete Services                | `kubectl delete -f nginx-services.yaml`       |
| Port forward Pod (alternative) | `kubectl port-forward pod/<pod-name> 8080:80` |
