# Topic 02: Kubernetes Architecture

| | |
|---|---|
| **Level** | Beginner |
| **Time** | ~45 min |
| **Prereqs** | [Topic 01: Containers & Docker basics](../docker_basics/docker_basics.md) |
| **Files** | [`kubernetes-cluster-architecture.svg`](kubernetes-cluster-architecture.svg) |

> Run all commands from the repo root.

---

## 1. What is it?

Kubernetes (K8s) is a **container orchestrator**. It runs and manages many
containers on many machines for you. It automates the deployment, scaling,
and management of containerized applications.

A Kubernetes **cluster** has two kinds of parts:

- **Control plane**: the "brain". It makes decisions and stores state.
- **Worker nodes**: the "muscles". They run your containers (in Pods).

You tell Kubernetes WHAT you want (desired state), for example "3 copies
of nginx". Kubernetes works all the time to make the real state match.

---

## 2. Why do we need it?

Running 1 container with Docker is easy. Running 500 containers on 20
servers is hard. You need answers to:

- Which server has free CPU and memory?
- What happens when a container or a server dies?
- How do containers find each other?
- How do I update the app with no downtime?
- How do I scale up when traffic grows?

Kubernetes answers all of these automatically:

| Feature | What it does |
|---------|--------------|
| Scheduling | Picks a good node for each Pod |
| Self-healing | Restarts or replaces failed Pods |
| Service discovery and load balancing | Stable names/IPs, traffic spread across Pods |
| Rolling updates and rollbacks | Update with no downtime, undo bad releases |
| Scaling | Manual and automatic |
| Config and secret management | Settings and passwords outside the image |

---

## 3. Key concepts

### Architecture diagram

![Kubernetes cluster architecture](kubernetes-cluster-architecture.svg)

Simple text picture:

```text
+--------------------------- CONTROL PLANE ---------------------------+
|                                                                     |
|  kube-apiserver  <---->  etcd                                       |
|       ^   ^                                                         |
|       |   +---- kube-scheduler                                      |
|       +-------- kube-controller-manager                             |
|       +-------- cloud-controller-manager (only in clouds)           |
+-------|-------------------------------------------------------------+
        |  (all talk goes through the API server)
+-------v------------ WORKER NODE ------------------------------------+
|  kubelet  --->  container runtime (containerd / CRI-O)              |
|  kube-proxy (Service networking)                                    |
|  [ Pod ] [ Pod ] [ Pod ]                                            |
+---------------------------------------------------------------------+
```

### Control plane components

**kube-apiserver**
The front door of the cluster. Every request (from kubectl, from
other components) goes through it. It checks auth, validates objects,
and saves them to etcd. It is the ONLY component that talks to etcd.

**etcd**
A distributed key-value database. It stores ALL cluster state
(configuration, state, metadata). If you lose etcd with no backup, you
lose the cluster config. Back it up!

**kube-scheduler**
Watches for new Pods with no node. Picks the best node based on
resources, rules (affinity, taints, tolerations) and more. It only
decides. The kubelet does the real start.

**kube-controller-manager**
Runs many **controllers**. Each controller is a loop:
"look at desired state -> look at real state -> fix the difference".
Examples: ReplicaSet controller, Deployment controller, Node
controller, Job controller, EndpointSlice controller.

**cloud-controller-manager**
Talks to the cloud provider (AWS, GCP, Azure) to create load
balancers, routes, etc. Not used on Minikube.

### Worker node components

**kubelet**
An agent on every node. It gets Pod specs from the API server and
tells the container runtime to start the containers. It reports
node and Pod status. It also runs health probes.

**Container runtime**
Actually runs containers (containerd, CRI-O). Talks to kubelet via CRI.

**kube-proxy**
Makes Services work. It programs network rules (iptables or IPVS) so
that traffic to a Service IP reaches a healthy Pod.

### Add-ons (run as Pods)

| Add-on | Purpose |
|--------|---------|
| CoreDNS | DNS names for Services (`my-svc.my-ns.svc.cluster.local`) |
| CNI plugin | Pod networking (Calico, Cilium, Flannel, kindnet...) |
| metrics-server | CPU/memory numbers for `kubectl top` and HPA |
| Others | Ingress controller, dashboard, monitoring/logging tools (metrics, logs, traces) |

### Components at a glance

| Component | Runs on | Role |
|-----------|---------|------|
| kube-apiserver | Control plane | Front door; validates requests, stores state in etcd |
| etcd | Control plane | Key-value store for all cluster data |
| kube-scheduler | Control plane | Assigns new Pods to nodes |
| kube-controller-manager | Control plane | Runs reconciliation loops (controllers) |
| cloud-controller-manager | Control plane (cloud only) | Load balancers, routes, cloud nodes |
| kubelet | Every node | Starts containers in Pods, reports status, runs probes |
| kube-proxy | Every node | Service networking rules |
| Container runtime | Every node | Pulls images and runs containers |

### Desired state and reconciliation

You write YAML (desired state). Controllers keep comparing it with real
state and fix differences. This "control loop" is the heart of K8s.

### What happens when you run `kubectl apply -f deployment.yaml`?

1. kubectl sends the YAML to kube-apiserver.
2. API server checks it and stores the Deployment in etcd.
3. Deployment controller sees it, creates a ReplicaSet.
4. ReplicaSet controller sees it, creates 3 Pod objects (no node yet).
5. Scheduler sees Pods with no node, picks a node for each.
6. kubelet on that node sees a Pod for it, asks the runtime to pull
   the image and start containers.
7. kubelet reports status "Running" back to the API server.

