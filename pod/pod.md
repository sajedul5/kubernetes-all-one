# Kubernetes Pod

A **Pod** is the smallest and simplest unit in the Kubernetes object model. It represents a **single running instance of a process** in your cluster.

---

## Key Concepts

| Concept         | Details                                                                 |
|-----------------|-------------------------------------------------------------------------|
| **Pod**         | A wrapper around one or more containers. Pods are scheduled and run on Nodes. |
| **Container(s)**| The actual app runs inside containers. Pods often contain a single container. |
| **Shared Storage** | If defined (e.g., volume), all containers in the pod can access it.     |
| **Shared Network** | All containers in a pod share the same IP address and port space.      |
| **Ephemeral**   | Pods are not permanent. They are recreated when they fail or are deleted (unless controlled by a Deployment, ReplicaSet, etc.) |

---

##  When to Use a Pod Directly?

Use a pod **only for learning or debugging purposes**. In real-world production:

- Use **Deployments** for managing updates and replicas
- Use **Services** to expose pods and load balance traffic
- Use **StatefulSets**, **DaemonSets**, etc., for more complex behavior

---

## ⚙️Pod Lifecycle (Simplified)

- **Pending**: Pod is accepted but not yet running (e.g., waiting for a node)
- **Running**: Pod is running on a node, containers are running
- **Succeeded / Failed**: Pod has completed or crashed
- **Unknown**: Node status can't be obtained

---

##  Useful Pod Commands

| Action             | Command                                         |
|--------------------|-------------------------------------------------|
| Create pod         | `kubectl apply -f nginx-pod.yaml`              |
| View pod           | `kubectl get pods`                             |
| View pod details   | `kubectl describe pod nginx-pod`               |
| View pod logs      | `kubectl logs nginx-pod`                       |
| Port forward       | `kubectl port-forward pod/nginx-pod 8080:80`   |
| Delete pod         | `kubectl delete -f nginx-pod.yaml`             |

---
