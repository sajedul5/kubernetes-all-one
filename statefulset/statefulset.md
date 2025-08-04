# Kubernetes StatefulSet

## What is a StatefulSet?

A **StatefulSet** is a Kubernetes controller used to manage stateful applications. It ensures that:
- Each pod has a **stable hostname**
- Each pod gets a **dedicated volume** (PVC)
- Pods are created and terminated **in order**
- Pod identity is retained across rescheduling

---

## StatefulSet vs Deployment (Stateless)

| Feature                  | Deployment (Stateless)      | StatefulSet (Stateful)        |
|--------------------------|-----------------------------|-------------------------------|
| Pod identity             | Random                      | Fixed (`pod-0`, `pod-1`, etc.) |
| Stable storage (PVC)     | Shared or ephemeral         | One PVC per pod               |
| DNS                      | Dynamic (no name guarantee) | Predictable DNS per pod       |
| Use case                 | APIs, frontend apps         | Databases, queues, Zookeeper  |
| Pod restart order        | Any                         | Strict order                  |

---

## When to Use a StatefulSet

- Databases: MongoDB, MySQL, PostgreSQL
- Messaging systems: Kafka, RabbitMQ
- Applications that need:
  - Stable network identity
  - Persistent storage per pod
  - Ordered startup/shutdown


## Key Concepts

- **Headless Service**: Uses `clusterIP: None` to expose each pod via DNS like:

    mongo-0.mongo.default.svc.cluster.local

---

## File Structure

| File                        | Purpose                        |
|-----------------------------|---------------------------------|
| `mongo-statefulset-basic.yaml` | Mongo StatefulSet (3 replicas) |
| `mongo-headless-svc.yaml`     | Headless Service (required)    |

---
# ---

## File Structure

| File                        | Purpose                        |
|-----------------------------|---------------------------------|
| `mongo-statefulset-basic.yaml` | Mongo StatefulSet (3 replicas) |
| `mongo-headless-svc.yaml`     | Headless Service (required)    |

---

#  Commands

    kubectl apply -f mongo-headless-svc.yaml
    kubectl apply -f mongo-statefulset-basic.yaml
    kubectl get pods -l app=mongo
    kubectl get pvc
    kubectl get pv
    kubectl delete pod mongo-0
    # It will recreate with the same name and attach the same volume
    kubectl delete -f mongo-statefulset-basic.yaml
    kubectl delete -f mongo-headless-svc.yaml
