# Topic 04: Pods

| | |
|---|---|
| **Level** | Beginner |
| **Time** | ~60 min |
| **Prereqs** | [Topic 03: Setup Minikube & kubectl](../kubernetes_install/kubernetes_install.md) |
| **Files** | [`nginx-pod.yaml`](nginx-pod.yaml), [`pod-demo.yaml`](pod-demo.yaml) |

> Run all commands from the repo root.

---

## 1. What is it?

A **Pod** is the smallest thing you can deploy in Kubernetes. A Pod is a
wrapper around ONE or MORE containers that:

- always run on the SAME node,
- share the SAME network (one IP address, they talk via localhost),
- can share VOLUMES (folders).

Most Pods have one container. Some have a main container plus small
helper containers.

| Concept | Details |
|---------|---------|
| **Pod** | A wrapper around one or more containers. Pods are scheduled and run on Nodes. |
| **Container(s)** | The actual app runs inside containers. Pods often contain a single container. |
| **Shared storage** | If defined (e.g. a volume), all containers in the Pod can access it. |
| **Shared network** | All containers in a Pod share the same IP address and port space. |
| **Ephemeral** | Pods are not permanent. A failed or deleted Pod is replaced only if a controller (Deployment, ReplicaSet, etc.) manages it. |

---

## 2. Why do we need it?

Kubernetes does not run "bare" containers. It runs Pods. The Pod gives
containers a shared network and storage, so tightly coupled helpers
(for example a log shipper) can live next to the main app.

> **Important:** Pods are DISPOSABLE. If a Pod dies or its node dies, the Pod
> is NOT moved. It is gone. A controller (ReplicaSet, Deployment...) must
> create a NEW Pod (new name, new IP). So in real life you almost never
> create Pods directly. You create Deployments ([Topic 07](../deployments/deployments.md)). But you must
> understand Pods first, because everything is built on them.

When to use a Pod directly? Only for learning or debugging. In real-world production:

- Use **Deployments** for managing updates and replicas
- Use **Services** to expose Pods and load balance traffic
- Use **StatefulSets**, **DaemonSets**, **Jobs** etc. for more specific behavior

---

## 3. Key concepts

**Pod IP**
Each Pod gets its own IP from the cluster network. All containers in
the Pod share it. A new Pod gets a new IP. Do not depend on Pod IPs;
use Services ([Topic 08](../services/services.md)).

**Multi-container patterns**

| Pattern | Purpose |
|---------|---------|
| Sidecar | Helper that runs next to the app all the time (log shipper, proxy, file sync). |
| Ambassador | Proxy for outgoing connections (for example to a DB). |
| Adapter | Changes the app output into a standard format. |

**Native sidecar containers** (Kubernetes 1.29+ beta, GA in 1.33)
An init container with `restartPolicy: Always`. It starts BEFORE the
main containers and keeps running. It stops AFTER them. This fixes
old problems (for example a Job that never ends because a sidecar
keeps running).

**Init containers**
Run BEFORE the app containers, one by one, in order. Each must finish
successfully. Use them to wait for a database, download config, run
migrations, or set file permissions. If one fails, kubelet retries it.

**Pod phases** (`status.phase`)

| Phase | Meaning |
|-------|---------|
| Pending | Accepted, but not all containers are running yet (waiting for scheduling or image download). |
| Running | On a node, at least one container is running. |
| Succeeded | All containers exited with code 0 and will not restart. |
| Failed | All containers ended, at least one with an error. |
| Unknown | Node cannot be reached. |

**Container states**
`Waiting` (with reason: `ContainerCreating`, `ImagePullBackOff`,
`CrashLoopBackOff`...), `Running`, `Terminated` (with exit code).

**Restart policy** (`spec.restartPolicy`, for the whole Pod)

| Value | Behavior |
|-------|----------|
| `Always` | Restart containers whenever they stop (default; web apps) |
| `OnFailure` | Restart only if exit code is not 0 (batch jobs) |
| `Never` | Never restart |

Restarts use an exponential back-off: 10s, 20s, 40s... up to 5 min.
That is the "BackOff" in `CrashLoopBackOff`.

**Pod lifecycle (simple)**

1. Created in API -> Pending
2. Scheduled to a node
3. Image pulled, init containers run one by one
4. App containers start -> Running
5. Probes check health ([Topic 15](../probes_resources/probes_resources.md))
6. On delete: Pod gets SIGTERM, has `terminationGracePeriodSeconds`
   (default 30s) to stop cleanly, then SIGKILL.

