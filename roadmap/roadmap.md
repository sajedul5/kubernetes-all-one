# Topic 00: Roadmap - Kubernetes A to Z on Minikube

| | |
|---|---|
| **Level** | All levels |
| **Time** | ~15 min (read once, come back often) |
| **Prereqs** | None |
| **Files** | Every topic folder in this repo (`<folder>/<folder>.md`) |

> Run all commands from the repo root.

---

## 1. Who is this for?

This learning path is for people who want to learn Kubernetes (K8s) from
zero. You do not need cloud money. Everything runs on your own laptop with
Minikube (a small, one-node Kubernetes cluster).

You should know:

- Basic Linux commands (`cd`, `ls`, `cat`, `vim` or `nano`)
- What a terminal is
- A little bit of networking (IP address, port)

You do NOT need to know Docker well. [Topic 01](../docker_basics/docker_basics.md) teaches the basics.

The English is simple on purpose. Short sentences. Many examples.

---

## 2. The full topic list

| No | Lesson | Level | One-line summary |
|----|--------|-------|------------------|
| 00 | [Roadmap](roadmap.md) | All | This file. The plan. |
| 01 | [Containers & Docker basics](../docker_basics/docker_basics.md) | Beginner | Images, containers, Dockerfile, registry. |
| 02 | [Kubernetes architecture](../kubernetes_architecture/kubernetes_architecture.md) | Beginner | Control plane, nodes, how K8s works inside. |
| 03 | [Setup: Minikube & kubectl](../kubernetes_install/kubernetes_install.md) | Beginner | Install Minikube, use kubectl, kubeconfig. |
| 04 | [Pods](../pod/pod.md) | Beginner | The smallest unit. Sidecars, init. |
| 05 | [Labels, selectors, annotations](../labels_selectors/labels_selectors.md) | Beginner | How K8s groups and finds objects. |
| 06 | [ReplicaSets](../replicaset/replicaset.md) | Beginner | Keep N copies of a Pod running. |
| 07 | [Deployments](../deployments/deployments.md) | Beginner | Rolling updates and rollbacks. |
| 08 | [Services](../services/services.md) | Beginner | Stable network name and IP for Pods. |
| 09 | [Namespaces](../namespaces/namespaces.md) | Beginner | Split one cluster into virtual parts. |
| 10 | [ConfigMaps & Secrets](../configmaps_secrets/configmaps_secrets.md) | Intermediate | Config and passwords outside the image. |
| 11 | [Storage: PV, PVC, StorageClass](../volumes/volumes.md) | Intermediate | Keep data when a Pod dies. |
| 12 | [StatefulSets](../statefulset/statefulset.md) | Intermediate | Databases and apps with stable identity. |
| 13 | [DaemonSets, Jobs, CronJobs](../daemonsets_jobs_cronjobs/daemonsets_jobs_cronjobs.md) | Intermediate | One Pod per node, batch and timed jobs. |
| 14 | [Ingress](../ingress/ingress.md) | Intermediate | HTTP routing by host and path. |
| 15 | [Probes & resources](../probes_resources/probes_resources.md) | Intermediate | Health checks, CPU and memory limits. |
| 16 | [Autoscaling (HPA)](../autoscaling_hpa/autoscaling_hpa.md) | Intermediate | Scale Pods by CPU or other metrics. |
| 17 | [RBAC & security](../rbac_security/rbac_security.md) | Advanced | Users, roles, service accounts, PodSecurity. |
| 18 | [Network policies](../network_policies/network_policies.md) | Advanced | Firewall rules between Pods. |
| 19 | [Helm](../helm/helm.md) | Advanced | Package manager for K8s apps. |
| 20 | [Monitoring & logging](../monitoring_logging/monitoring_logging.md) | Advanced | Metrics, Prometheus, Grafana, logs. |
| 21 | [Troubleshooting](../troubleshooting/troubleshooting.md) | Advanced | A step-by-step way to fix broken things. |
| 22 | [Production best practices](../production_best_practices/production_best_practices.md) | Advanced | What to do before you go live. |
| 23 | [Load testing with k6](../load_testing/load_testing.md) | Advanced | Test your app under load, watch HPA work. |
| 24 | [Cheatsheet & interview questions](../cheatsheet_interview/cheatsheet_interview.md) | All | All commands in one place + interview Qs. |

---

## 3. Levels