After that, kube-proxy on each node keeps network rules up to date so Pods
and Services can talk inside the cluster, and Services / Ingress let
external users reach them.

### Minikube

Minikube runs the control plane AND the worker on ONE node (a VM or
a Docker container). Great for learning. Not for production.

---

## 4. Example YAML

Every Kubernetes object has the same 4 top-level parts:

```yaml
apiVersion: apps/v1          # API group + version of this object type
kind: Deployment             # object type
metadata:                    # identity: name, namespace, labels
  name: nginx-deployment
  labels:
    app: nginx
spec:                        # DESIRED state (what you want)
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx-container
        image: nginx:1.27    # pinned tag

# "status:" is the 5th part. Kubernetes writes it (REAL state).
# You never write status yourself.
```

---

## 5. Hands-on lab

You need Minikube running. If not yet installed, do
[Topic 03: Setup Minikube & kubectl](../kubernetes_install/kubernetes_install.md) first and
come back. (Quick: `minikube start`)

**Step 1. See the node**

```bash
kubectl get nodes -o wide
```

You should see: one node `minikube`, STATUS `Ready`, ROLES `control-plane`.

**Step 2. See the control plane Pods**

```bash
kubectl get pods -n kube-system
```

You should see (names may have suffixes):

```text
etcd-minikube
kube-apiserver-minikube
kube-controller-manager-minikube
kube-scheduler-minikube
kube-proxy-xxxxx
coredns-xxxxx
storage-provisioner
```

**Step 3. Look at one component**

```bash
kubectl describe pod -n kube-system kube-apiserver-minikube
```

Look at `Command:` to see its flags (for example `--etcd-servers`).

**Step 4. Check component health**

```bash
kubectl get --raw='/readyz?verbose'
```

You should see many lines with `ok` and `readyz check passed`.

**Step 5. Find the kubelet** (it is NOT a Pod; it is a system service)

```bash
minikube ssh
  sudo systemctl status kubelet
  exit
```

**Step 6. Watch reconciliation (self-healing)**

```bash
kubectl create deployment demo --image=nginx:1.27 --replicas=2
kubectl get pods -l app=demo
kubectl delete pod -l app=demo --wait=false
kubectl get pods -l app=demo -w
```

You should see: old Pods `Terminating`, new Pods created right away.
Press Ctrl+C to stop watching.

**Step 7. See events (what controllers did)**

```bash
kubectl get events --sort-by=.lastTimestamp | tail -20
```

**Step 8. Clean up**

```bash
kubectl delete deployment demo
```

---

## 6. Common mistakes & troubleshooting

| Mistake / Problem | Explanation / Fix |
|-------------------|-------------------|
| Thinking the scheduler starts containers | No. Scheduler only picks a node. kubelet starts containers. |
| Thinking kubectl talks to nodes directly | No. kubectl talks only to the API server. |
| Looking for kubelet in `kubectl get pods` | kubelet is a system service on the node, not a Pod. |
| `The connection to the server localhost:8080 was refused` | kubectl has no config / cluster is down. Run `minikube start` and check `kubectl config current-context`. |
| Node `NotReady` | Often a CNI or kubelet problem. Check `kubectl describe node minikube` and look at "Conditions". On Minikube, `minikube delete` and `minikube start` is a quick reset. |
| Pods stuck `Pending` | Scheduler cannot find a node (not enough CPU/memory, or a rule blocks it). Check `kubectl describe pod <name>` -> Events. |

---

## 7. Cheat sheet

| Command | What it does |
|---------|--------------|
| `kubectl cluster-info` | API server and CoreDNS address |
| `kubectl get nodes -o wide` | List nodes with IP, OS, runtime |
| `kubectl describe node <node>` | Capacity, conditions, Pods |
| `kubectl get pods -n kube-system` | System components |
| `kubectl get --raw='/readyz?verbose'` | API server health checks |
| `kubectl api-resources` | All object types + short names |
| `kubectl api-versions` | All API groups/versions |
| `kubectl get events -A` | Recent events in all namespaces |
| `minikube ssh` | Shell into the Minikube node |

---

## 8. Practice tasks

1. Draw the architecture on paper from memory. Label all 7 main parts.
2. Use `kubectl api-resources` to find the short name of
   `deployments`, `services` and `persistentvolumeclaims`.
3. Find which container runtime Minikube uses
   (hint: `kubectl get nodes -o wide`, column `CONTAINER-RUNTIME`).
4. Find the etcd data directory (hint: describe the etcd Pod, look for
   `--data-dir`).
5. Explain in 5 lines what happens when you run `kubectl delete pod X`
   for a Pod owned by a ReplicaSet.

---

## 9. Quiz

1. Which component is the only one that talks directly to etcd?
2. Which component picks the node for a new Pod?
3. Which component runs on every node and starts containers?
4. What is a "controller" in Kubernetes?
5. What does kube-proxy do?

<details><summary>Quiz answers</summary>

1. kube-apiserver.
2. kube-scheduler.
3. kubelet (it uses the container runtime to do it).
4. A loop that watches desired state and real state and acts to make
   them equal (reconciliation).
5. It programs network rules on each node so Service IPs forward
   traffic to the right Pods.

</details>

---

## 10. Next topic

[Topic 03: Setup Minikube & kubectl](../kubernetes_install/kubernetes_install.md)

---

**Previous:** [Topic 01: Containers & Docker basics](../docker_basics/docker_basics.md) | **Next:** [Topic 03: Setup Minikube & kubectl](../kubernetes_install/kubernetes_install.md) | [Back to README](../README.md)
