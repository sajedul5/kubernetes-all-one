# Topic 03: Setup Minikube and kubectl

| | |
|---|---|
| **Level** | Beginner |
| **Time** | ~60 min |
| **Prereqs** | [Topic 01: Containers & Docker basics](../docker_basics/docker_basics.md), [Topic 02: Kubernetes architecture](../kubernetes_architecture/kubernetes_architecture.md) |
| **Files** | [Manual install guide (Ubuntu)](docker-minikube-install.md), [`install-minikube-ubuntu.sh`](../scripts/install-minikube-ubuntu.sh), [`install-minikube-macos.sh`](../scripts/install-minikube-macos.sh), [`install-minikube-windows.ps1`](../scripts/install-minikube-windows.ps1) |

> Run all commands from the repo root.

---

## 1. What is it?

**Minikube** is a tool that creates a small Kubernetes cluster on your
laptop. It runs inside Docker (most common) or inside a VM.

**kubectl** ("kube-control" or "kube-C-T-L") is the command-line tool to talk
to ANY Kubernetes cluster. It sends requests to the kube-apiserver.

**kubeconfig** is a file (default: `~/.kube/config`) that tells kubectl which
clusters exist, which user to use, and how to log in.

---

## 2. Why do we need it?

- You need a cluster to practice. Cloud clusters cost money. Minikube
  is free and runs locally.
- You need kubectl for everything in this course, and at work.
- In real jobs you often have many clusters (dev, staging, prod).
  Contexts in kubeconfig let you switch safely between them.

---

## 3. Key concepts

**Minikube driver**
How Minikube creates the node: `docker` (default, recommended), `podman`,
`hyperkit`/`vfkit` (macOS), `hyperv` (Windows), `kvm2` (Linux), `virtualbox`.

**Kubeconfig structure**

| Section | Contents |
|---------|----------|
| `clusters` | name + API server URL + CA certificate |
| `users` | name + credentials (cert, token...) |
| `contexts` | a pair (cluster + user + default namespace) with a name |
| `current-context` | which context kubectl uses now |

**Context**
`minikube start` creates a context named `minikube` and makes it
current. Always check the context before you run commands!

**kubectl command shape**

```text
kubectl <verb> <resource> [name] [flags]
```

Examples:

```bash
kubectl get pods
kubectl describe deployment nginx-deployment
kubectl delete service nginx-service -n nginx
```

**Imperative vs declarative**

| Style | Commands | Good for |
|-------|----------|----------|
| Imperative | `kubectl run / create / scale / set` | Quick, one-off |
| Declarative | `kubectl apply -f file.yaml` | Repeatable, Git |

Use imperative to LEARN and to GENERATE YAML. Use declarative for
real work.

**Output formats (`-o`)**

| Flag | Output |
|------|--------|
| `-o wide` | More columns |
| `-o yaml` | Full object as YAML |
| `-o json` | Full object as JSON |
| `-o name` | Only `kind/name` |
| `-o jsonpath='{.spec.replicas}'` | One field |

**kubectl explain**
Built-in docs for every field. Works offline against your cluster's
real API version. Example:

```bash
kubectl explain pod.spec.containers.ports
kubectl explain deployment.spec.strategy --recursive
```

**Dry-run to generate YAML**
`--dry-run=client -o yaml` prints the YAML but creates NOTHING.
This is the fastest way to write correct YAML.

```bash
kubectl create deployment web --image=nginx:1.27 --replicas=3 \
  --dry-run=client -o yaml > web-deploy.yaml
```

`--dry-run=server` asks the API server to validate without saving.

**Version skew**
kubectl should be within one minor version of the cluster (for
example kubectl 1.31 with cluster 1.30, 1.31 or 1.32).
Trick: `minikube kubectl -- get pods` uses a matching kubectl.

---

## 4. Example YAML

A simplified `~/.kube/config` after `minikube start`:

```yaml
apiVersion: v1
kind: Config
clusters:
- name: minikube                          # cluster nickname
  cluster:
    server: https://127.0.0.1:52345       # API server URL (port varies)
    certificate-authority: /home/you/.minikube/ca.crt  # trust this CA
users:
- name: minikube                          # user nickname
  user:
    client-certificate: /home/you/.minikube/profiles/minikube/client.crt
    client-key: /home/you/.minikube/profiles/minikube/client.key
contexts:
- name: minikube                          # context = cluster + user
  context:
    cluster: minikube
    user: minikube
    namespace: default                    # default namespace for commands
current-context: minikube                 # the active context
```

YAML generated with dry-run (`kubectl run web --image=nginx:1.27
--port=80 --dry-run=client -o yaml`), cleaned a little:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: web              # kubectl run adds label run=<name>
  name: web
spec:
  containers:
  - image: nginx:1.27     # pinned tag
    name: web
    ports:
    - containerPort: 80
  restartPolicy: Always
```

---

## 5. Hands-on lab

**Step 1. Install**

Run the one-shot script for your OS, or follow the
[manual install guide](docker-minikube-install.md) (Ubuntu, step by step).

| OS | Script | Command |
|----|--------|---------|
| Linux (Ubuntu) | [`install-minikube-ubuntu.sh`](../scripts/install-minikube-ubuntu.sh) | `bash scripts/install-minikube-ubuntu.sh` |
| macOS | [`install-minikube-macos.sh`](../scripts/install-minikube-macos.sh) | `bash scripts/install-minikube-macos.sh` |
| Windows | [`install-minikube-windows.ps1`](../scripts/install-minikube-windows.ps1) | see below |

Windows (in PowerShell as Administrator; `` ` `` continues a line):

```powershell
powershell -ExecutionPolicy Bypass `
  -File scripts\install-minikube-windows.ps1
```

Check:

```bash
docker version
minikube version
kubectl version --client
```

**Step 2. Start the cluster**

```bash
minikube start --driver=docker --cpus=2 --memory=4096
```

You should see: `Done! kubectl is now configured to use "minikube"
cluster and "default" namespace by default`

**Step 3. Check it**

```bash
minikube status
kubectl get nodes
```

You should see: `minikube   Ready   control-plane   ...`

**Step 4. Look at kubeconfig and contexts**

```bash
kubectl config view --minify
kubectl config get-contexts
kubectl config current-context
```

You should see: a `*` next to `minikube`.

**Step 5. Set a default namespace for the context**

```bash
kubectl create namespace dev
kubectl config set-context --current --namespace=dev
kubectl config view --minify | grep namespace
```

You should see: `namespace: dev`. Change it back:

```bash
kubectl config set-context --current --namespace=default
```

**Step 6. Use kubectl explain**

```bash
kubectl explain pod
kubectl explain pod.spec.restartPolicy
```

You should see: a description and allowed values (`Always`, `OnFailure`,
`Never`).

**Step 7. Generate YAML with dry-run**

```bash
kubectl create deployment web --image=nginx:1.27 --replicas=2 \
  --dry-run=client -o yaml > web.yaml
cat web.yaml
kubectl apply -f web.yaml
kubectl get deploy,rs,pods
```

You should see: 1 deployment, 1 replicaset, 2 pods.

**Step 8. Other useful generators**

```bash
kubectl expose deployment web --port=80 --dry-run=client -o yaml
kubectl create configmap app-cfg --from-literal=color=blue \
  --dry-run=client -o yaml
kubectl create job hello --image=busybox:1.36 --dry-run=client -o yaml \
  -- echo hi
```

**Step 9. Try Minikube extras**

```bash
minikube addons list
minikube addons enable metrics-server
minikube dashboard --url
minikube ip
minikube ssh -- docker ps    # or: minikube ssh -- sudo crictl ps
```

**Step 10. Clean up**

```bash
kubectl delete -f web.yaml
kubectl delete namespace dev
```

**Shell autocompletion (strongly recommended)**

```bash
# bash
source <(kubectl completion bash)
# zsh
source <(kubectl completion zsh)

