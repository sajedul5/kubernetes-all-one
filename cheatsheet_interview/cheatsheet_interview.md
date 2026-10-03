# Topic 24: Cheat Sheet & Interview Questions

| | |
|---|---|
| **Level** | All |
| **Time** | ~60 min (read once, come back before exams and interviews) |
| **Prereqs** | All previous topics ([Containers & Docker Basics](../docker_basics/docker_basics.md) through [Load Testing with k6](../load_testing/load_testing.md)) - this file is a review of the whole path. See the [Roadmap](../roadmap/roadmap.md). |
| **Files** | all folders ([deployments/](../deployments/deployments.md), [services/](../services/services.md), [ingress/](../ingress/ingress.md), [volumes/](../volumes/volumes.md), [statefulset/](../statefulset/statefulset.md), [load_testing/](../load_testing/load_testing.md), `scripts/`) |

> Run all commands from the repo root.

**Parts of this file**

- [A. kubectl cheat sheet](#a-kubectl-cheat-sheet) (grouped by category)
- [B. Interview questions & answers](#b-interview-questions--answers) (basic -> advanced)
- [C. What to learn next](#c-what-to-learn-next)
- [D. End - congratulations](#d-end---congratulations)

---

## A. kubectl cheat sheet

Tip: add these to your shell profile (`~/.bashrc` or `~/.zshrc`):

```bash
alias k=kubectl
source <(kubectl completion bash)     # or: kubectl completion zsh
complete -o default -F __start_kubectl k   # bash: completion for "k"
export do="--dry-run=client -o yaml"  # k create deploy x --image=y $do
```

### A1. Cluster & context

| Command | Purpose |
|---|---|
| `kubectl version` | client and server versions |
| `kubectl cluster-info` | API server address |
| `kubectl get nodes -o wide` | nodes, IPs, OS, runtime |
| `kubectl config get-contexts` | list clusters/contexts |
| `kubectl config use-context <ctx>` | switch cluster |
| `kubectl config set-context --current --namespace=<ns>` | change default namespace |
| `kubectl api-resources` | all object kinds + short names |
| `kubectl api-versions` | all API groups/versions |
| `kubectl explain deploy.spec.strategy` | field docs (no internet) |
| `kubectl explain pod --recursive \| less` | all fields of a Pod |

### A2. Minikube

| Command | Purpose |
|---|---|
| `minikube start --cpus=4 --memory=6144` | start a cluster |
| `minikube start -p <name> --nodes 3` | extra multi-node profile |
| `minikube start --cni=calico` | with NetworkPolicy support |
| `minikube status` / `stop` / `delete` | manage cluster |
| `minikube addons list` | addons |
| `minikube addons enable ingress` | ingress controller |
| `minikube addons enable metrics-server` | `kubectl top` + HPA |
| `minikube service <svc> --url` | URL of a NodePort Service |
| `minikube tunnel` | LoadBalancer/ingress access |
| `minikube ssh` | shell on the node |
| `minikube dashboard` | web UI |

Install scripts: [scripts/install-minikube-ubuntu.sh](../scripts/install-minikube-ubuntu.sh), [scripts/install-minikube-macos.sh](../scripts/install-minikube-macos.sh), [scripts/install-minikube-windows.ps1](../scripts/install-minikube-windows.ps1)

### A3. Create & apply

| Command | Purpose |
|---|---|
| `kubectl apply -f file.yaml` | create/update (declarative) |
| `kubectl apply -f deployments/` | apply a whole folder |
| `kubectl apply -k <dir>` | apply with Kustomize |
| `kubectl diff -f file.yaml` | show changes before apply |
| `kubectl delete -f file.yaml` | delete what the file made |
| `kubectl run nginx --image=nginx:1.27.2` | quick Pod |
| `kubectl create deploy web --image=nginx:1.27.2 --replicas=3` | quick Deployment |
| `kubectl create deploy web --image=nginx:1.27.2 --dry-run=client -o yaml > web.yaml` | generate YAML fast |
| `kubectl expose deploy web --port=8080 --target-port=80` | Service for a Deployment |
| `kubectl create job hello --image=busybox:1.36 -- echo hi` | quick Job |
| `kubectl create cronjob tick --image=busybox:1.36 --schedule="*/5 * * * *" -- date` | quick CronJob |

### A4. View & find

| Command | Purpose |
|---|---|
| `kubectl get pods` | Pods in current namespace |
| `kubectl get pods -A` | all namespaces |
| `kubectl get pods -o wide` | + node and IP |
| `kubectl get pods --show-labels` | + labels |
| `kubectl get pods -l app=nginx` | filter by label |
| `kubectl get pods --field-selector status.phase=Pending` | filter by field |
| `kubectl get all -n <ns>` | common objects in ns |
| `kubectl get deploy web -o yaml` | full object |
| `kubectl get pods -o jsonpath='{.items[*].metadata.name}'` | only names |
| `kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName` | your own columns |
| `kubectl get pods --sort-by=.metadata.creationTimestamp` | sort by age |
| `kubectl get pods -w` | watch changes live |
| `kubectl describe <kind> <name>` | details + events |

### A5. Edit & change

| Command | Purpose |
|---|---|
| `kubectl edit deploy web` | edit live in an editor |
| `kubectl scale deploy web --replicas=5` | change replicas |
| `kubectl set image deploy/web nginx=nginx:1.27.3` | new image |
| `kubectl set env deploy/web MODE=prod` | add env variable |
| `kubectl set resources deploy/web --requests=cpu=100m,memory=64Mi` | set requests |
| `kubectl label pod <p> tier=web` | add label |
| `kubectl label pod <p> tier-` | remove label |
| `kubectl annotate deploy web note="hi"` | add annotation |
| `kubectl patch deploy web -p '{"spec":{"replicas":2}}'` | patch a field |
| `kubectl replace --force -f pod.yaml` | delete + create again |

### A6. Rollouts

| Command | Purpose |
|---|---|
| `kubectl rollout status deploy/web` | wait for rollout |
| `kubectl rollout history deploy/web` | revisions |
| `kubectl rollout undo deploy/web` | previous revision |
| `kubectl rollout undo deploy/web --to-revision=2` | a specific revision |
| `kubectl rollout restart deploy/web` | restart all Pods |
| `kubectl rollout pause deploy/web` / `resume` | pause / resume a rollout |

### A7. Logs & debug

| Command | Purpose |
|---|---|
| `kubectl logs <pod>` | logs |
| `kubectl logs <pod> -c <container>` | one container |
| `kubectl logs <pod> --previous` | crashed container |
| `kubectl logs -f -l app=nginx --prefix` | follow by label |
| `kubectl exec -it <pod> -- sh` | shell in container |
| `kubectl debug -it <pod> --image=busybox:1.36 --target=<c>` | ephemeral debug container |
| `kubectl debug node/<node> -it --image=busybox:1.36` | debug a node |
| `kubectl get events --sort-by=.lastTimestamp` | events in time order |
| `kubectl events --for pod/<pod>` | events of one object |
| `kubectl top nodes` / `kubectl top pods` | CPU and memory |
| `kubectl port-forward svc/nginx-service 8080:8080` | reach a Service locally |
| `kubectl cp <pod>:/etc/nginx/nginx.conf ./nginx.conf` | copy a file out of a Pod |

### A8. Networking

| Command | Purpose |
|---|---|
| `kubectl get svc,endpointslices` | Services and backends |
| `kubectl get ingress` | Ingress rules |
| `kubectl get netpol -A` | NetworkPolicies |
| `kubectl run t --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- -T 3 http://nginx-service:8080` | test HTTP from inside |
| `kubectl run t --rm -it --image=busybox:1.36 --restart=Never -- nslookup nginx-service.default.svc.cluster.local` | test DNS from inside |

### A9. Config & storage

| Command | Purpose |
|---|---|
| `kubectl create configmap cfg --from-literal=k=v --from-file=app.conf` | ConfigMap |
| `kubectl create secret generic db --from-literal=password=s3cret` | Secret |
| `kubectl get secret db -o jsonpath='{.data.password}' \| base64 -d` | read a Secret value |
| `kubectl get pv,pvc,storageclass` | storage objects |
| `kubectl describe pvc <pvc>` | why is it Pending? |

### A10. Scheduling & nodes

| Command | Purpose |
|---|---|
| `kubectl cordon <node>` / `kubectl uncordon <node>` | stop / allow new Pods |
| `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data` | evict Pods safely |
| `kubectl taint nodes <node> key=val:NoSchedule` | add taint |
| `kubectl taint nodes <node> key=val:NoSchedule-` | remove taint |
| `kubectl label node <node> disk=ssd` | for nodeSelector |
| `kubectl get pdb` | disruption budgets |

### A11. Security

| Command | Purpose |
|---|---|
| `kubectl auth whoami` | who am I |
| `kubectl auth can-i create deploy -n dev` | check permission |
| `kubectl auth can-i --list --as=system:serviceaccount:dev:app-sa -n dev` | all rights of a ServiceAccount |
| `kubectl create sa app-sa` | ServiceAccount |
| `kubectl create token app-sa` | short-lived token |
| `kubectl create role r --verb=get,list --resource=pods` | Role |
| `kubectl create rolebinding rb --role=r --serviceaccount=default:app-sa` | RoleBinding |
| `kubectl label ns dev pod-security.kubernetes.io/enforce=restricted` | Pod Security Admission |

### A12. Autoscaling

| Command | Purpose |
|---|---|
| `kubectl autoscale deploy web --cpu-percent=50 --min=2 --max=10` | create HPA |
| `kubectl get hpa -w` | watch the HPA |
| `kubectl describe hpa web` | scaling events |

### A13. Helm ([Helm](../helm/helm.md))

```bash
helm repo add <n> <url> ; helm repo update
helm upgrade --install <rel> <chart> -n <ns> --create-namespace \
  -f values.yaml
helm list -A ; helm history <rel> ; helm rollback <rel> <rev>
helm template <rel> <chart> ; helm uninstall <rel>
```

### A14. Load testing ([Load Testing with k6](../load_testing/load_testing.md))

```bash
bash scripts/install-k6-ubuntu.sh       # install k6 (also install-k6-macos.sh, install-k6-windows.ps1)
kubectl port-forward svc/nginx-service 8080:8080
k6 run load_testing/k6-nginx-test.js
BASE_URL=http://host:port k6 run load_testing/k6-nginx-test.js
```

### A15. Short names

| Short | Resource | Short | Resource |
|---|---|---|---|
| `po` | pods | `cm` | configmaps |
| `deploy` | deployments | `ns` | namespaces |
| `rs` | replicasets | `no` | nodes |
| `sts` | statefulsets | `pv` / `pvc` | persistentvolumes / persistentvolumeclaims |
| `ds` | daemonsets | `sc` | storageclasses |
| `svc` | services | `sa` | serviceaccounts |
| `ep` | endpoints | `netpol` | networkpolicies |
| `ing` | ingresses | `hpa` | horizontalpodautoscalers |
| `cj` | cronjobs | `pdb` | poddisruptionbudgets |
| `crd` | customresourcedefinitions | | |

---

## B. Interview questions & answers

Click a question to show its answer.

### Basic

<details>
<summary><b>Q1. What is Kubernetes?</b></summary>

An open-source system that runs and manages containers on many machines. It schedules containers, restarts them, scales them, and gives them networking and storage. You describe the wanted state in YAML; Kubernetes keeps the real state equal to it.

</details>

<details>
<summary><b>Q2. What is the difference between a container and a Pod?</b></summary>

A Pod is the smallest unit in Kubernetes. It wraps one or more containers that share the same network (IP, ports) and can share volumes. Kubernetes manages Pods, not single containers.

</details>

<details>
<summary><b>Q3. Name the control plane components.</b></summary>

kube-apiserver (front door, REST API), etcd (key-value store for all cluster data), kube-scheduler (picks a node for new Pods), kube-controller-manager (runs controllers like Deployment and Node controllers), and cloud-controller-manager (cloud integration).

</details>

<details>
<summary><b>Q4. What runs on every worker node?</b></summary>

kubelet (starts Pods, reports status), a container runtime (containerd or CRI-O), and kube-proxy (Service networking rules; some CNIs like Cilium can replace it).

</details>

<details>
<summary><b>Q5. What is a Deployment?</b></summary>

An object that manages ReplicaSets, which manage Pods. It gives rolling updates, rollbacks and scaling for stateless apps.

</details>

<details>
<summary><b>Q6. Why not create Pods directly?</b></summary>

A bare Pod is not recreated if it dies or its node fails. A Deployment (or other controller) replaces failed Pods automatically.

</details>

<details>
<summary><b>Q7. What is a Service and why do we need it?</b></summary>

Pod IPs change when Pods are replaced. A Service gives a stable virtual IP and DNS name and load-balances to Pods selected by labels.

</details>

<details>
<summary><b>Q8. Name the Service types.</b></summary>

ClusterIP (inside the cluster, default), NodePort (a port on every node, 30000-32767), LoadBalancer (cloud load balancer), ExternalName (DNS alias). Headless (`clusterIP: None`) gives Pod IPs directly.

</details>

<details>
<summary><b>Q9. What are labels and selectors?</b></summary>

Labels are key/value tags on objects (`app=nginx`). Selectors find objects by labels. Services, Deployments and NetworkPolicies use selectors to find their Pods.

</details>

<details>
<summary><b>Q10. What is a namespace?</b></summary>

A virtual folder inside a cluster that groups objects, scopes names, RBAC and quotas. It is not a network boundary by default.

</details>

<details>
<summary><b>Q11. ConfigMap vs Secret?</b></summary>

Both hold configuration as key/value data. Secrets are for sensitive data; they are only base64-encoded by default, so enable encryption at rest and restrict RBAC. Both can be env variables or mounted files.

</details>

<details>
<summary><b>Q12. What does <code>kubectl apply</code> do compared with <code>kubectl create</code>?</b></summary>

`create` makes a new object and fails if it exists (imperative). `apply` creates or updates to match the file (declarative) and is the normal way with Git.

</details>

### Intermediate

<details>
<summary><b>Q13. How does a rolling update work?</b></summary>

The Deployment creates a new ReplicaSet and slowly scales it up while scaling the old one down, limited by `maxSurge` and `maxUnavailable`. Readiness probes decide when a new Pod counts as available. `kubectl rollout undo` goes back.

</details>

<details>
<summary><b>Q14. Liveness vs readiness vs startup probe?</b></summary>

Liveness: if it fails, kubelet restarts the container. Readiness: if it fails, the Pod is removed from Service endpoints (no restart). Startup: runs first for slow apps; the other probes wait until it succeeds.

</details>

<details>
<summary><b>Q15. Requests vs limits?</b></summary>

Requests are what the scheduler reserves for the container and the base for HPA percentages. Limits are the maximum. Over the CPU limit the container is throttled; over the memory limit it is OOMKilled.

</details>

<details>
<summary><b>Q16. What are QoS classes?</b></summary>

Guaranteed (requests = limits for all containers), Burstable (some requests/limits set), BestEffort (none). Under memory pressure BestEffort Pods are evicted first, Guaranteed last.

</details>

<details>
<summary><b>Q17. StatefulSet vs Deployment?</b></summary>

StatefulSet gives each Pod a stable name (mongo-0, mongo-1), stable DNS via a headless Service, its own PVC (volumeClaimTemplates), and ordered start/stop. Used for databases (see [statefulset/](../statefulset/statefulset.md) in this repo). Deployments are for stateless, interchangeable Pods.

</details>

<details>
<summary><b>Q18. What is a DaemonSet? Give an example.</b></summary>

It runs one Pod on every (or selected) node. Examples: log agents (Fluent Bit), node-exporter, CNI agents like calico-node.

</details>

<details>
<summary><b>Q19. Job vs CronJob?</b></summary>

A Job runs Pods until a task completes successfully. A CronJob creates Jobs on a schedule (cron format).

</details>

<details>
<summary><b>Q20. Explain PV, PVC and StorageClass.</b></summary>

PV is a piece of storage in the cluster. PVC is a request for storage by a user/Pod. StorageClass describes a type of storage and lets PVs be created automatically (dynamic provisioning) when a PVC asks for it.

</details>

<details>
<summary><b>Q21. What are access modes?</b></summary>

ReadWriteOnce (one node read-write), ReadOnlyMany (many nodes read), ReadWriteMany (many nodes read-write), ReadWriteOncePod (one Pod only).

</details>

<details>
<summary><b>Q22. What is an Ingress? What is an Ingress controller?</b></summary>

Ingress is a set of HTTP/HTTPS routing rules (host and path -> Service). The Ingress controller (e.g. NGINX, Traefik, HAProxy) is the actual proxy that reads these rules. Without a controller, Ingress objects do nothing. Gateway API is the newer successor.

</details>

<details>
<summary><b>Q23. How does Service discovery work?</b></summary>

CoreDNS creates DNS records for Services: `<svc>.<namespace>.svc.cluster.local`. Pods use these names. kube-proxy (iptables/IPVS/nftables) or the CNI forwards the virtual IP to Pods.

</details>

<details>
<summary><b>Q24. What is the HPA and what does it need?</b></summary>

HorizontalPodAutoscaler changes the replica count based on metrics (CPU, memory, custom). It needs metrics-server (or another metrics API) and resource requests on the containers.

</details>

<details>
<summary><b>Q25. Taints/tolerations vs node affinity?</b></summary>

Taints on a node REPEL Pods that do not tolerate them. Node affinity ATTRACTS Pods to nodes with certain labels. Use both to dedicate nodes to some workloads.

</details>

<details>
<summary><b>Q26. What is an init container?</b></summary>

A container that runs to completion before the app containers start. Used to wait for a dependency, run migrations, or prepare files. Sidecar containers (`restartPolicy: Always` in initContainers) keep running next to the app.

</details>

<details>
<summary><b>Q27. How do you debug a CrashLoopBackOff?</b></summary>

`kubectl describe pod` (events, exit code, Last State), `kubectl logs --previous`, check command/args, config, env, probes and memory limits. See [Troubleshooting](../troubleshooting/troubleshooting.md).

</details>

<details>
<summary><b>Q28. What does a Pod's "Pending" status usually mean?</b></summary>

The scheduler cannot place it: not enough CPU/memory, taints, node selectors/affinity, unbound PVC, or quota. `describe` shows the reason in events.

</details>

### Advanced

<details>
<summary><b>Q29. What happens when you run <code>kubectl apply -f deploy.yaml</code>?</b></summary>

kubectl sends the object to the API server. It is authenticated, authorized (RBAC), passes admission controllers, and is stored in etcd. The Deployment controller creates a ReplicaSet, the ReplicaSet controller creates Pods, the scheduler assigns nodes, and the kubelet on each node asks the runtime to pull images and start containers. CNI gives the Pod an IP.

</details>

<details>
<summary><b>Q30. Explain RBAC objects.</b></summary>

Role (namespaced rules) and ClusterRole (cluster-wide rules). They are given to users, groups or ServiceAccounts with RoleBinding (one namespace) or ClusterRoleBinding (all namespaces). RBAC only allows; there is no deny.

</details>

<details>
<summary><b>Q31. What is Pod Security Admission?</b></summary>

A built-in admission controller that checks Pods against the Pod Security Standards (privileged, baseline, restricted). It is turned on per namespace with labels and modes enforce, audit, warn.

</details>

<details>
<summary><b>Q32. How do NetworkPolicies work?</b></summary>

They select Pods and allow ingress/egress traffic from/to Pods, namespaces or IP blocks. Once a Pod is selected for a direction, everything not allowed is denied. The CNI must support them (Calico, Cilium).

</details>

<details>
<summary><b>Q33. What is a PodDisruptionBudget?</b></summary>

It limits how many Pods of an app can be down at the same time during voluntary disruptions like node drains and upgrades (`minAvailable` or `maxUnavailable`).

</details>

<details>
<summary><b>Q34. How do you do zero-downtime deployments?</b></summary>

Multiple replicas, readiness probes, rolling update with `maxUnavailable: 0`, graceful shutdown (handle SIGTERM, preStop delay), PDBs, and spread across nodes/zones. For risky changes use canary or blue/green (Argo Rollouts, Flagger, service mesh).

</details>

<details>
<summary><b>Q35. What is etcd and how do you back it up?</b></summary>

A consistent, distributed key-value store that holds all cluster state. Back it up with `etcdctl snapshot save` (self-managed clusters). In managed Kubernetes the provider does it. Velero backs up objects and volumes at the Kubernetes level.

</details>

<details>
<summary><b>Q36. What is a CRD and an Operator?</b></summary>

A CustomResourceDefinition adds a new object kind to the API (e.g. ServiceMonitor). An Operator is a controller that watches those custom objects and runs app-specific logic (install, backup, failover), like a human operator would.

</details>

<details>
<summary><b>Q37. Explain the controller / reconcile loop.</b></summary>

Each controller watches the API for objects, compares desired state (spec) with actual state (status), and acts to remove the difference. It repeats forever. This is why Kubernetes "self-heals".

</details>

<details>
<summary><b>Q38. What is GitOps?</b></summary>

Git is the single source of truth for cluster config. A tool in the cluster (Argo CD, Flux) pulls from Git and applies changes, and fixes drift. Changes and rollbacks happen with pull requests.

</details>

<details>
<summary><b>Q39. Helm vs Kustomize?</b></summary>

Helm uses templates + values, has packaging, versions, repos and release history/rollback. Kustomize patches plain YAML with overlays, no templates, and is built into kubectl (`apply -k`).

</details>

<details>
<summary><b>Q40. How do you secure the supply chain of container images?</b></summary>

Use minimal base images, pin tags or digests, scan in CI (Trivy, Grype), sign images (Sigstore cosign), verify signatures with an admission policy (Kyverno, Gatekeeper), and pull only from trusted private registries.

</details>

<details>
<summary><b>Q41. How do you upgrade a cluster?</b></summary>

Read release notes and fix removed APIs first. Upgrade one minor version at a time: control plane first, then nodes (drain, upgrade, uncordon), respecting PDBs. Test in staging first. On EKS/GKE/AKS the provider handles most steps.

</details>

<details>
<summary><b>Q42. What is the CNI, CSI and CRI?</b></summary>

Plugin interfaces. CNI = Container Network Interface (Pod networking: Calico, Cilium, Flannel). CSI = Container Storage Interface (volume drivers: EBS, GCE PD, Ceph). CRI = Container Runtime Interface (containerd, CRI-O).

</details>

<details>
<summary><b>Q43. Why did Kubernetes remove dockershim?</b></summary>

Kubernetes talks to runtimes through CRI. Docker Engine did not implement CRI, so a shim was needed. It was removed in v1.24. Images built with Docker still work because they are OCI images.

</details>

<details>
<summary><b>Q44. How do you load test an app on Kubernetes and check autoscaling?</b></summary>

Use a tool like k6 ([load_testing/k6-nginx-test.js](../load_testing/k6-nginx-test.js)). Define stages and thresholds (p95 latency, error rate). Run it from inside the cluster (Pod or k6 Operator) so traffic goes through the Service, and watch `kubectl get hpa -w` and Grafana while it runs.

</details>

<details>
<summary><b>Q45. A Service returns 503 through the Ingress. How do you debug?</b></summary>

Check the Service has endpoints (`kubectl get endpointslices`), Pods are Ready, selector and targetPort are correct, the Ingress backend service name/port is right, NetworkPolicies allow the ingress controller, and read the ingress controller logs.

</details>

<details>
<summary><b>Q46. How do you handle secrets safely in Git-based workflows?</b></summary>

Never store plain secrets in Git. Use External Secrets Operator with a vault/cloud secret manager, or Sealed Secrets / SOPS to store only encrypted data. Enable encryption at rest in etcd and limit "get/list secrets" in RBAC.

</details>

---

## C. What to learn next

### 1. Certifications

From the CNCF / Linux Foundation; all are hands-on exams in a real terminal, ~2 hours.

| Exam | What it covers |
|---|---|
| **KCNA** | Kubernetes and Cloud Native Associate. Multiple choice. Good first step if you are new. |
| **CKAD** | Certified Kubernetes Application Developer. Pods, Deployments, config, probes, Services, Helm basics. Topics [Pods](../pod/pod.md) through [Autoscaling (HPA)](../autoscaling_hpa/autoscaling_hpa.md), plus [Helm](../helm/helm.md). |
| **CKA** | Certified Kubernetes Administrator. Cluster install and upgrade (kubeadm), etcd backup, networking, storage, troubleshooting. Topics [Kubernetes Architecture](../kubernetes_architecture/kubernetes_architecture.md), [Storage](../volumes/volumes.md), [RBAC & Security](../rbac_security/rbac_security.md), [Network Policies](../network_policies/network_policies.md), [Troubleshooting](../troubleshooting/troubleshooting.md). |
| **CKS** | Certified Kubernetes Security Specialist. Needs an active CKA. RBAC, Pod Security, NetworkPolicy, supply chain, runtime security (Falco), audit logs. |

Practice tip: get fast with kubectl imperative commands and `--dry-run=client -o yaml`. Use `kubectl explain` instead of searching the web. Practice in killer.sh style simulators.

### 2. Service mesh

Istio, Linkerd, Cilium service mesh. They add mTLS between Pods, retries, timeouts, traffic splitting (canary), and detailed metrics/traces without changing app code. Learn when you have many services talking to each other. Also look at Istio ambient mode (no sidecars).

### 3. Gateway API

The modern replacement for Ingress (GA since 2023). Objects: GatewayClass, Gateway, HTTPRoute, GRPCRoute. Role-based (platform team owns the Gateway, app teams own Routes), supports header matching, traffic splitting and more. Many controllers support it (Envoy Gateway, Istio, Cilium, NGINX Gateway Fabric, Traefik). Since ingress-nginx is retired, new projects should start here.

### 4. Operators & CRDs

Learn to write your own controller with Kubebuilder or Operator SDK (Go), or Kopf (Python). Use existing operators: CloudNativePG, cert-manager, Prometheus Operator, Strimzi (Kafka).

### 5. GitOps

Argo CD or Flux. Store all YAML/Helm values in Git; let the cluster pull it. Add Argo Rollouts or Flagger for canary/blue-green. Combine with Kustomize overlays for dev/staging/prod.

### 6. Also worth learning

- Infrastructure as Code: Terraform/OpenTofu to create EKS/GKE/AKS.
- Policy: Kyverno or OPA Gatekeeper; ValidatingAdmissionPolicy (CEL).
- Node autoscaling: Cluster Autoscaler, Karpenter.
- Event-driven autoscaling: KEDA (scale on queue length, cron ...).
- Observability: OpenTelemetry, Tempo/Jaeger for traces.
- Platform engineering: Backstage, Crossplane, vCluster.
- Run a real cluster with kubeadm on 2-3 VMs (great CKA practice).

---

## D. End - congratulations

You finished the whole learning path: from containers and Pods to RBAC, NetworkPolicies, Helm, monitoring, troubleshooting, production practices and load testing.

Next steps:

1. Do the PRACTICE TASKS you skipped in the earlier topics (see the [Roadmap](../roadmap/roadmap.md)).
2. Build one small project end to end: an app + database (see [volumes/](../volumes/volumes.md) and [statefulset/](../statefulset/statefulset.md)), a Helm chart, an Ingress, HPA, NetworkPolicies, monitoring, a k6 test - all deployed with GitOps.
3. Book the CKAD or CKA exam and practice every day for 2-4 weeks.

Good luck, and keep learning!

---

**Previous:** [Load Testing with k6](../load_testing/load_testing.md) | [Back to README](../README.md)
