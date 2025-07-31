# Kubernetes Deployment

This project uses the `nginx-deployments.yaml` file to demonstrate how **Deployments** work in Kubernetes. A Deployment ensures high availability, declarative updates, rollback capability, and scalability for your applications.

---

## What is a Kubernetes Deployment?

A **Deployment** is a higher-level controller in Kubernetes that:

- Manages the desired number of **Pods**
- Automatically creates a **ReplicaSet**
- Supports **rolling updates**, **rollbacks**, and **scaling**
- Is ideal for **stateless application management**

---

## File: `nginx-deployments.yaml`

This YAML file defines:

- A Deployment named `nginx-deployment`
- 3 replicas of an NGINX container
- Label selector `app: nginx`
- Uses the Docker image `nginx:latest`

> You can find this file in your working directory and apply it with `kubectl`.

---

## Deployment vs ReplicaSet vs Pod
| Feature             | Pod | ReplicaSet | Deployment |
| ------------------- | --- | ---------- | ---------- |
| Self-Healing        | ❌   | ✅          | ✅          |
| Rolling Updates     | ❌   | ❌          | ✅          |
| Rollback Support    | ❌   | ❌          | ✅          |
| Declarative Updates | ❌   | ❌          | ✅          |


## Apply the Deployment

    kubectl apply -f nginx-deployments.yaml
    kubectl get deployments
    kubectl get rs
    kubectl get pods -l app=nginx
    kubectl describe deployment nginx-deployment
    kubectl scale deployment/nginx-deployment --replicas=5
    kubectl get pods -l app=nginx


## Summary of Commands

| Task                           | Command                                                                   |
| ------------------------------ | ------------------------------------------------------------------------- |
| Apply deployment               | `kubectl apply -f nginx-deployments.yaml`                                 |
| Get deployments                | `kubectl get deployments`                                                 |
| Get pods                       | `kubectl get pods -l app=nginx`                                           |
| Describe deployment            | `kubectl describe deployment nginx-deployment`                            |
| Set new image (rolling update) | `kubectl set image deployment/nginx-deployment nginx=nginx:1.25 --record` |
| Rollout status                 | `kubectl rollout status deployment/nginx-deployment`                      |
| Rollout history                | `kubectl rollout history deployment/nginx-deployment`                     |
| Rollback to previous           | `kubectl rollout undo deployment/nginx-deployment`                        |
| Rollback to specific revision  | `kubectl rollout undo deployment/nginx-deployment --to-revision=2`        |
| Scale deployment               | `kubectl scale deployment/nginx-deployment --replicas=5`                  |
| Logs from pod                  | `kubectl logs <pod-name>`                                                 |
| Port forward                   | `kubectl port-forward pod/<pod-name> 8080:80`                             |
| Delete deployment              | `kubectl delete -f nginx-deployments.yaml`                                |
