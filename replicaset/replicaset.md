# 📘 Kubernetes ReplicaSet 

This document explains the purpose and use of a **ReplicaSet** in Kubernetes using the `nginx-replicaset.yaml` file. It is intended for learning and hands-on practice.

---

## What is a ReplicaSet?

A **ReplicaSet** is a Kubernetes object that ensures a specified number of **identical Pods** are running at all times.

- If a Pod is deleted or crashes, the ReplicaSet creates a new one.
- It is defined by a **Pod template** and a **label selector**.
- ReplicaSets are usually managed by **Deployments** in production for rolling updates.

---

## About `nginx-replicaset.yaml`

This file defines a ReplicaSet that:

- Deploys **3 Pods** of the `nginx:latest` container
- Uses the label `app: nginx` to identify and manage Pods
- Ensures all Pods expose **port 80** inside the container

---

## How to Use

| Action                                | Command                                          |
| ------------------------------------- | ------------------------------------------------ |
| Create ReplicaSet                     | `kubectl apply -f nginx-replicaset.yaml`         |
| View ReplicaSet                       | `kubectl get rs`                                 |
| Describe ReplicaSet                   | `kubectl describe rs nginx-replicaset`           |
| View Pods by Label                    | `kubectl get pods -l app=nginx`                  |
| Delete ReplicaSet                     | `kubectl delete -f nginx-replicaset.yaml`        |
| Manually delete a Pod (auto-recreate) | `kubectl delete pod <pod-name>`                  |
| Scale ReplicaSet                      | `kubectl scale rs nginx-replicaset --replicas=5` |
