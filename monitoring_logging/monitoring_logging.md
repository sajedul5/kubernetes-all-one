# Topic 20: Monitoring & Logging

| | |
|---|---|
| **Level** | Advanced |
| **Time** | ~75 min |
| **Prereqs** | [Probes & Resources](../probes_resources/probes_resources.md), [Autoscaling (HPA)](../autoscaling_hpa/autoscaling_hpa.md), [Helm](../helm/helm.md) |
| **Files** | [kps-values.yaml](kps-values.yaml), [podinfo-servicemonitor.yaml](podinfo-servicemonitor.yaml), [restart-alerts.yaml](restart-alerts.yaml), [deployments/nginx-deployments.yaml](../deployments/nginx-deployments.yaml) |

> Run all commands from the repo root.

---

## 1. What is it?

Observability = knowing what happens inside your cluster. 3 main parts:

| Part | What | Tools |
|---|---|---|
| **Metrics** | numbers over time (CPU, memory, requests per second, error rate) | metrics-server, Prometheus, Grafana |
| **Logs** | text lines that apps write (stdout/stderr) | `kubectl logs`, Loki, Fluent Bit, Elasticsearch/OpenSearch |
| **Events** | short Kubernetes messages: "Pulled image", "Back-off restarting", "FailedScheduling". Kept for ~1 hour. | `kubectl get events`, `kubectl events` |

(Traces are the 4th part - OpenTelemetry, Jaeger, Tempo. Not covered here.)

---

## 2. Why do we need it?

- Find problems BEFORE users do (alerts).
- Find the cause of a problem fast (logs + metrics at the same time).
- Right-size resources: see real CPU/memory use, set good requests.
- HPA needs metrics (metrics-server) to scale.
- Pods die and are replaced. Their logs disappear with them. A log system keeps them.

---

## 3. Key concepts

### a) metrics-server

Small add-on. Collects CPU/memory from each kubelet every ~15s. Keeps ONLY current values (no history). Used by `kubectl top` and HPA.

Minikube: `minikube addons enable metrics-server`

### b) Prometheus

Time-series database. It PULLS ("scrapes") metrics from HTTP endpoints (usually `/metrics`) every N seconds. Query language: PromQL.

### c) kube-prometheus-stack (Helm chart)

One chart that installs:

| Component | Role |
|---|---|
| Prometheus Operator | manages Prometheus with CRDs |
| Prometheus | stores metrics |
| Alertmanager | sends alerts (Slack, email, PagerDuty) |
| Grafana | dashboards (many built in) |
| node-exporter | node metrics (CPU, disk, network) |
| kube-state-metrics | object state (replicas, Pod phase, restarts) |

### d) Operator CRDs

- **ServiceMonitor** -> "scrape the Pods behind this Service"
- **PodMonitor** -> "scrape these Pods directly"
- **PrometheusRule** -> alert rules and recording rules

By default the chart only picks up objects with label `release: <helm-release-name>`.

### e) Logs in Kubernetes

Apps write to stdout/stderr. The container runtime saves them on the node in `/var/log/pods/...`. `kubectl logs` reads these files.

A log agent (DaemonSet = one Pod per node) reads the same files and sends them to a central store.

- **Fluent Bit** -> light, fast, sends to many backends
- **Grafana Alloy** -> Grafana's agent (Promtail is deprecated; Alloy replaces it)
- **Loki** -> stores logs, cheap, query with LogQL in Grafana

### f) Useful PromQL

| Query | Meaning |
|---|---|
| `up` | 1 = target is up |
| `sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="default"}[5m]))` | CPU cores per Pod |
| `sum by (pod) (container_memory_working_set_bytes{namespace="default", container!=""})` | memory per Pod |
| `kube_pod_container_status_restarts_total` | restart counts |
| `kube_deployment_status_replicas_available` | ready replicas |

---

## 4. Example YAML

### a) Helm values for kube-prometheus-stack on Minikube

Saved as [monitoring_logging/kps-values.yaml](kps-values.yaml):

```yaml
grafana:
  adminPassword: "change-me-123"   # lab only! use a Secret in prod
prometheus:
  prometheusSpec:
    retention: 2d                  # keep 2 days of data (small laptop)
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
alertmanager:
  alertmanagerSpec:
    resources:
      requests:
        memory: 64Mi
```

### b) ServiceMonitor - scrape an app that has /metrics

