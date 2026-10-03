# Topic 09: Namespaces

| | |
|---|---|
| **Level** | Beginner |
| **Time** | ~40 min |
| **Prereqs** | [Pods](../pod/pod.md), [Deployments](../deployments/deployments.md), [Services](../services/services.md) |
| **Files** | [`namespaces/nginx-namespaces.yaml`](nginx-namespaces.yaml), [`namespaces/dev-ns.yaml`](dev-ns.yaml), [`deployments/nginx-deployments.yaml`](../deployments/nginx-deployments.yaml), [`services/nginx-services.yaml`](../services/nginx-services.yaml) |

> Run all commands from the repo root.

---

## 1. What is it?

A Namespace is a "folder" inside one Kubernetes cluster.

It groups objects (Pods, Deployments, Services, ConfigMaps, Secrets ...) together. Names must be unique **inside** a namespace, but the same name can be used in two different namespaces.

Example: you can have `nginx-deployment` in namespace `dev` and another `nginx-deployment` in namespace `prod`. They do not conflict.

Every cluster starts with these namespaces:

| Namespace | Purpose |
|---|---|
| `default` | Used when you do not say a namespace |
| `kube-system` | Kubernetes system parts (CoreDNS, kube-proxy, ...) |
| `kube-public` | Readable by everyone, rarely used |
| `kube-node-lease` | Node heartbeats (Lease objects) |

Minikube addons may create more (for example `ingress-nginx`).

---

## 2. Why do we need it?

| Benefit | Description |
|---|---|
| Separate teams | `team-a` and `team-b` do not see each other's objects in normal `kubectl get` output |
| Separate stages | `dev`, `staging`, `prod` in one cluster (small setups) |
| Limit resources | ResourceQuota caps CPU, memory, number of Pods per namespace |
| Default sizes | LimitRange gives default requests/limits to containers that do not set them |
| Access control | RBAC Roles are namespaced. You can give a user rights in only one namespace |
| Easy cleanup | `kubectl delete namespace dev` deletes everything inside it |

> **Important:** a namespace is NOT a strong security wall. Pods in different namespaces can still talk over the network by default. Use a [NetworkPolicy](../network_policies/network_policies.md) to block traffic.

### When to use namespaces

Use them when you have:

- Multiple teams sharing a cluster
- Separate environments (dev/stg/prod)
- Names that may overlap between projects
- Resource quota and isolation needs

You may skip them when:

- You have a small cluster with 1-2 apps
- You have no need for isolation or RBAC

---

## 3. Key concepts

### a) Namespaced vs cluster-scoped objects

| Scope | Examples |
|---|---|
| Namespaced | Pod, Deployment, Service, ConfigMap, Secret, PVC, Role, ResourceQuota, LimitRange, Ingress ... |
| Cluster-scoped | Node, PersistentVolume, StorageClass, Namespace, ClusterRole, IngressClass ... |

Check with:

```bash
kubectl api-resources --namespaced=true
kubectl api-resources --namespaced=false
```

### b) DNS across namespaces

A Service gets this DNS name:

```text
<service>.<namespace>.svc.cluster.local
```

Inside the same namespace, just `<service>` is enough. From another namespace, use `<service>.<namespace>`.

Example: `nginx-service.nginx.svc.cluster.local`

### c) Current namespace (context)

kubectl uses `default` unless you pass `-n` or change your context:

```bash
kubectl config set-context --current --namespace=nginx
```

### d) ResourceQuota

Sets a **max total** for the whole namespace. Example: total CPU requests must not be more than 2 cores. If a new Pod would go over the quota, the API server **rejects** it.

If a quota covers cpu/memory, every new Pod **must** set requests/limits for them (or get defaults from a LimitRange). Otherwise it is rejected.

### e) LimitRange

Works per container (or per Pod / PVC). It can:

- set **default** requests and limits when the container has none
- set **min** and **max** values allowed for one container

### f) Deleting a namespace

