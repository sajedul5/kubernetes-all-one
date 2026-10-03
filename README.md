# kubernetes-all-one

A complete, all-in-one Kubernetes learning repository. Start from zero, follow the
learning path step by step, and practise every topic on a local **Minikube** cluster.

> **New here?** 1) Install Minikube with one script → 2) open
> [`roadmap/roadmap.md`](roadmap/roadmap.md) → 3) follow topics 00 → 24 in order.

---

## 1. Quick Start: Install Minikube

| OS | Command |
|----|---------|
| **Ubuntu** (22.04/24.04) | `chmod +x scripts/install-minikube-ubuntu.sh && ./scripts/install-minikube-ubuntu.sh` |
| **macOS** (Intel / Apple Silicon) | `chmod +x scripts/install-minikube-macos.sh && ./scripts/install-minikube-macos.sh` |
| **Windows** 10/11 (PowerShell as Admin) | `Set-ExecutionPolicy -Scope Process Bypass; .\scripts\install-minikube-windows.ps1` |

Each script installs **Docker + kubectl + Minikube**, starts the cluster, and enables the
`ingress`, `metrics-server` and `dashboard` addons. Add `--no-start` (or `-NoStart` on
Windows) to install only. Change the cluster size with `MINIKUBE_CPUS` / `MINIKUBE_MEMORY`
(or `-Cpus` / `-Memory` on Windows).

Check that it works:

```bash
kubectl get nodes        # STATUS should be Ready
minikube dashboard       # opens the web UI
```

Manual step-by-step guide: [`kubernetes_install/docker-minikube-install.md`](kubernetes_install/docker-minikube-install.md)

## 2. Optional: Install k6 (load testing)

| OS | Command |
|----|---------|
| **Ubuntu** | `./scripts/install-k6-ubuntu.sh` |
| **macOS** | `./scripts/install-k6-macos.sh` |
| **Windows** | `.\scripts\install-k6-windows.ps1` |

```bash
kubectl apply -f deployments/nginx-deployments.yaml -f services/nginx-services.yaml
kubectl port-forward svc/nginx-service 8080:8080     # keep this running
k6 run load_testing/k6-nginx-test.js                 # in a second terminal
```

---

## 3. Learning Path (A → Z)

Each topic lives in its own folder: a lesson `<topic>/<topic>.md` plus ready-to-apply YAML.
Every lesson has the same layout: **what / why → key concepts → YAML explained →
hands-on lab → common mistakes → cheat sheet → practice tasks → quiz**.

Follow the topics in order. Run all commands from the repo root.

| # | Topic | Level | Folder |
|---|-------|-------|--------|
| 00 | [Roadmap & study plan](roadmap/roadmap.md) | – | [`roadmap/`](roadmap/) |
| 01 | [Containers & Docker basics](docker_basics/docker_basics.md) | Beginner | [`docker_basics/`](docker_basics/) |
| 02 | [Kubernetes architecture](kubernetes_architecture/kubernetes_architecture.md) | Beginner | [`kubernetes_architecture/`](kubernetes_architecture/) |
| 03 | [Setup: Minikube & kubectl](kubernetes_install/kubernetes_install.md) | Beginner | [`kubernetes_install/`](kubernetes_install/) |
| 04 | [Pods](pod/pod.md) | Beginner | [`pod/`](pod/) |
| 05 | [Labels, selectors, annotations](labels_selectors/labels_selectors.md) | Beginner | [`labels_selectors/`](labels_selectors/) |
| 06 | [ReplicaSets](replicaset/replicaset.md) | Beginner | [`replicaset/`](replicaset/) |
| 07 | [Deployments](deployments/deployments.md) | Beginner | [`deployments/`](deployments/) |
| 08 | [Services](services/services.md) | Beginner | [`services/`](services/) |
| 09 | [Namespaces, quotas, limits](namespaces/namespaces.md) | Beginner | [`namespaces/`](namespaces/) |
| 10 | [ConfigMaps & Secrets](configmaps_secrets/configmaps_secrets.md) | Beginner | [`configmaps_secrets/`](configmaps_secrets/) |
| 11 | [Storage: PV, PVC, StorageClass](volumes/volumes.md) | Intermediate | [`volumes/`](volumes/) |
| 12 | [StatefulSets](statefulset/statefulset.md) | Intermediate | [`statefulset/`](statefulset/) |
| 13 | [DaemonSets, Jobs, CronJobs](daemonsets_jobs_cronjobs/daemonsets_jobs_cronjobs.md) | Intermediate | [`daemonsets_jobs_cronjobs/`](daemonsets_jobs_cronjobs/) |
| 14 | [Ingress](ingress/ingress.md) | Intermediate | [`ingress/`](ingress/) |
| 15 | [Probes & resources](probes_resources/probes_resources.md) | Intermediate | [`probes_resources/`](probes_resources/) |
| 16 | [Autoscaling (HPA)](autoscaling_hpa/autoscaling_hpa.md) | Intermediate | [`autoscaling_hpa/`](autoscaling_hpa/) |
| 17 | [RBAC & security](rbac_security/rbac_security.md) | Advanced | [`rbac_security/`](rbac_security/) |
| 18 | [Network policies](network_policies/network_policies.md) | Advanced | [`network_policies/`](network_policies/) |
| 19 | [Helm](helm/helm.md) | Advanced | [`helm/`](helm/) |
| 20 | [Monitoring & logging](monitoring_logging/monitoring_logging.md) | Advanced | [`monitoring_logging/`](monitoring_logging/) |
| 21 | [Troubleshooting](troubleshooting/troubleshooting.md) | Advanced | [`troubleshooting/`](troubleshooting/) |
| 22 | [Production best practices](production_best_practices/production_best_practices.md) | Advanced | [`production_best_practices/`](production_best_practices/) |
| 23 | [Load testing with k6](load_testing/load_testing.md) | Advanced | [`load_testing/`](load_testing/) |
| 24 | [Cheat sheet & interview Q&A](cheatsheet_interview/cheatsheet_interview.md) | All | [`cheatsheet_interview/`](cheatsheet_interview/) |