podinfo (from [Helm](../helm/helm.md)) exposes metrics on port `http` (9898). Saved as [monitoring_logging/podinfo-servicemonitor.yaml](podinfo-servicemonitor.yaml):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: podinfo
  namespace: default
  labels:
    release: kps                 # MUST match the Helm release name
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: my-podinfo   # labels on the Service
  endpoints:
  - port: http                   # NAME of the Service port
    path: /metrics               # where metrics are
    interval: 15s                # scrape every 15 seconds
```

### c) PrometheusRule - alert if a container restarts often

Saved as [monitoring_logging/restart-alerts.yaml](restart-alerts.yaml):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: restart-alerts
  namespace: default
  labels:
    release: kps                 # so Prometheus loads this rule
spec:
  groups:
  - name: pods
    rules:
    - alert: PodRestartingTooMuch
      # more than 3 restarts in the last 15 minutes
      expr: increase(kube_pod_container_status_restarts_total[15m]) > 3
      for: 5m                    # must be true for 5 minutes
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.pod }} restarts too much"
```

---

## 5. Hands-on lab

1. Start Minikube with enough memory (the stack needs ~3-4 GB):

   ```bash
   minikube start --cpus=4 --memory=6144
   ```

   (If you already have a cluster with less memory, run `minikube delete` first. Memory size is fixed at create time.)

2. Basic logs with kubectl:

   ```bash
   kubectl apply -f deployments/nginx-deployments.yaml
   kubectl logs deploy/nginx-deployment            # one Pod
   kubectl logs -l app=nginx --prefix --tail=20    # all Pods
   kubectl logs -f deploy/nginx-deployment         # follow (Ctrl+C)
   kubectl logs <pod> --previous                   # crashed container
   kubectl logs <pod> --since=10m --timestamps
   ```

3. metrics-server and `kubectl top`:

   ```bash
   minikube addons enable metrics-server
   kubectl get pods -n kube-system -l k8s-app=metrics-server
   ```

   Wait ~60 seconds, then:

   ```bash
   kubectl top nodes
   kubectl top pods -A --sort-by=memory
   kubectl top pods -l app=nginx --containers
   ```

   You see CPU in millicores (m) and memory in Mi.

4. Events:

   ```bash
   kubectl get events --sort-by=.lastTimestamp
   kubectl get events -A --field-selector type=Warning
   kubectl events --for deployment/nginx-deployment
   ```

5. Install kube-prometheus-stack:

   ```bash
   helm repo add prometheus-community \
     https://prometheus-community.github.io/helm-charts
   helm repo update
   helm install kps prometheus-community/kube-prometheus-stack \
     -n monitoring --create-namespace -f monitoring_logging/kps-values.yaml
   kubectl get pods -n monitoring -w
   ```

   Wait until all Pods are Running (2-5 minutes). Ctrl+C.

6. Open Grafana:

   ```bash
   kubectl get svc -n monitoring
   kubectl port-forward -n monitoring svc/kps-grafana 3000:80
   ```

   Open <http://localhost:3000>. User: `admin`. Password: `change-me-123`.

   (Without the values file, read the password from the Secret:)

   ```bash
   kubectl get secret -n monitoring kps-grafana \
     -o jsonpath='{.data.admin-password}' | base64 -d ; echo
   ```

   Go to Dashboards -> "Kubernetes / Compute Resources / Namespace (Pods)". Select namespace `default`. You see the nginx Pods.

7. Open Prometheus (new terminal):

   ```bash
   kubectl port-forward -n monitoring svc/prometheus-operated 9090
   ```

   Open <http://localhost:9090>. Try the queries from section 3f. Status -> Targets shows everything Prometheus scrapes.

8. Apply the PrometheusRule from 4c:

   ```bash
   kubectl apply -f monitoring_logging/restart-alerts.yaml
   ```

   After ~1 minute, in Prometheus go to Alerts. You should see `PodRestartingTooMuch` (inactive).

9. (Optional) Central logs - short version with Fluent Bit:

   ```bash
   helm repo add fluent https://fluent.github.io/helm-charts
   helm install fluent-bit fluent/fluent-bit -n logging \
     --create-namespace
   kubectl logs -n logging ds/fluent-bit --tail=20
   ```

   By default it reads container logs on each node. In real life you set an "output" (Loki, Elasticsearch, S3, CloudWatch ...) in values. The Grafana way is Loki + Grafana Alloy (helm charts `grafana/loki` and `grafana/alloy`) and then add Loki as a data source in Grafana.

