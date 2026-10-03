# Topic 11: Storage - Volumes, PV, PVC & StorageClass

| | |
|---|---|
| **Level** | Beginner/Intermediate |
| **Time** | ~60 min |
| **Prereqs** | [Pods](../pod/pod.md), [Deployments](../deployments/deployments.md), [Services](../services/services.md), [ConfigMaps & Secrets](../configmaps_secrets/configmaps_secrets.md) |
| **Files** | See the table below |

> Run all commands from the repo root.

| File | Purpose |
|---|---|
| [`volumes/sc.yaml`](sc.yaml) | StorageClass `demo-storage` (dynamic provisioning) |
| [`volumes/pvc.yaml`](pvc.yaml) | PVC `mongo-pvc-sc`, 5Gi |
| [`volumes/pv.yaml`](pv.yaml) | Static local PV `mongo-pv` example |
| [`volumes/deployment.yaml`](deployment.yaml) | `mongo` Deployment using the PVC |
| [`volumes/service.yaml`](service.yaml) | NodePort Service `mongo-service` (30017) |
| [`volumes/emptydir-pod.yaml`](emptydir-pod.yaml) | Pod `shared`: two containers share an emptyDir |
| [`volumes/sc-wait.yaml`](sc-wait.yaml) | StorageClass `wait-storage` (WaitForFirstConsumer, Retain) |
| [`volumes/pvc-wait.yaml`](pvc-wait.yaml) | PVC `wait-pvc` using `wait-storage` |

---

## 1. What is it?

A container file system is **temporary**. When the container restarts, all files written inside it are gone.

A **Volume** is a folder that a Pod can mount. Some volumes live only as long as the Pod (`emptyDir`). Others live outside the Pod and keep data (PersistentVolume).

The persistent storage system in Kubernetes has 3 parts:

| Object | What it is | Scope |
|---|---|---|
| **PersistentVolume (PV)** | A real piece of storage (disk, NFS, cloud disk). Made by an admin or by a provisioner. Exists independently of Pods. | Cluster-scoped |
| **PersistentVolumeClaim (PVC)** | A **request** for storage by a user: "I need 5Gi, ReadWriteOnce". Binds to a matching PV and is used inside Pod specs. | Namespaced |
| **StorageClass (SC)** | A "type" of storage (SSD, HDD, network, cloud) and a recipe to create PVs automatically. Each SC names a **provisioner** plugin and parameters. | Cluster-scoped |

Picture:

```text
Pod --uses--> PVC --bound to--> PV --points to--> real disk
               |
               +--asks--> StorageClass --creates--> PV (dynamic)
```

---

## 2. Why do we need it?

- Pods are **ephemeral**: they can be restarted, rescheduled, or deleted at any time. Databases (MongoDB, PostgreSQL) must keep data after a restart.
- Developers should not need to know WHERE the disk is. They write a PVC. Admins (or the cloud) give the real storage.
- The same YAML can work on Minikube, AWS, GCP: only the StorageClass changes.

---

## 3. Key concepts

### a) Simple volume types

| Type | Behaviour |
|---|---|
| `emptyDir` | Empty folder, created when the Pod starts on a node, DELETED when the Pod is removed. Survives container restarts. Good for cache or sharing files between two containers in one Pod. `medium: Memory` uses RAM (tmpfs). |
| `hostPath` | Mounts a folder from the NODE. Data stays on that node only. If the Pod moves to another node, data is "lost". Security risk in production. OK for Minikube labs. |
| `configMap` / `secret` | See [Topic 10: ConfigMaps & Secrets](../configmaps_secrets/configmaps_secrets.md). |

### b) Access modes (what the volume SUPPORTS; depends on the driver)

| Short | Mode | Meaning |
|---|---|---|
| RWO | ReadWriteOnce | Read-write by Pods on ONE node |
| ROX | ReadOnlyMany | Read-only by many nodes |
| RWX | ReadWriteMany | Read-write by many nodes (NFS, CephFS, EFS) |
| RWOP | ReadWriteOncePod | Read-write by ONE single Pod (GA in v1.29, CSI volumes only) |