alias k=kubectl
# and for bash:
complete -o default -F __start_kubectl k
```

---

## 6. Common mistakes & troubleshooting

| Problem | Fix |
|---------|-----|
| `minikube start` fails with driver error | Make sure Docker is running (`docker ps` works without sudo). Or pick a driver: `minikube start --driver=docker` |
| Not enough memory | Give more: `minikube start --memory=4096 --cpus=2`. Changing resources needs: `minikube delete && minikube start ...` |
| Wrong cluster! You ran a command on prod by accident | Always check: `kubectl config current-context`. Tip: show the context in your shell prompt (kube-ps1 tool). |
| `error: You must be logged in to the server (Unauthorized)` | Old/expired credentials. For Minikube: `minikube update-context` |
| kubectl and cluster version too far apart | Use: `minikube kubectl -- <command>` |
| Very strange cluster state | Reset fast: `minikube delete && minikube start` |
| Mistake: saving dry-run YAML and never reading it | Always open and read generated YAML. Remove `creationTimestamp: null` and empty `status: {}` lines; they are noise. |

---

## 7. Cheat sheet

### Minikube

| Command | What it does |
|---------|--------------|
| `minikube start` | Create/start cluster |
| `minikube stop` | Stop cluster, keep data |
| `minikube delete` | Delete cluster |
| `minikube status` | Health of cluster parts |
| `minikube ip` | Node IP |
| `minikube ssh` | Shell on the node |
| `minikube dashboard` | Open web UI |
| `minikube addons list` / `enable <x>` | Manage add-ons |
| `minikube image load <img>` | Copy local image into cluster |
| `minikube profile list` | List Minikube clusters |

### kubectl

| Command | What it does |
|---------|--------------|
| `kubectl config get-contexts` | List contexts |
| `kubectl config current-context` | Show active context |
| `kubectl config use-context <name>` | Switch context |
| `kubectl config set-context --current --namespace=<ns>` | Change default namespace |
| `kubectl get <res> [-A] [-o wide]` | List objects |
| `kubectl describe <res> <name>` | Details + events |
| `kubectl apply -f <file\|dir>` | Create/update from YAML |
| `kubectl delete -f <file>` | Delete objects in YAML |
| `kubectl explain <res.field>` | Field docs |
| `kubectl <cmd> --dry-run=client -o yaml` | Print YAML, create nothing |
| `kubectl diff -f <file>` | Preview changes before apply |
| `kubectl api-resources` | All types and short names |

---

## 8. Practice tasks

1. Start a second Minikube cluster: `minikube start -p lab2`. List
   contexts. Switch between `minikube` and `lab2`. Delete `lab2`.
2. Use dry-run to generate YAML for a Pod `cache` with image
   `redis:7.4`. Save it as `cache.yaml` and apply it.
3. Use `kubectl explain` to find the field that sets how many old
   ReplicaSets a Deployment keeps.
4. Print only the image of your `cache` Pod using `-o jsonpath`.
5. Set default namespace to `kube-system`, run `kubectl get pods`, then
   set it back to `default`.

---

## 9. Quiz

1. What is the default path of the kubeconfig file?
2. A context is made of which three things?
3. What does `--dry-run=client -o yaml` do?
4. Which command shows docs for `spec.replicas` of a Deployment?
5. What is the difference between `minikube stop` and `minikube delete`?

<details><summary>Quiz answers</summary>

1. `~/.kube/config` (you can change it with the `KUBECONFIG` env variable).
2. A cluster, a user, and (optionally) a default namespace.
3. It prints the object as YAML without creating it in the cluster.
4. `kubectl explain deployment.spec.replicas`
5. `stop` turns the cluster off but keeps it. `delete` removes the
   cluster and all its data.

(Answer for practice task 3: `spec.revisionHistoryLimit`)

</details>

---

## 10. Next topic

[Topic 04: Pods](../pod/pod.md)

---

**Previous:** [Topic 02: Kubernetes architecture](../kubernetes_architecture/kubernetes_architecture.md) | **Next:** [Topic 04: Pods](../pod/pod.md) | [Back to README](../README.md)
