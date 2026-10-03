# Topic 22: Production Best Practices

| | |
|---|---|
| **Level** | Advanced |
| **Time** | ~75 min |
| **Prereqs** | [Probes & Resources](../probes_resources/probes_resources.md), [Autoscaling (HPA)](../autoscaling_hpa/autoscaling_hpa.md), [RBAC & Security](../rbac_security/rbac_security.md), [Network Policies](../network_policies/network_policies.md), [Helm](../helm/helm.md) |
| **Files** | [nginx-prod.yaml](nginx-prod.yaml), [pdb.yaml](pdb.yaml), [argocd-application.yaml](argocd-application.yaml), [deployments/nginx-deployments.yaml](../deployments/nginx-deployments.yaml) (the "before" version), [services/nginx-services.yaml](../services/nginx-services.yaml) |

> Run all commands from the repo root.

---

## 1. What is it?

A CHECKLIST of things to do before (and after) you run real users' traffic on Kubernetes. Each item links back to a topic you learned.

The repo file [deployments/nginx-deployments.yaml](../deployments/nginx-deployments.yaml) is fine for learning, but NOT for production:

| Problem | Why it matters |
|---|---|
| `image: nginx:latest` | not pinned |
| no requests/limits | can starve other Pods, HPA cannot work |
| no probes | traffic goes to Pods that are not ready |
| no PDB, no spreading | one node failure can kill all replicas |
| root user | fails "restricted" Pod Security |

In section 4 we fix all of this.

---

## 2. Why do we need it?

- Most outages come from small missing settings, not from Kubernetes bugs.
- A checklist makes reviews fast and the same for every team.
- Interviewers often ask: "What do you check before going to prod?"

---

## 3. Key concepts (the checklist)

### Workloads

- [ ] Pin image tags (`nginx:1.27.2`), or even digests (`@sha256:...`). Never `latest`. ([Deployments](../deployments/deployments.md))
- [ ] Set `resources.requests` (CPU + memory) on every container. Set a memory limit. CPU limit is optional (it can cause throttling). ([Probes & Resources](../probes_resources/probes_resources.md))
- [ ] `readinessProbe` on every app. `livenessProbe` only if the app can hang. `startupProbe` for slow starters. ([Probes & Resources](../probes_resources/probes_resources.md))
- [ ] At least 2 replicas (3 is better) for anything users depend on.
- [ ] PodDisruptionBudget (PDB): keeps a minimum number of Pods during voluntary disruptions (node drain, cluster upgrade).
- [ ] Spread Pods across nodes and zones: `topologySpreadConstraints` or `podAntiAffinity`.
- [ ] Rolling update strategy: `maxUnavailable: 0`, `maxSurge: 1` (or 25%). Use `kubectl rollout status` in CI. Keep `revisionHistoryLimit`.
- [ ] Graceful shutdown: handle SIGTERM; set `terminationGracePeriodSeconds`; a small `preStop` sleep helps load balancers remove the Pod first.
- [ ] HPA for variable load ([Autoscaling (HPA)](../autoscaling_hpa/autoscaling_hpa.md)). Test it with k6 ([Load Testing with k6](../load_testing/load_testing.md)).
- [ ] Set `priorityClassName` for critical apps.

### Security

- [ ] RBAC least privilege. No cluster-admin for apps or CI. One ServiceAccount per app. `automountServiceAccountToken: false` when the app does not call the API. ([RBAC & Security](../rbac_security/rbac_security.md))
- [ ] Pod Security Admission: "restricted" (or at least "baseline") on app namespaces. `runAsNonRoot`, `readOnlyRootFilesystem`, drop ALL.
- [ ] NetworkPolicy: default deny + explicit allows. ([Network Policies](../network_policies/network_policies.md))
- [ ] Secrets management: Kubernetes Secrets are only base64. Turn on encryption at rest. Keep real secrets in a vault (HashiCorp Vault, AWS/GCP/Azure secret managers) and sync them with External Secrets Operator, or store encrypted in Git with Sealed Secrets or SOPS. Never commit plain secrets.
- [ ] Scan images in CI (Trivy, Grype). Use a private, trusted registry.
- [ ] Admission policies (Kyverno, OPA Gatekeeper, or built-in ValidatingAdmissionPolicy) to enforce rules like "no latest tag", "must have requests".