- Note: RWO allows many Pods on the SAME node. Use RWOP for one Pod.
- Note: `minikube-hostpath` does not really enforce access modes, so [`volumes/pvc.yaml`](pvc.yaml) asks for RWX and still works on one node.

### c) Reclaim policy (what happens to the PV after the PVC is deleted)

| Policy | Behaviour |
|---|---|
| `Delete` | PV and the real storage are deleted. Default for dynamic. |
| `Retain` | PV stays in `Released` state with the data. An admin must clean it and make it usable again by hand. |
| `Recycle` | Deprecated. Do not use. |

### d) Static vs dynamic provisioning

- **Static**: admin creates PVs first. A PVC binds to a matching PV (same `storageClassName`, enough size, matching access mode). Example: [`volumes/pv.yaml`](pv.yaml) (a "local" PV on node minikube).
- **Dynamic**: PVC names a StorageClass. The provisioner creates a new PV automatically. Example: [`volumes/sc.yaml`](sc.yaml) + [`volumes/pvc.yaml`](pvc.yaml).

### e) Default StorageClass

One SC can be marked default (annotation `storageclass.kubernetes.io/is-default-class: "true"`). Minikube has `standard` as default. A PVC with NO `storageClassName` gets the default. A PVC with `storageClassName: ""` means "no class, static PV only".

### f) volumeBindingMode

| Mode | Behaviour |
|---|---|
| `Immediate` | PV is created/bound as soon as the PVC exists (used by [`volumes/sc.yaml`](sc.yaml)). |
| `WaitForFirstConsumer` | Wait until a Pod uses the PVC. Then the PV is created on the node/zone where the Pod is scheduled. Recommended for local disks and multi-zone clouds. Required for "local" PVs. |

### g) PV lifecycle (STATUS column)

```text
Available -> Bound -> Released -> (deleted or reused by admin)
Failed    -> automatic reclaim failed
```

### h) Expanding a PVC

If the SC has `allowVolumeExpansion: true`, you can edit the PVC and make `spec.resources.requests.storage` bigger. You can NOT shrink.

---

## 4. Example YAML

### [`volumes/sc.yaml`](sc.yaml)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass                 # cluster-scoped
metadata:
  name: demo-storage               # PVCs use this name
provisioner: k8s.io/minikube-hostpath   # who creates the PVs
volumeBindingMode: Immediate       # bind right away, no wait for a Pod
reclaimPolicy: Delete              # delete PV when the PVC is deleted
```

### [`volumes/pvc.yaml`](pvc.yaml)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim        # namespaced
metadata:
  name: mongo-pvc-sc
spec:
  accessModes:
    - ReadWriteMany                # asks for RWX
  resources:
    requests:
      storage: 5Gi                 # minimum size wanted
  storageClassName: "demo-storage" # -> dynamic provisioning
```

### [`volumes/pv.yaml`](pv.yaml) (static example, short)

It is NOT used by `mongo-pvc-sc` (different class), so that PVC gets a dynamically provisioned PV instead.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongo-pv
spec:
  capacity:
    storage: 5Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain   # keep data after PVC delete
  storageClassName: manual-local   # a PVC must ask for this class
  local:
    path: /storage/data            # folder must already exist on node
  nodeAffinity:                    # local PV MUST say which node
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values: ["minikube"]
```

### Pod volume part of [`volumes/deployment.yaml`](deployment.yaml)

```yaml
      volumes:
        - name: mongo-volume
          # emptyDir: {}               # option 1: temp data
          # hostPath:                  # option 2: node folder
          #   path: /data
          persistentVolumeClaim:       # option 3: persistent (used)
            claimName: mongo-pvc-sc