**Static Pods**
Pods the kubelet runs from files on the node (for example
`/etc/kubernetes/manifests`). The control plane Pods in Minikube are
static Pods.

**Image pull policy**
`IfNotPresent` (default for pinned tags), `Always` (default for `:latest`
or no tag), `Never`. Another reason to avoid `:latest`.

---

## 4. Example YAML

### A) The repo file [`pod/nginx-pod.yaml`](nginx-pod.yaml) (simple Pod)

```yaml
apiVersion: v1                 # Pods are in the core API group "v1"
kind: Pod
metadata:
  name: nginx-pod              # unique name in the namespace
  labels:
    app: nginx                 # label, used by Services/selectors
spec:
  containers:
  - name: nginx-container      # container name inside the Pod
    image: nginx:latest        # repo uses latest; better: nginx:1.27
    ports:
    - containerPort: 80        # informational; app listens on 80
```

### B) Multi-container Pod with an init container and a sidecar

Saved as [`pod/pod-demo.yaml`](pod-demo.yaml):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-with-helpers
  labels:
    app: web
spec:
  restartPolicy: Always              # default; restart if they stop
  volumes:
  - name: html                       # shared folder for all containers
    emptyDir: {}                     # lives as long as the Pod lives
  - name: logs
    emptyDir: {}
  initContainers:
  - name: write-page                 # 1) runs first, must finish OK
    image: busybox:1.36
    command: ["sh", "-c", "echo '<h1>Hello init</h1>' > /work/index.html"]
    volumeMounts:
    - name: html
      mountPath: /work
  - name: log-shipper                # 2) native sidecar (K8s 1.29+)
    image: busybox:1.36
    restartPolicy: Always            # THIS makes it a sidecar
    command: ["sh", "-c", "touch /logs/access.log; tail -F /logs/access.log"]
    volumeMounts:
    - name: logs
      mountPath: /logs
  containers:
  - name: nginx                      # 3) main app
    image: nginx:1.27                # pinned tag
    ports:
    - containerPort: 80
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html   # serve the page from init
    - name: logs
      mountPath: /var/log/nginx          # nginx writes logs here
```

> **Note:** on clusters older than 1.29, move `log-shipper` into
> `containers:` and remove its `restartPolicy` line (classic sidecar).

---

## 5. Hands-on lab

**Step 1. Create the repo Pod**

```bash
kubectl apply -f pod/nginx-pod.yaml
kubectl get pods -o wide
```

You should see: `nginx-pod  1/1  Running  ...` with an IP and NODE
`minikube`. READY `1/1` = 1 of 1 containers ready.

**Step 2. Look at details and events**

```bash
kubectl describe pod nginx-pod
```

Read "Events" at the bottom: Scheduled, Pulling, Pulled, Created,
Started.

**Step 3. Logs and exec**

```bash
kubectl logs nginx-pod
kubectl exec -it nginx-pod -- sh
  curl -s localhost | head -5   # if curl missing: exit and skip
  exit
```

**Step 4. Reach the Pod from your laptop**

```bash
kubectl port-forward pod/nginx-pod 8080:80
# in another terminal:
curl http://localhost:8080
```

You should see: `Welcome to nginx!`. Ctrl+C to stop.

**Step 5. Prove Pods are disposable**

```bash
kubectl delete pod nginx-pod
kubectl get pods
```

You should see: it is gone. Nobody recreates it (no controller).

**Step 6. Multi-container Pod**

```bash
kubectl apply -f pod/pod-demo.yaml
kubectl get pod web-with-helpers -w
```

You should see: `Init:0/2` -> `Init:1/2` -> `PodInitializing` -> `Running`.
READY shows `2/2` (nginx + native sidecar).

**Step 7. Check each container**

```bash
kubectl logs web-with-helpers -c write-page
  # (empty output is OK: it wrote to a file, not to stdout)