The namespace goes to `Terminating` state, then all objects inside are deleted. This can take some time.

---

## 4. Example YAML

### [`namespaces/nginx-namespaces.yaml`](nginx-namespaces.yaml)

```yaml
apiVersion: v1
kind: Namespace              # cluster-scoped object
metadata:
  name: nginx                # lowercase, a-z 0-9 and "-" only
```

### Quota + limit range for a "dev" namespace: [`namespaces/dev-ns.yaml`](dev-ns.yaml)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dev
  labels:
    env: dev                 # labels help you select namespaces later
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev             # quota lives INSIDE the namespace it limits
spec:
  hard:
    pods: "5"                # max 5 Pods in this namespace
    requests.cpu: "1"        # sum of all CPU requests <= 1 core
    requests.memory: 1Gi     # sum of all memory requests <= 1 GiB
    limits.cpu: "2"          # sum of all CPU limits <= 2 cores
    limits.memory: 2Gi       # sum of all memory limits <= 2 GiB
    services: "5"            # max 5 Services
    persistentvolumeclaims: "3"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
  namespace: dev
spec:
  limits:
    - type: Container
      defaultRequest:        # used when a container has NO requests
        cpu: 100m            # 100 millicores = 0.1 CPU
        memory: 64Mi
      default:               # used when a container has NO limits
        cpu: 200m
        memory: 128Mi
      max:                   # one container can never ask more than this
        cpu: 500m
        memory: 512Mi
      min:
        cpu: 50m
        memory: 32Mi
```

---

## 5. Hands-on lab

### Step 1: Start minikube and list namespaces

```bash
minikube start
kubectl get namespaces
# -> You see default, kube-system, kube-public, kube-node-lease.
```

### Step 2: Create the "nginx" namespace from the repo

```bash
kubectl apply -f namespaces/nginx-namespaces.yaml
kubectl get ns
# -> "nginx   Active"
```

### Step 3: Deploy nginx into that namespace

```bash
kubectl apply -f deployments/nginx-deployments.yaml -n nginx
kubectl apply -f services/nginx-services.yaml -n nginx
kubectl get pods -n nginx
# -> 3 Pods "nginx-deployment-xxxx" Running.
kubectl get pods
# -> "No resources found in default namespace." (they are in "nginx")
```

### Step 4: See objects in all namespaces

```bash
kubectl get pods -A
# -> NAMESPACE column shows where each Pod lives.
```

### Step 5: Test DNS across namespaces

```bash
kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- \
  wget -qO- http://nginx-service.nginx.svc.cluster.local:8080