```

### A better SC for local-style disks: [`volumes/sc-wait.yaml`](sc-wait.yaml)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: wait-storage
provisioner: k8s.io/minikube-hostpath
volumeBindingMode: WaitForFirstConsumer   # PV created when Pod is placed
reclaimPolicy: Retain                     # keep data after PVC delete
allowVolumeExpansion: true                # allow bigger size later
                                          # (only if the driver supports
                                          # it; hostpath does not resize)
```

And a PVC that uses it, [`volumes/pvc-wait.yaml`](pvc-wait.yaml):

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wait-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: wait-storage
```

### emptyDir shared by two containers: [`volumes/emptydir-pod.yaml`](emptydir-pod.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared
spec:
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "while true; do date >> /data/log; sleep 2; done"]
      volumeMounts:
        - {name: tmp, mountPath: /data}
    - name: reader
      image: busybox:1.36
      command: ["sh", "-c", "tail -f /data/log"]
      volumeMounts:
        - {name: tmp, mountPath: /data}
  volumes:
    - name: tmp
      emptyDir: {}                 # lives as long as the Pod
```

---

## 5. Hands-on lab

### Step 1: See existing storage classes

```bash
kubectl get storageclass
# -> "standard (default)   k8s.io/minikube-hostpath   Delete  Immediate"
```

### Step 2: emptyDir test

```bash
kubectl apply -f volumes/emptydir-pod.yaml
kubectl logs shared -c reader --tail=3
# -> dates printed by the writer container.
kubectl delete pod shared
```

### Step 3: Create the repo StorageClass and PVC

```bash
kubectl apply -f volumes/sc.yaml
kubectl apply -f volumes/pvc.yaml
kubectl get pvc
# -> mongo-pvc-sc   Bound   pvc-xxxx   5Gi   RWX   demo-storage
kubectl get pv
# -> a new PV "pvc-xxxx" was created automatically (dynamic).
```

### Step 4: Run MongoDB with the PVC

```bash
kubectl apply -f volumes/deployment.yaml
kubectl apply -f volumes/service.yaml
kubectl get pods -l app=mongo -w      # wait for Running, Ctrl+C
```

### Step 5: Write data

```bash
kubectl exec -it deploy/mongo -- mongosh -u admin -p password \
  --eval 'db.getSiblingDB("shop").items.insertOne({name:"apple"})'
```

(Old mongo images use `mongo` instead of `mongosh`.)

### Step 6: Delete the Pod and check data survives

```bash
kubectl delete pod -l app=mongo
kubectl get pods -l app=mongo -w      # new Pod comes up
kubectl exec -it deploy/mongo -- mongosh -u admin -p password \
  --eval 'db.getSiblingDB("shop").items.find()'
# -> { name: 'apple' }   Data is still there.
```

### Step 7: Look at the real folder on the node

```bash
kubectl get pv -o jsonpath='{.items[0].spec.hostPath.path}'; echo
minikube ssh -- ls /tmp/hostpath-provisioner/default/
# -> a folder named mongo-pvc-sc
```

### Step 8: Static PV (optional)

```bash
minikube ssh -- sudo mkdir -p /storage/data
kubectl apply -f volumes/pv.yaml
kubectl get pv mongo-pv
# -> STATUS Available.
```

It stays Available because no PVC asks for `storageClassName: manual-local`. (Try: write a PVC with that class, 5Gi, ReadWriteOnce, and it binds to `mongo-pv`.)

### Step 9: See WaitForFirstConsumer

```bash
kubectl apply -f volumes/sc-wait.yaml
kubectl apply -f volumes/pvc-wait.yaml
kubectl get pvc
# -> wait-pvc STATUS Pending.
kubectl describe pvc wait-pvc
# -> Events: "waiting for first consumer to be created before binding"
```

It binds when a Pod uses it.

### Step 10: Clean up and see the reclaim policy

```bash
kubectl delete -f volumes/deployment.yaml -f volumes/service.yaml
kubectl delete -f volumes/pvc.yaml
kubectl get pv
# -> the dynamic PV is gone (reclaimPolicy Delete).
kubectl delete -f volumes/pv.yaml
kubectl delete -f volumes/pvc-wait.yaml -f volumes/sc-wait.yaml
```