### Operations

- [ ] Separate environments: namespaces dev/staging/prod with ResourceQuota + LimitRange ([Namespaces](../namespaces/namespaces.md)). For strong isolation, use separate clusters for prod.
- [ ] GitOps: Git is the source of truth. Argo CD or Flux syncs Git to the cluster. No manual `kubectl apply` in prod. Easy rollback = `git revert`.
- [ ] Everything as code: Helm charts or Kustomize ([Helm](../helm/helm.md)).
- [ ] Monitoring + alerts + central logs ([Monitoring & Logging](../monitoring_logging/monitoring_logging.md)). Alert on symptoms (error rate, latency), not only on CPU.
- [ ] Backups: Velero backs up Kubernetes objects AND volume data to object storage (S3, GCS, Azure Blob). Test restores regularly. Also back up etcd if you run your own control plane.
- [ ] Use managed Kubernetes when possible: Amazon EKS, Google GKE, Azure AKS. The cloud runs the control plane, etcd and upgrades for you.
- [ ] Upgrades: one minor version at a time (1.31 -> 1.32 -> 1.33). Control plane first, then nodes. Read the release notes for removed APIs (tools: pluto, kubent). Upgrade in staging first. Kubernetes supports each minor version ~14 months; stay on a supported one.
- [ ] Ingress with TLS (cert-manager + Let's Encrypt). Note: the community ingress-nginx project is retired (2026). For new setups look at Gateway API implementations or another maintained controller.
- [ ] Cluster autoscaler or Karpenter for nodes, so Pending Pods get a node.
- [ ] Cost: right-size requests using real metrics. Delete unused PVCs and LoadBalancers.

---

## 4. Example YAML

### Production-style nginx

Saved as [production_best_practices/nginx-prod.yaml](nginx-prod.yaml) (Deployment + Service):

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-prod
  labels:
    app: nginx-prod
spec:
  replicas: 3                        # survive the loss of one Pod
  revisionHistoryLimit: 5            # keep 5 old ReplicaSets for undo
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0              # never go below 3 ready Pods
      maxSurge: 1                    # add 1 new Pod at a time
  selector:
    matchLabels:
      app: nginx-prod
  template:
    metadata:
      labels:
        app: nginx-prod
    spec:
      automountServiceAccountToken: false  # nginx never calls the API
      terminationGracePeriodSeconds: 30
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        seccompProfile:
          type: RuntimeDefault
      topologySpreadConstraints:
      - maxSkew: 1                   # Pod count per node differs by <= 1
        topologyKey: kubernetes.io/hostname   # spread over nodes
        whenUnsatisfiable: ScheduleAnyway     # soft rule (DoNotSchedule
                                              # = hard rule)
        labelSelector:
          matchLabels:
            app: nginx-prod
      # In the cloud also spread over zones:
      #   topologyKey: topology.kubernetes.io/zone
      containers:
      - name: nginx
        image: nginxinc/nginx-unprivileged:1.27.2-alpine  # pinned
        ports:
        - name: http
          containerPort: 8080
        resources:
          requests:                  # used for scheduling and HPA
            cpu: 100m
            memory: 64Mi
          limits:
            memory: 128Mi            # memory limit protects the node
        readinessProbe:              # send traffic only when ready
          httpGet:
            path: /
            port: http
          periodSeconds: 5
        livenessProbe:               # restart if it hangs
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
        lifecycle:
          preStop:                   # let the LB remove us first
            sleep:
              seconds: 5             # native sleep action (v1.30+)
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-prod
spec:
  selector:
    app: nginx-prod
  ports:
  - port: 8080
    targetPort: http                 # named port is safer
```

The PodDisruptionBudget, saved as [production_best_practices/pdb.yaml](pdb.yaml):

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nginx-prod-pdb
spec:
  minAvailable: 2                    # a drain may evict only 1 Pod
  selector:                          # at a time out of 3
    matchLabels:
      app: nginx-prod
```

Hard anti-affinity alternative (max one Pod per node), goes in the Pod `spec`:

```yaml
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: nginx-prod
            topologyKey: kubernetes.io/hostname
```

### GitOps example - Argo CD Application

Argo CD must be installed. Saved as [production_best_practices/argocd-application.yaml](argocd-application.yaml):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<you>/kubernetes-all-one.git
    targetRevision: main
    path: deployments                # folder with YAML to sync
  destination:
    server: https://kubernetes.default.svc
    namespace: prod
  syncPolicy:
    automated:
      prune: true                    # delete objects removed from Git
      selfHeal: true                 # undo manual changes in cluster
    syncOptions:
    - CreateNamespace=true
```

---

## 5. Hands-on lab

1. Start a 3-node Minikube cluster (new profile):

   ```bash
   minikube start -p prod-lab --nodes 3 --cpus=2 --memory=2048
   kubectl get nodes
   ```

   You see `prod-lab`, `prod-lab-m02`, `prod-lab-m03`.

2. Apply the production nginx and its PDB:

   ```bash
   kubectl apply -f production_best_practices/nginx-prod.yaml
   kubectl apply -f production_best_practices/pdb.yaml
   kubectl get pods -l app=nginx-prod -o wide
   ```

   The NODE column shows one Pod on each node (spread).

3. Check the PDB:

   ```bash
   kubectl get pdb
   ```

   ALLOWED DISRUPTIONS = 1.

4. Drain a node (like a node upgrade):

   ```bash
   kubectl drain prod-lab-m02 --ignore-daemonsets \
     --delete-emptydir-data
   kubectl get pods -l app=nginx-prod -o wide
   ```

   The Pod moves to another node. The PDB made sure 2 stayed available.

   ```bash
   kubectl uncordon prod-lab-m02
   ```

5. Zero-downtime rolling update. In terminal A:

   ```bash
   kubectl get pods -l app=nginx-prod -w
   ```

   In terminal B:

   ```bash
   kubectl set image deploy/nginx-prod \
     nginx=nginxinc/nginx-unprivileged:1.27.3-alpine
   kubectl rollout status deploy/nginx-prod
   ```

   You see one new Pod become Ready before an old one stops.

   ```bash
   kubectl rollout history deploy/nginx-prod
   kubectl rollout undo deploy/nginx-prod
   ```

6. Separate environments with namespaces + quota:

   ```bash
   kubectl create ns staging
   kubectl create quota staging-quota -n staging \
     --hard=requests.cpu=1,requests.memory=1Gi,pods=10
   kubectl apply -f production_best_practices/nginx-prod.yaml -n staging
   kubectl apply -f production_best_practices/pdb.yaml -n staging
   kubectl describe quota -n staging
   ```

7. Check security level (no change, just warnings):

   ```bash
   kubectl label --dry-run=server --overwrite ns staging \
     pod-security.kubernetes.io/enforce=restricted
   ```

   No warnings = nginx-prod passes "restricted".

8. (Optional) Backups with Velero. Velero needs object storage (S3, GCS, Azure Blob; for a lab you can run MinIO). Install it with `velero install ...` as shown in <https://velero.io/docs>. Then:

   ```bash
   velero backup create staging-bk --include-namespaces staging
   velero backup get
   kubectl delete ns staging
   velero restore create --from-backup staging-bk
   ```

   (See <https://velero.io/docs> for full setup.)

9. Clean up:

   ```bash
   minikube delete -p prod-lab
   ```

---

## 6. Common mistakes & troubleshooting

- PDB with `minAvailable` equal to replicas (3 of 3) -> node drains and cluster upgrades hang forever. Leave room for at least 1 disruption.
- PDB on a single-replica app -> same problem. Use 2+ replicas.
- Hard anti-affinity with more replicas than nodes -> extra Pods stay Pending. Use `topologySpreadConstraints` with `ScheduleAnyway` or "preferred" anti-affinity.
- `maxUnavailable: 0` and `maxSurge: 0` -> invalid; rollout cannot start.
- Liveness probe that checks a database -> DB slow = all Pods restart. Liveness should check only the process itself.
- Memory limit too low -> OOMKilled under load. Check real usage with monitoring before setting limits.
- Manual hotfix in prod with `kubectl edit` while Argo CD selfHeal is on -> Argo CD reverts it. Fix in Git.
- Backups never tested -> they may not work. Do restore drills.
- Skipping minor versions in upgrades -> not supported.
- Same cluster for dev and prod with no quotas -> a dev load test can starve prod.

---

## 7. Cheat sheet

| Command | Purpose |
|---|---|
| `kubectl get pdb` | disruption budgets |
| `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data` | evict Pods safely |
| `kubectl cordon <node>` / `kubectl uncordon <node>` | stop / allow scheduling |
| `kubectl rollout status deploy/<d>` | wait for rollout |
| `kubectl rollout history deploy/<d>` | revisions |
| `kubectl rollout undo deploy/<d> --to-revision=2` | rollback |
| `kubectl rollout restart deploy/<d>` | restart all Pods safely |
| `kubectl set image deploy/<d> <c>=<img:tag>` | new image |
| `kubectl create quota <q> -n <ns> --hard=...` | limit a namespace |
| `kubectl get pods -o wide` | check Pod spreading |
| `kubectl version` | client + server version |
| `argocd app sync <app>` / `argocd app list` | Argo CD CLI |
| `flux get kustomizations` | Flux status |
| `velero backup create <b> --include-namespaces <ns>` | backup |
| `velero restore create --from-backup <b>` | restore |
| `pluto detect-files -d .` | find removed APIs |

---

## 8. Practice tasks

1. Rewrite [deployments/nginx-deployments.yaml](../deployments/nginx-deployments.yaml) with every item from the WORKLOADS checklist. Keep labels `app=nginx` so [services/nginx-services.yaml](../services/nginx-services.yaml) still works (watch out for the port: unprivileged nginx uses 8080).
2. On the 3-node cluster, change the PDB to `minAvailable: 3` and try to drain a node. What happens? Press Ctrl+C and fix it.
3. Change `topologySpreadConstraints` to `DoNotSchedule` and scale to 7. Where do the Pods go?
4. Write a short "prod readiness" review of any Helm chart from [Helm](../helm/helm.md). Which checklist items are missing?
5. Install Argo CD (see <https://argo-cd.readthedocs.io>) on Minikube and sync the `deployments/` folder from your fork of this repo (edit `repoURL` in [argocd-application.yaml](argocd-application.yaml), then `kubectl apply -f production_best_practices/argocd-application.yaml`).

---

## 9. Quiz

1. Why should you not use the `latest` image tag?
2. What does a PodDisruptionBudget protect against? What does it NOT protect against?
3. What do `maxUnavailable: 0` and `maxSurge: 1` mean in a rolling update?
4. Name 2 GitOps tools and the main idea of GitOps.
5. Why upgrade Kubernetes one minor version at a time?

<details>
<summary>Quiz answers</summary>

1. `latest` can change at any time. Two Pods may run different code, rollbacks do not work well, and you cannot know what is running.
2. It protects against VOLUNTARY disruptions (drain, upgrade, eviction API). It does NOT protect against node crashes or OOM kills.
3. Never have fewer ready Pods than desired (0 unavailable) and create at most 1 extra Pod at a time during the update.
4. Argo CD and Flux. Git is the single source of truth; a controller in the cluster pulls and applies what is in Git automatically.
5. Kubernetes only supports upgrading one minor version at a time (version skew rules), and APIs can be removed between versions.

</details>

---

**Previous:** [Troubleshooting](../troubleshooting/troubleshooting.md) | **Next:** [Load Testing with k6](../load_testing/load_testing.md) | [Back to README](../README.md)