| Level | Topics | Goal |
|-------|--------|------|
| **Beginner** | 01 - 09 | You can run an app on Kubernetes, scale it, update it, and reach it over the network. You understand what each part of the cluster does. |
| **Intermediate** | 10 - 16 | You can run a "real" app: with config, secrets, saved data, databases, background jobs, HTTP routing, health checks and autoscaling. |
| **Advanced** | 17 - 23 | You can make the cluster safe, observable and ready for production. You can debug problems fast and test performance. |
| **Review** | 24 | Fast revision before an exam (CKAD / CKA) or a job interview. |

---

## 4. Suggested schedule (~6 weeks)

Plan for about 1 to 1.5 hours per day, 5 days per week. Go slower if you
need to. Understanding is more important than speed.

### Week 1 - Foundations

| Day | Work |
|-----|------|
| 1 | [00 roadmap](roadmap.md), [01 containers and Docker basics](../docker_basics/docker_basics.md) |
| 2 | [02 Kubernetes architecture](../kubernetes_architecture/kubernetes_architecture.md) |
| 3 | [03 setup Minikube and kubectl](../kubernetes_install/kubernetes_install.md) |
| 4 | [04 pods](../pod/pod.md) |
| 5 | [05 labels, selectors, annotations](../labels_selectors/labels_selectors.md) + review week 1 |

### Week 2 - Running apps

| Day | Work |
|-----|------|
| 1 | [06 replicasets](../replicaset/replicaset.md) |
| 2 | [07 deployments](../deployments/deployments.md) |
| 3 | [08 services](../services/services.md) |
| 4 | [09 namespaces](../namespaces/namespaces.md) |
| 5 | Mini project: deploy nginx with Deployment + Service in its own namespace. Update the image. Roll back. |

### Week 3 - Config and data

| Day | Work |
|-----|------|
| 1 | [10 configmaps and secrets](../configmaps_secrets/configmaps_secrets.md) |
| 2 | [11 storage: PV, PVC, StorageClass](../volumes/volumes.md) |
| 3 | [12 statefulsets](../statefulset/statefulset.md) |
| 4 | [13 daemonsets, jobs, cronjobs](../daemonsets_jobs_cronjobs/daemonsets_jobs_cronjobs.md) |
| 5 | Mini project: run a database with a StatefulSet and a PVC. |

### Week 4 - Traffic and health

| Day | Work |
|-----|------|
| 1 | [14 ingress](../ingress/ingress.md) |
| 2 | [15 probes and resources](../probes_resources/probes_resources.md) |
| 3 | [16 autoscaling (HPA)](../autoscaling_hpa/autoscaling_hpa.md) |
| 4 | Mini project: app + Ingress + probes + HPA |
| 5 | Review weeks 1-4, redo the quizzes |

### Week 5 - Security and tools

| Day | Work |
|-----|------|
| 1 | [17 RBAC and security](../rbac_security/rbac_security.md) |
| 2 | [18 network policies](../network_policies/network_policies.md) |
| 3 | [19 helm](../helm/helm.md) |
| 4 | [20 monitoring and logging](../monitoring_logging/monitoring_logging.md) |
| 5 | [21 troubleshooting](../troubleshooting/troubleshooting.md) |

### Week 6 - Production and review