Keep `volumes/sc.yaml` (`demo-storage`) if you go on to [Topic 12: StatefulSets](../statefulset/statefulset.md); otherwise remove it too with `kubectl delete -f volumes/sc.yaml`.

---

## 6. Common mistakes & troubleshooting

- **PVC stuck in `Pending`**
  - `kubectl describe pvc <name>`. Reasons:
    - `storageClassName` does not exist (typo)
    - no PV matches (size too small, wrong access mode, wrong class)
    - `WaitForFirstConsumer` and no Pod uses it yet (this is normal)
- **Pod stuck `ContainerCreating` with "Multi-Attach error"**
  - An RWO cloud disk is still attached to another node. Wait, or make sure the old Pod is gone. Deployments with RWO volumes should use strategy type `Recreate`.
- **Data lost after Pod restart**
  - You used `emptyDir`, or no volume at all.
- **PVC deleted, data gone**
  - `reclaimPolicy` was `Delete`. For important data use `Retain`, and take backups (for example with Velero).
- **PV stays `Released` and new PVC cannot use it**
  - `Retain` keeps a `claimRef`. Clean the data, then remove `spec.claimRef` from the PV to make it Available again.
- **PVC stuck `Terminating`**
  - A Pod still uses it (finalizer `kubernetes.io/pvc-protection`). Delete the Pod first.
- **Permission denied when writing to the volume**
  - The container user cannot write to the folder. Use `securityContext.fsGroup` or run as the right user.

---

## 7. Cheat sheet

| Command | What it does |
|---|---|
| `kubectl get sc` | List StorageClasses |
| `kubectl get pv` | List PersistentVolumes |
| `kubectl get pvc -A` | List claims in all namespaces |
| `kubectl describe pvc NAME` | Why is it Pending? (PVC info and events) |
| `kubectl describe pv NAME` | Detailed PV info |
| `kubectl get pv NAME -o yaml` | See source path, claimRef |
| `kubectl patch pv NAME -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'` | Change reclaim policy |
| `kubectl patch pvc NAME -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'` | Expand (if SC allows) |
| `kubectl patch sc standard -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'` | Un-default a class |
| `minikube ssh` | Look at node folders |

---

## 8. Practice tasks

1. Change [`volumes/deployment.yaml`](deployment.yaml) to use `emptyDir` (copy the file first). Insert data, delete the Pod, and show the data is gone.
2. Create a PVC with NO `storageClassName`. Which SC does it get? Why?
3. Create an SC with `reclaimPolicy: Retain`. Make a PVC, delete it, and show the PV is `Released`. Make it `Available` again.
4. Write a static PV (hostPath, 1Gi, `storageClassName: manual`) and a PVC that binds to it. Prove they are Bound to each other.
5. Explain in 3 lines why `WaitForFirstConsumer` is better for a cluster with nodes in many zones.

---

## 9. Quiz

1. Which object is namespaced: PV or PVC?
2. What happens to an emptyDir when the Pod is deleted?
3. What is the difference between RWO and RWOP?
4. A PVC is deleted. The PV has reclaimPolicy Retain. What is the PV status now?
5. What does volumeBindingMode WaitForFirstConsumer do?

<details><summary>Quiz answers</summary>

1. PVC is namespaced. PV (and StorageClass) are cluster-scoped.
2. It is deleted with all its data. (It survives container restarts.)
3. RWO = one NODE can mount it read-write (many Pods on that node is OK). RWOP = only ONE Pod in the whole cluster can use it.
4. `Released`. Data is kept. An admin must clean it up manually.
5. It delays binding/creating the PV until a Pod using the PVC is scheduled, so the volume is made on the right node/zone.

</details>

---

**Previous:** [Topic 10: ConfigMaps & Secrets](../configmaps_secrets/configmaps_secrets.md) | **Next:** [Topic 12: StatefulSets](../statefulset/statefulset.md) | [Back to README](../README.md)
