# Topic 12: StatefulSets

| | |
|---|---|
| **Level** | Beginner/Intermediate |
| **Time** | ~50 min |
| **Prereqs** | [Deployments](../deployments/deployments.md), [Services](../services/services.md), [Storage - PV, PVC & StorageClass](../volumes/volumes.md) |
| **Files** | [`statefulset/headless-service.yaml`](headless-service.yaml) (headless svc `mongo`), [`statefulset/mongo-statefulset.yaml`](mongo-statefulset.yaml) (3 replicas + PVCs), [`volumes/sc.yaml`](../volumes/sc.yaml) (apply FIRST) |

> Run all commands from the repo root.

---

## 1. What is it?

A StatefulSet is a controller (like a Deployment) for apps that need:

- a **stable name** for each Pod (`mongo-0`, `mongo-1`, `mongo-2`)
- a **stable DNS name** for each Pod (`mongo-0.mongo...`)
- its **own disk** for each Pod (`mongo-data-mongo-0`, `mongo-data-mongo-1`, ...)
- an **order** for start, stop and update

Deployment Pods are like cattle: all the same, random names (`nginx-deployment-7c9f-abcde`). StatefulSet Pods are like pets: each one has an identity that stays the same after restart or reschedule.

### StatefulSet vs Deployment

| Feature | Deployment (stateless) | StatefulSet (stateful) |
|---|---|---|
| Pod identity | Random | Fixed (`pod-0`, `pod-1`, ...) |
| Stable storage (PVC) | Shared or ephemeral | One PVC per Pod |
| DNS | Dynamic (no name guarantee) | Predictable DNS per Pod |
| Use case | APIs, frontend apps | Databases, queues, ZooKeeper |
| Pod start/stop order | Any | Strict order |

---

## 2. Why do we need it?

Databases and clustered systems: MongoDB replica sets, PostgreSQL, MySQL, Kafka, RabbitMQ, ZooKeeper, Elasticsearch, Redis cluster, etcd.

Those apps need:

- "I am member 0, the others are member 1 and 2" (fixed identity).
- To find each other by a fixed address (Pod IPs change!).
- Each member keeps its own data. Member 1 must get ITS old disk back.

A Deployment with one shared PVC can not do this.

> **Note:** a StatefulSet does NOT set up replication for you. MongoDB still needs `rs.initiate()` etc. In production, people often use an Operator (for example the MongoDB Community Operator) or a Helm chart.

---

## 3. Key concepts

### a) Stable network ID

Pod names are `<statefulset-name>-<ordinal>`: `mongo-0`, `mongo-1`, `mongo-2`. The hostname inside the Pod is the same.

### b) Headless Service (`clusterIP: None`)

Required. It gives DNS records for EACH Pod instead of one virtual IP. The StatefulSet field `spec.serviceName` must point to it.

Per-Pod DNS name:

```text
<pod>.<service>.<namespace>.svc.cluster.local
mongo-0.mongo.default.svc.cluster.local
```

The Service name itself (`mongo.default.svc.cluster.local`) returns ALL ready Pod IPs (A records), not a single ClusterIP.

### c) volumeClaimTemplates

A PVC "template". The StatefulSet makes one PVC per Pod:

```text
<template-name>-<pod-name>  ->  mongo-data-mongo-0, ...-mongo-1, ...
```

If `mongo-1` is deleted, the new `mongo-1` gets the SAME PVC back.

### d) Ordered rollout (`podManagementPolicy: OrderedReady`, the default)

- **Scale up**: 0, then 1, then 2. Each waits for the previous one to be Running AND Ready.
- **Scale down**: highest first: 2, then 1, then 0.

`podManagementPolicy: Parallel` starts/stops all Pods at once (faster; use when members do not depend on order). This only affects scaling, not rolling updates.

### e) Update strategy

| Strategy | Behaviour |
|---|---|
| `RollingUpdate` (default) | Updates Pods one by one from the HIGHEST ordinal to the lowest (2, 1, 0) |
| `partition: N` | Only Pods with ordinal >= N are updated. Good for canary tests |
| `OnDelete` | Pods update only when YOU delete them |

### f) PVCs are NOT deleted on scale down (by default)

Scale 3 -> 1: Pods `mongo-2` and `mongo-1` go away, but their PVCs stay. Scale back to 3: they get their old data back.

Since v1.32 (GA) you can change this with `persistentVolumeClaimRetentionPolicy`:

| Field | Values | When |
|---|---|---|
| `whenDeleted` | `Retain` \| `Delete` | StatefulSet deleted |
| `whenScaled` | `Retain` \| `Delete` | Replicas reduced |

Default is Retain / Retain. Safe for data.

### g) Deleting a StatefulSet

Deleting a StatefulSet does not delete Pods in order. Scale it to 0 first if order matters.

---

## 4. Example YAML

### [`statefulset/headless-service.yaml`](headless-service.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongo                  # must equal spec.serviceName below
spec:
  clusterIP: None              # "headless": no virtual IP, per-Pod DNS
  selector:
    app: mongo                 # matches the StatefulSet Pod labels
  ports:
    - name: mongo
      port: 27017
      targetPort: 27017
```

### [`statefulset/mongo-statefulset.yaml`](mongo-statefulset.yaml) (with comments)

The repo uses `mongo:4.0.8`; `mongo:7.0` is a newer pinned choice.

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongo                  # Pods: mongo-0, mongo-1, mongo-2
spec:
  serviceName: "mongo"         # the headless Service for DNS
  replicas: 3
  # podManagementPolicy: OrderedReady   # default; or Parallel
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo             # must match selector
    spec:
      containers:
        - name: mongo
          image: mongo:4.0.8
          ports:
            - containerPort: 27017
          volumeMounts:
            - name: mongo-data       # = volumeClaimTemplates name
              mountPath: /data/db
  volumeClaimTemplates:        # one PVC per Pod
    - metadata:
        name: mongo-data       # PVC: mongo-data-mongo-0, ...
      spec:
        accessModes: ["ReadWriteOnce"]   # each Pod has its own disk
        storageClassName: demo-storage   # from volumes/sc.yaml
        resources:
          requests:
            storage: 1Gi
```

### Optional extra fields (inline example)

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0             # set to 2 to update only mongo-2
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Retain        # keep PVCs when the STS is deleted
    whenScaled: Retain         # keep PVCs when scaling down
```

---

## 5. Hands-on lab

### Step 1: Apply the StorageClass first (the PVC template needs it)

```bash
kubectl apply -f volumes/sc.yaml
kubectl get sc demo-storage
```

### Step 2: Create the headless Service and the StatefulSet

```bash
kubectl apply -f statefulset/headless-service.yaml
kubectl apply -f statefulset/mongo-statefulset.yaml
```

### Step 3: Watch the ordered start (open quickly)

```bash
kubectl get pods -l app=mongo -w
# -> mongo-0 Pending -> ContainerCreating -> Running
#    only THEN mongo-1 starts, then mongo-2. Press Ctrl+C.
```

### Step 4: See one PVC per Pod

```bash
kubectl get pvc
# -> mongo-data-mongo-0   Bound   1Gi   RWO   demo-storage
#    mongo-data-mongo-1   Bound   ...
#    mongo-data-mongo-2   Bound   ...
```

### Step 5: Check the headless Service

```bash
kubectl get svc mongo
# -> CLUSTER-IP is "None".
```

### Step 6: Test per-Pod DNS

```bash
kubectl run dns --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup mongo-0.mongo.default.svc.cluster.local
# -> one address = IP of mongo-0
kubectl run dns --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup mongo.default.svc.cluster.local
# -> three addresses (all Pods)
```

### Step 7: Stable identity after delete

```bash
kubectl exec mongo-1 -- hostname        # -> mongo-1
kubectl exec mongo-1 -- sh -c 'echo hello > /data/db/marker.txt'
kubectl get pod mongo-1 -o wide         # note the IP
kubectl delete pod mongo-1
kubectl get pods -w                     # mongo-1 comes back
kubectl exec mongo-1 -- cat /data/db/marker.txt
# -> hello        (same PVC, same name; the IP may be new)
```

### Step 8: Scale down and see PVCs stay

```bash
kubectl scale statefulset mongo --replicas=1
kubectl get pods -l app=mongo            # -> only mongo-0
kubectl get pvc                          # -> still 3 PVCs
kubectl scale statefulset mongo --replicas=3
kubectl exec mongo-1 -- cat /data/db/marker.txt   # -> hello
```

### Step 9: Rolling update in reverse order

```bash
kubectl set env statefulset/mongo DEMO_VERSION=v2
kubectl rollout status statefulset/mongo
# -> Pods are replaced: mongo-2, then mongo-1, then mongo-0.
```

We change an env var, not the image. Jumping mongo 4.0 -> 7.0 on old data files makes mongod refuse to start. Real Mongo upgrades must go one major version at a time.

### Step 10: Clean up (PVCs need a separate delete)

```bash
kubectl delete -f statefulset/mongo-statefulset.yaml
kubectl delete -f statefulset/headless-service.yaml
kubectl delete pvc -l app=mongo
kubectl get pvc     # -> empty. PVs are deleted (reclaimPolicy Delete).
```

---

## 6. Common mistakes & troubleshooting

- **`mongo-0` Pending, "storageclass demo-storage not found"**
  - Apply [`volumes/sc.yaml`](../volumes/sc.yaml) first. Or change `storageClassName` to `standard` (minikube default).
- **Only `mongo-0` is created, others never start**
  - With `OrderedReady`, `mongo-1` waits for `mongo-0` to be READY. Check `kubectl describe pod mongo-0` (failing readiness probe, crash).
- **DNS name `mongo-0.mongo...` does not resolve**
  - `spec.serviceName` does not match the Service name, or the Service is not headless, or the Service selector does not match Pod labels.
  - The Pod must be Ready to be in DNS (unless the Service sets `publishNotReadyAddresses: true`).
- **Changing volumeClaimTemplates fails**
  - Most fields there are immutable. Delete the StatefulSet with `--cascade=orphan`, then re-create it with the new template.
- **Old data after "fresh" re-install**
  - PVCs were kept from last time. Delete them if you want clean data.
- **Rolling update stuck**
  - A Pod with the new version never becomes Ready. Fix the image or config; the controller does not continue until it is Ready.

---

## 7. Cheat sheet

| Command | What it does |
|---|---|
| `kubectl get sts` | List StatefulSets |
| `kubectl describe sts mongo` | Events, status |
| `kubectl scale sts mongo --replicas=5` | Scale |
| `kubectl rollout status sts/mongo` | Watch an update |
| `kubectl rollout history sts/mongo` | Update history |
| `kubectl rollout undo sts/mongo` | Roll back |
| `kubectl rollout restart sts/mongo` | Restart Pods in order |
| `kubectl set image sts/mongo mongo=mongo:4.0.28` | Change image |
| `kubectl patch sts mongo -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":2}}}}'` | Canary: update only ordinals >= 2 |
| `kubectl delete sts mongo --cascade=orphan` | Delete STS, keep Pods |
| `kubectl get pvc -l app=mongo` | PVCs made by the template |