| Day | Work |
|-----|------|
| 1 | [22 production best practices](../production_best_practices/production_best_practices.md) |
| 2 | [23 load testing with k6](../load_testing/load_testing.md) |
| 3 | Final project (see [section 7](#7-final-project-week-6)) |
| 4 | Final project |
| 5 | [24 cheatsheet and interview questions](../cheatsheet_interview/cheatsheet_interview.md) |

---

## 5. How to use each lesson

Every topic lesson has the same 10 sections. Use them like this:

| # | Section | How to use it |
|---|---------|---------------|
| 1 | **What is it?** | Read. Make sure you can explain it in 1 line. |
| 2 | **Why do we need it?** | Read. Think: "what problem does it solve?" |
| 3 | **Key concepts** | Read slowly. These words come back later. |
| 4 | **Example YAML** | Type it yourself. Do not copy-paste the first time. Typing helps you remember. |
| 5 | **Hands-on lab** | Run every command. Compare your output with "what you should see". |
| 6 | **Common mistakes** | Read before you get stuck. Come back when stuck. |
| 7 | **Cheat sheet** | Keep it open while you work. |
| 8 | **Practice tasks** | Do them WITHOUT looking at the lab. |
| 9 | **Quiz** | Answer first, then open the "Quiz answers" block. |
| 10 | **Next topic** | Go to the next lesson (links at the bottom of each page). |

Tips:

- Keep a notebook (paper or a text file). Write the commands you learn.
- Break things on purpose. Delete a Pod. Use a wrong image name. Watch
  what Kubernetes does. This is the best way to learn.
- If you cannot answer 4 of 5 quiz questions, read the lesson again.
- Use `kubectl explain <thing>` a lot. It is the built-in manual.

---

## 6. Files in this repo

Topic folders in this repo have a lesson (`<folder>/<folder>.md`) plus notes and
YAML you can apply directly:

| File | What it is |
|------|------------|
| [`kubernetes_architecture/kubernetes_architecture.md`](../kubernetes_architecture/kubernetes_architecture.md) | Architecture lesson |
| [`kubernetes_architecture/kubernetes-cluster-architecture.svg`](../kubernetes_architecture/kubernetes-cluster-architecture.svg) | Diagram |
| [`kubernetes_install/docker-minikube-install.md`](../kubernetes_install/docker-minikube-install.md) | Manual install guide |
| [`scripts/install-minikube-ubuntu.sh`](../scripts/install-minikube-ubuntu.sh) | Install script (Linux) |
| [`scripts/install-minikube-macos.sh`](../scripts/install-minikube-macos.sh) | Install script (macOS) |
| [`scripts/install-minikube-windows.ps1`](../scripts/install-minikube-windows.ps1) | Install script (Windows) |
| [`docker_basics/myweb/`](../docker_basics/myweb/) | Dockerfile + web page for the Docker lab |
| [`pod/nginx-pod.yaml`](../pod/nginx-pod.yaml) | Simple Pod |
| [`pod/pod-demo.yaml`](../pod/pod-demo.yaml) | Pod with init container + native sidecar |
| [`labels_selectors/labels-demo.yaml`](../labels_selectors/labels-demo.yaml) | Pods with labels for the selector lab |
| [`replicaset/nginx-replicaset.yaml`](../replicaset/nginx-replicaset.yaml) | ReplicaSet, 3 Pods |
| [`deployments/nginx-deployments.yaml`](../deployments/nginx-deployments.yaml) | Deployment, 3 Pods |
| [`deployments/web-deploy.yaml`](../deployments/web-deploy.yaml) | Production-style Deployment (strategy, probe) |
| [`services/nginx-services.yaml`](../services/nginx-services.yaml) | ClusterIP Service |
| [`services/svc-types.yaml`](../services/svc-types.yaml) | NodePort, LoadBalancer, headless, ExternalName |
| [`namespaces/nginx-namespaces.yaml`](../namespaces/nginx-namespaces.yaml) | Namespace "nginx" |
| [`load_testing/k6-nginx-test.js`](../load_testing/k6-nginx-test.js) | k6 load test script |

> **Note:** some repo YAML files use `nginx:latest`. The lessons explain
> why a pinned tag like `nginx:1.27` is better. You will see both.

---

## 7. Final project (week 6)

Build a small 2-tier app on Minikube:

- A web app (nginx or any simple app) as a Deployment, 2+ replicas
- A database (PostgreSQL or Redis) as a StatefulSet with a PVC
- Config in a ConfigMap, password in a Secret
- A ClusterIP Service for each part
- An Ingress for the web app (enable: `minikube addons enable ingress`)
- Readiness and liveness probes, CPU/memory requests and limits
- An HPA on the web app
- A NetworkPolicy: only the web app can talk to the database
- Everything in its own namespace
- Bonus: package it as a Helm chart, load test it with k6

If you can build this alone, you know Kubernetes basics very well.

---

## 8. Minikube quick start

Details in [Topic 03: Setup Minikube & kubectl](../kubernetes_install/kubernetes_install.md).

```bash
minikube start            # create and start the cluster
kubectl get nodes         # check the node is Ready
minikube dashboard        # open the web UI (optional)
minikube stop             # stop the cluster (keeps data)
minikube delete           # delete the cluster (removes everything)
```

---

## 9. Good habits from day 1

- Write YAML files. Do not only use `kubectl run` / `kubectl create`.
  YAML files can go into Git. This is called "declarative" style.
- Always pin image tags (`nginx:1.27`, not `nginx:latest`).
- Always use labels (`app`, `tier`, `version`).
- Read error messages fully. `kubectl describe` and `kubectl logs` solve
  most problems.
- Clean up after each lab: `kubectl delete -f <file>.yaml`

---

## 10. Next topic

[Topic 01: Containers & Docker basics](../docker_basics/docker_basics.md)

---

**Next:** [Topic 01: Containers & Docker basics](../docker_basics/docker_basics.md) | [Back to README](../README.md)