# -> HTML of the nginx welcome page. ("tmp" runs in "default",
#    but it reaches the Service in "nginx".)
```

### Step 6: Create "dev" with quota and limit range

```bash
kubectl apply -f namespaces/dev-ns.yaml
kubectl describe resourcequota dev-quota -n dev
kubectl describe limitrange dev-limits -n dev
```

### Step 7: See the LimitRange defaults in action

```bash
kubectl run web --image=nginx:1.27 -n dev
kubectl get pod web -n dev -o jsonpath='{.spec.containers[0].resources}'
# -> {"limits":{"cpu":"200m","memory":"128Mi"},
#     "requests":{"cpu":"100m","memory":"64Mi"}}
```

You did not write resources, the LimitRange added them.

### Step 8: Hit the quota

```bash
kubectl create deployment many --image=nginx:1.27 --replicas=8 -n dev
kubectl get pods -n dev
# -> Only 4 new Pods (5 total with "web").
kubectl get rs -n dev
kubectl describe rs -n dev | grep -i forbidden
# -> "exceeded quota: dev-quota, requested: pods=1, used: pods=5,
#     limited: pods=5"
```

### Step 9: Change your default namespace, then go back

```bash
kubectl config set-context --current --namespace=dev
kubectl get pods            # now shows "dev" Pods
kubectl config set-context --current --namespace=default
```

### Step 10: Clean up

```bash
kubectl delete namespace dev
kubectl delete namespace nginx
# -> Everything inside is deleted too.
```

---

## 6. Common mistakes & troubleshooting

- **"No resources found" but you know the Pod exists**
  - You are looking in the wrong namespace. Add `-n <ns>` or use `-A`.
- **Service in another namespace not reachable by short name**
  - Use `<service>.<namespace>` or the full name with `.svc.cluster.local`.
- **Pod rejected: "must specify limits.cpu, limits.memory ..."**
  - A ResourceQuota covers cpu/memory. Add resources to the Pod, or add a LimitRange with defaults.
- **Deployment shows READY 2/5 and no error on the Pods**
  - The ReplicaSet could not create Pods. Run `kubectl describe rs -n <ns>` and look for "exceeded quota".
- **Namespace stuck in "Terminating"**
  - Some object has a finalizer that never finishes. Check:

    ```bash
    kubectl get all -n <ns>
    kubectl api-resources --verbs=list --namespaced -o name \
      | xargs -n 1 kubectl get -n <ns> --ignore-not-found
    ```

  - Fix or remove the stuck object (do not force-delete blindly).
- **`metadata.namespace` in YAML differs from the `-n` flag**
  - kubectl gives an error ("the namespace from the provided object does not match"). Use one of them, not both with different values.
- **Trying to put a PV or StorageClass in a namespace**
  - They are cluster-scoped. The `namespace` field is ignored.

---

## 7. Cheat sheet

| Command | What it does |
|---|---|
| `kubectl get ns` | List namespaces |
| `kubectl create namespace dev` | Create namespace "dev" |
| `kubectl apply -f x.yaml -n dev` | Create objects in "dev" |
| `kubectl get pods -n dev` | List Pods in "dev" |
| `kubectl get pods -A` | List Pods in all namespaces |
| `kubectl get all -n dev` | Common objects in "dev" |
| `kubectl config set-context --current --namespace=dev` | Make "dev" your default |
| `kubectl config view --minify \| grep namespace` | Show current default ns |
| `kubens <namespace>` | Switch namespace (via the `kubectx` plugin) |
| `kubectl describe quota -n dev` | Show quota used / hard |
| `kubectl describe limitrange -n dev` | Show default/min/max values |
| `kubectl api-resources --namespaced=false` | List cluster-scoped kinds |
| `kubectl delete ns dev` | Delete ns and ALL inside it |

---

## 8. Practice tasks

1. Create namespaces `team-a` and `team-b`. Deploy `nginx:1.27` with the same Deployment name `web` in both. Show that both exist.
2. From a `busybox:1.36` Pod in `team-a`, call the `web` Service in `team-b` using its DNS name.
3. Add a ResourceQuota to `team-a` that allows only 2 Pods. Scale `web` to 4 replicas. Find the error message that explains why only 2 run.
4. Add a LimitRange with max memory 256Mi. Try to create a Pod that asks for 512Mi memory. Read the error.
5. List 5 object kinds that are cluster-scoped using kubectl.

---

## 9. Quiz

1. Which namespace is used if you do not pass `-n`?
2. Is a PersistentVolume namespaced?
3. What is the full DNS name of Service `api` in namespace `shop`?
4. What is the difference between ResourceQuota and LimitRange?
5. Does a namespace block network traffic between Pods by default?

<details><summary>Quiz answers</summary>

1. `default` (unless you changed the namespace in your kubectl context).
2. No. PersistentVolume is cluster-scoped. The PVC is namespaced.
3. `api.shop.svc.cluster.local`
4. ResourceQuota limits the **total** for the whole namespace. LimitRange sets defaults and min/max for **each** container (or Pod/PVC).
5. No. You need a NetworkPolicy (and a CNI that supports it) to block it.

</details>

---

**Previous:** [Topic 08: Services](../services/services.md) | **Next:** [Topic 10: ConfigMaps & Secrets](../configmaps_secrets/configmaps_secrets.md) | [Back to README](../README.md)