kubectl port-forward pod/web-with-helpers 8080:80
curl http://localhost:8080        # -> <h1>Hello init</h1>
kubectl logs web-with-helpers -c log-shipper
```

You should see: the access log line from your curl request.

**Step 8. See restartPolicy in action**

```bash
kubectl run crash --image=busybox:1.36 --restart=Always -- sh -c "exit 1"
kubectl get pod crash -w
```

You should see: `Error` -> `CrashLoopBackOff`, RESTARTS going up.

```bash
kubectl run once --image=busybox:1.36 --restart=Never -- sh -c "exit 1"
kubectl get pod once
```

You should see: STATUS `Error`, RESTARTS `0`.

**Step 9. Clean up**

```bash
kubectl delete pod web-with-helpers crash once
```

---

## 6. Common mistakes & troubleshooting

| Problem | Cause / Fix |
|---------|-------------|
| `ImagePullBackOff` / `ErrImagePull` | Wrong image name or tag, or a private registry without a secret. Check: `kubectl describe pod <name>` -> Events. |
| `CrashLoopBackOff` | Container starts and dies again and again. Read the logs of the PREVIOUS run: `kubectl logs <pod> --previous` |
| `Pending` | No node can fit it (CPU/memory) or a PVC is not bound. Check Events in `kubectl describe`. |
| `Init:CrashLoopBackOff` / stuck at `Init:0/1` | An init container fails. `kubectl logs <pod> -c <init-name>` |
| `error: a container name must be specified` | Multi-container Pod: add `-c <container-name>`. |
| Trying to edit most fields of a running Pod | Most Pod spec fields are immutable (image is an exception). Delete and recreate, or better: use a Deployment. |
| Using Pods directly in production | No self-healing. Use a Deployment / StatefulSet / Job. |

---

## 7. Cheat sheet

| Command | What it does |
|---------|--------------|
| `kubectl run web --image=nginx:1.27` | Create a Pod quickly |
| `kubectl apply -f pod/nginx-pod.yaml` | Create/update from file |
| `kubectl get pods [-o wide] [--show-labels]` | List Pods |
| `kubectl get pod web -o yaml` | Full object + status |
| `kubectl describe pod web` | Details + events |
| `kubectl logs web [-c ctr] [-f] [--previous]` | Container logs |
| `kubectl exec -it web [-c ctr] -- sh` | Shell in container |
| `kubectl port-forward pod/web 8080:80` | Local port to Pod |
| `kubectl cp web:/etc/nginx/nginx.conf ./n.conf` | Copy file from Pod |
| `kubectl delete pod web [--grace-period=0 --force]` | Delete |
| `kubectl get pod web -o jsonpath='{.status.phase}'` | Show phase |
| `kubectl debug -it web --image=busybox:1.36 --target=nginx` | Ephemeral debug container |
| `kubectl delete -f pod/nginx-pod.yaml` | Delete Pods defined in a file |

---

## 8. Practice tasks

1. Write (do not generate) a Pod `redis` with image `redis:7.4` and label
   `app=cache`. Apply it. Run `redis-cli ping` inside it.
2. Make a Pod with two containers: `nginx:1.27` and `busybox:1.36` running
   `sleep 3600`. From busybox, run `wget -qO- localhost`. Why does it
   work?
3. Add an init container that sleeps 20 seconds. Watch the Pod status.
4. Create a Pod with restartPolicy `OnFailure` that runs `exit 0`. What
   is its final phase?
5. Use `kubectl explain` to find the default `terminationGracePeriodSeconds`.

---

## 9. Quiz

1. What do containers in the same Pod share?
2. In which order do init containers run, and when do app containers
   start?
3. What makes an init container a "native sidecar"?
4. What are the 3 values of restartPolicy, and which is the default?
5. If you delete a Pod you created with `kubectl apply -f pod.yaml`,
   does Kubernetes recreate it? Why?

<details><summary>Quiz answers</summary>

1. The network (same IP, localhost), and volumes if they mount them.
   They also always run on the same node.
2. One by one, in the order written. App containers start only after
   ALL init containers finished successfully (native sidecars only
   need to be started).
3. Setting `restartPolicy: Always` on the init container.
4. `Always` (default), `OnFailure`, `Never`.
5. No. A bare Pod has no controller to recreate it. Use a ReplicaSet
   or Deployment for self-healing.

</details>

---

## 10. Next topic

[Topic 05: Labels, selectors, annotations](../labels_selectors/labels_selectors.md)

---

**Previous:** [Topic 03: Setup Minikube & kubectl](../kubernetes_install/kubernetes_install.md) | **Next:** [Topic 05: Labels, selectors, annotations](../labels_selectors/labels_selectors.md) | [Back to README](../README.md)