---

## 8. Practice tasks

1. Change `podManagementPolicy` to `Parallel` (you must delete and re-create the StatefulSet). Watch: do all Pods start together?
2. Set `partition: 2` and change the image. Which Pods get the new image?
3. Scale to 5 replicas. Write down the new Pod and PVC names before you look. Were you right?
4. Write a small StatefulSet `web` with `nginx:1.27`, 2 replicas, a headless Service `web`, and a 100Mi PVC per Pod mounted at `/usr/share/nginx/html`. Write a different `index.html` into each Pod and curl `web-0.web` and `web-1.web` from a busybox Pod.
5. (Advanced) Add `persistentVolumeClaimRetentionPolicy` `whenScaled: Delete`. Scale down and check the PVCs.

---

## 9. Quiz

1. What is the DNS name of Pod `mongo-2` of Service `mongo` in namespace `db`?
2. With the default policy, in which order are Pods created? Deleted on scale down?
3. What does `clusterIP: None` mean?
4. You scale from 3 to 1. What happens to the PVCs of `mongo-1` and `mongo-2` by default?
5. Name a case where `podManagementPolicy: Parallel` is a good choice.

<details><summary>Quiz answers</summary>

1. `mongo-2.mongo.db.svc.cluster.local`
2. Created 0, 1, 2 (each waits for the previous to be Ready). Deleted in reverse: 2, 1, 0.
3. Headless Service: no virtual IP. DNS returns the Pod IPs directly and each Pod gets its own DNS record.
4. They are kept (Retain). If you scale up again, the Pods get the same PVCs and data back.
5. When Pods do not depend on each other to start, for example a sharded cache where each member is independent; it makes scaling faster.

</details>

---

**Previous:** [Topic 11: Storage - Volumes, PV, PVC & StorageClass](../volumes/volumes.md) | **Next:** [Topic 13: DaemonSets, Jobs & CronJobs](../daemonsets_jobs_cronjobs/daemonsets_jobs_cronjobs.md) | [Back to README](../README.md)