---

## 4. Repository Structure

```
kubernetes-all-one/
├── README.md                  # you are here
├── scripts/                   # one-command installers (Minikube + k6, Ubuntu/macOS/Windows)
├── roadmap/                   # 00 Roadmap & study plan
├── docker_basics/             # 01 Containers & Docker basics
├── kubernetes_architecture/   # 02 Kubernetes architecture
├── kubernetes_install/        # 03 Setup: Minikube & kubectl
├── pod/                       # 04 Pods
├── labels_selectors/          # 05 Labels, selectors, annotations
├── replicaset/                # 06 ReplicaSets
├── deployments/               # 07 Deployments
├── services/                  # 08 Services
├── namespaces/                # 09 Namespaces, quotas, limits
├── configmaps_secrets/        # 10 ConfigMaps & Secrets
├── volumes/                   # 11 Storage: PV, PVC, StorageClass
├── statefulset/               # 12 StatefulSets
├── daemonsets_jobs_cronjobs/  # 13 DaemonSets, Jobs, CronJobs
├── ingress/                   # 14 Ingress
├── probes_resources/          # 15 Probes & resources
├── autoscaling_hpa/           # 16 Autoscaling (HPA)
├── rbac_security/             # 17 RBAC & security
├── network_policies/          # 18 Network policies
├── helm/                      # 19 Helm
├── monitoring_logging/        # 20 Monitoring & logging
├── troubleshooting/           # 21 Troubleshooting
├── production_best_practices/ # 22 Production best practices
├── load_testing/              # 23 Load testing with k6
├── cheatsheet_interview/      # 24 Cheat sheet & interview Q&A
```

Inside every topic folder: `<topic>.md` (the lesson) + `*.yaml` (the examples).

## 5. Run the Examples in Order

```bash
kubectl apply -f pod/nginx-pod.yaml                    # 1. single Pod
kubectl delete -f pod/nginx-pod.yaml
kubectl apply -f deployments/nginx-deployments.yaml    # 2. Deployment (3 nginx pods)
kubectl apply -f services/nginx-services.yaml          # 3. Service in front of the pods
kubectl apply -f ingress/nginx-ingress.yaml            # 4. Ingress -> http://nginx.example.com
kubectl apply -f volumes/sc.yaml -f volumes/pvc.yaml \
              -f volumes/deployment.yaml -f volumes/service.yaml   # 5. MongoDB + PVC
kubectl apply -f statefulset/                          # 6. MongoDB StatefulSet (needs volumes/sc.yaml)
```

Each topic folder has more examples; its `.md` lesson tells you which file to apply and when.

Clean up everything: `minikube delete`

## 6. Useful Links

- Official docs: https://kubernetes.io/docs/
- kubectl cheat sheet: https://kubernetes.io/docs/reference/kubectl/quick-reference/
- Minikube: https://minikube.sigs.k8s.io/docs/
- k6: https://grafana.com/docs/k6/latest/

## Contributing

Found a mistake or want to add a topic? Open an issue or PR. Keep new topics in the
same format: `<topic>/<topic>.md` + YAML files, and add a row to the table above.