10. Clean up:

    ```bash
    kubectl delete -f monitoring_logging/restart-alerts.yaml
    helm uninstall kps -n monitoring
    helm uninstall fluent-bit -n logging
    kubectl delete ns monitoring logging
    ```

    Note: Helm does not delete CRDs. Delete them by hand if you want:

    ```bash
    kubectl get crd | grep monitoring.coreos.com
    ```

---

## 6. Common mistakes & troubleshooting

- `error: Metrics API not available` -> metrics-server not installed or not ready yet. Enable the addon and wait 1 minute.
- `kubectl top` shows nothing for a new Pod -> wait one scrape cycle.
- kube-prometheus-stack Pods Pending -> not enough memory. Give Minikube more (`--memory=6144`) or lower requests in values.
- ServiceMonitor ignored -> missing label `release: kps`, wrong Service label selector, or `port` is a number instead of the port NAME.
- Target DOWN in Prometheus -> wrong path, app has no `/metrics`, or a NetworkPolicy blocks Prometheus (allow namespace `monitoring`).
- `kubectl logs` for a Pod with many containers -> add `-c <container>` or `--all-containers`.
- Logs of a crashed container are gone -> use `--previous`. After the Pod is deleted, logs are only in your central log system.
- Events disappear after ~1 hour. Check them early, or export them.
- Grafana password lost -> read it from the grafana Secret.
- Very high memory in Prometheus -> too many labels (high cardinality, e.g. user IDs as labels). Never put unique IDs in metric labels.

---

## 7. Cheat sheet

| Command | Purpose |
|---|---|
| `kubectl logs <pod>` | logs of a Pod |
| `kubectl logs <pod> -c <container>` | one container |
| `kubectl logs -f deploy/<name>` | follow logs |
| `kubectl logs <pod> --previous` | last crashed container |
| `kubectl logs -l app=nginx --prefix` | by label, show Pod name |
| `kubectl logs <pod> --since=1h --tail=100` | limit output |
| `kubectl top nodes` | node CPU/memory |
| `kubectl top pods -A --sort-by=cpu` | heaviest Pods |
| `kubectl get events --sort-by=.lastTimestamp` | events in time order |
| `kubectl events --for pod/<pod>` | events of one object |
| `minikube addons enable metrics-server` | turn on metrics |
| `helm install kps prometheus-community/kube-prometheus-stack -n monitoring --create-namespace` | full monitoring stack |
| `kubectl port-forward -n monitoring svc/kps-grafana 3000:80` | open Grafana |
| `kubectl port-forward -n monitoring svc/prometheus-operated 9090` | open Prometheus |
| `kubectl get servicemonitor,prometheusrule -A` | monitoring CRDs |

---

## 8. Practice tasks

1. Run `kubectl top pods` for nginx. Compare real usage with the requests you set in [Probes & Resources](../probes_resources/probes_resources.md). Are your requests too high or too low?
2. Install podinfo ([Helm](../helm/helm.md)) and create the ServiceMonitor from 4b (`kubectl apply -f monitoring_logging/podinfo-servicemonitor.yaml`). Find the podinfo target in Prometheus -> Status -> Targets.
3. In Grafana, create a new dashboard panel with the query:

   ```promql
   sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="default"}[5m]))
   ```

4. Create a Pod that crashes every 10 seconds (`busybox:1.36`, command `sh -c 'sleep 10; exit 1'`). Watch the PrometheusRule alert go from inactive -> pending -> firing.
5. Write a one-line command that shows only Warning events from the last hour in all namespaces.

---

## 9. Quiz

1. What is the difference between metrics-server and Prometheus?
2. How do you see the logs of a container that crashed and restarted?
3. Which label does kube-prometheus-stack need on a ServiceMonitor by default?
4. Where do container logs live on a node, and which kind of workload usually collects them?
5. How long are Kubernetes events kept by default?

<details>
<summary>Quiz answers</summary>

1. metrics-server keeps only the CURRENT CPU/memory values (for `kubectl top` and HPA). Prometheus stores many metrics with HISTORY and has a query language and alerts.
2. `kubectl logs <pod> --previous` (add `-c <container>` if needed)
3. `release: <helm-release-name>` (e.g. `release: kps`)
4. In `/var/log/pods/` (and `/var/log/containers/`) on the node. A DaemonSet log agent (Fluent Bit, Alloy) reads them on every node.
5. About 1 hour (the API server default `--event-ttl=1h`).

</details>

---

**Previous:** [Helm](../helm/helm.md) | **Next:** [Troubleshooting](../troubleshooting/troubleshooting.md) | [Back to README](../README.md)
