# Kubernetes Storage: PV, PVC, and StorageClass

##  Why Do We Need Persistent Storage in Kubernetes?

In Kubernetes, Pods are **ephemeral**—they can be restarted, rescheduled, or deleted at any time. Any data stored inside a container’s filesystem will be lost if the container dies.

To persist data beyond the lifecycle of a Pod, Kubernetes introduces **Persistent Volumes (PV)** and **Persistent Volume Claims (PVC)**.

---

## Core Components

###  PersistentVolume (PV)

A `PersistentVolume` is a piece of storage in the cluster that has been provisioned either **manually by an administrator** or **dynamically using a StorageClass**. It represents real storage: a disk on the node, NFS share, cloud disk, etc.

- Managed by Kubernetes
- Exists independently of Pods
- Defined once, reusable across workloads

### PersistentVolumeClaim (PVC)

A `PersistentVolumeClaim` is a request for storage by a user or a Pod. It specifies **how much storage** is needed and **what access mode** is required.

- Bound to a matching PV
- Used inside Pod specs to mount volumes

###  StorageClass

A `StorageClass` provides a way to describe different classes or "types" of storage. It is also used to enable **dynamic provisioning** of PVs.

- Example: SSD, HDD, network-backed, cloud-native
- Each StorageClass defines a **provisioner** plugin and parameters
- PVCs referencing a StorageClass will trigger dynamic volume creation

---

## The Storage Flow in Kubernetes


Pod → PVC → (binds to) PV ← (created by) StorageClass


# Apply StorageClass
    kubectl apply -f sc.yaml

# Apply PersistentVolume (if static)
    kubectl apply -f pv.yaml

# Apply PersistentVolumeClaim
    kubectl apply -f pvc.yaml

# Apply Deployment using PVC
    kubectl apply -f deployment.yaml



# Useful kubectl Commands

    kubectl get pv                      # List PersistentVolumes
    kubectl get pvc                     # List PersistentVolumeClaims
    kubectl get storageclass            # View available StorageClasses
    kubectl describe pvc <name>         # Detailed PVC info and events
    kubectl describe pv <name>          # Detailed PV info

# Clean Up

    kubectl delete -f deployment.yaml
    kubectl delete -f pvc.yaml
    kubectl delete -f pv.yaml         
    kubectl delete -f sc.yaml
