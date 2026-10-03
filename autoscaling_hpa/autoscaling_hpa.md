# Topic 16: Autoscaling - Horizontal Pod Autoscaler (HPA)

| | |
|---|---|
| **Level** | Intermediate |
| **Time** | ~50 min |
| **Prereqs** | [Deployments](../deployments/deployments.md), [Services](../services/services.md), [Probes & Resources](../probes_resources/probes_resources.md) |
| **Files** | [`autoscaling_hpa/nginx-deployment.yaml`](nginx-deployment.yaml), [`autoscaling_hpa/nginx-hpa.yaml`](nginx-hpa.yaml), [`services/nginx-services.yaml`](../services/nginx-services.yaml), [`deployments/nginx-deployments.yaml`](../deployments/nginx-deployments.yaml) (base for the lab Deployment) |

> Run all commands from the repo root.

---

## 1. What is it?

The HorizontalPodAutoscaler (HPA) changes the number of replicas of a Deployment (or StatefulSet, or ReplicaSet) automatically, based on metrics like CPU or memory usage.

```text
Load goes UP   -> HPA adds Pods    (scale out)
Load goes DOWN -> HPA removes Pods (scale in)
```

- **"Horizontal"** = more or fewer Pods.
- **"Vertical"** = bigger or smaller Pods (more CPU/memory per Pod). That is the VPA, see [section 3](#3-key-concepts).

---

## 2. Why do we need it?

- Traffic changes during the day. Fixed replicas are either too many (wasted money) or too few (slow site, errors).
- Humans are slow to react at 3 AM. HPA checks every 15 seconds.
- Together with the Cluster Autoscaler, the cluster can grow and shrink the NODES too.

---

## 3. Key concepts

### a) metrics-server

HPA needs numbers. For CPU/memory they come from metrics-server (the "resource metrics API"). It is NOT installed by default.

```bash
minikube addons enable metrics-server   # on Minikube
kubectl top pods                        # test (works after ~1 minute)
```

### b) Requests are REQUIRED

CPU utilization % = real usage / REQUEST.

No cpu request on the container -> HPA cannot compute % and shows `<unknown>` in TARGETS. Every container in the Pod should have a request for the metric you use.

### c) The formula

```text
desiredReplicas = ceil( currentReplicas x currentValue / targetValue )
```

Example: 2 Pods at 90% CPU, target 50%: `ceil(2 x 90 / 50) = ceil(3.6) = 4` Pods.

There is a 10% tolerance: no change if the ratio is 0.9 - 1.1.

### d) min / max

`minReplicas` and `maxReplicas` are hard limits. HPA never goes outside.

### e) Stabilization (no "flapping")

- **Scale up**: by default happens quickly (no stabilization window).
- **Scale down**: by default waits 300 seconds (5 min) and uses the HIGHEST recommendation in that window. So Pods go away slowly.

You can tune this in `spec.behavior`.

### f) API version

Use `autoscaling/v2` (stable since v1.23). It supports many metrics, memory, custom metrics and `behavior`. `autoscaling/v1` = CPU only.

### g) Metric types in v2

| Type | Source |
|---|---|
| `Resource` | cpu / memory of the Pods (from metrics-server) |
| `ContainerResource` | cpu / memory of ONE container in the Pod |
| `Pods` / `Object` / `External` | Custom metrics (for example requests per second from Prometheus via prometheus-adapter, or a queue length) |

KEDA is a popular tool for event-driven scaling (Kafka, RabbitMQ, cron ...).

### h) Do not fight the HPA

If HPA manages a Deployment, do NOT set `replicas` by hand (or in your YAML on every apply). HPA will change it back. Many teams remove `replicas:` from the Deployment YAML when HPA is used.

### i) VPA - Vertical Pod Autoscaler (brief)

An add-on (not built in). It watches real usage and RECOMMENDS or SETS better requests/limits. Modes: `Off` (only recommend), `Initial`, `Recreate`, `InPlaceOrRecreate` (apply changes).

Do not use VPA and HPA on the SAME metric (cpu) for the same workload - they will fight.

Note: in-place Pod resize (change CPU/memory without a restart) is beta in v1.33, GA in v1.35, and newer VPA versions can use it.

### j) Cluster Autoscaler (brief)

Adds NODES when Pods are Pending because no node has room, and removes nodes that are almost empty. Works with cloud node groups (AWS, GCP, Azure). Karpenter is a newer alternative (mainly AWS).

On Minikube there is no Cluster Autoscaler - you add nodes by hand with `minikube node add`.

| Autoscaler | Changes |
|---|---|
| HPA | The NUMBER of Pods |
| VPA | The SIZE (requests/limits) of Pods |
| Cluster Autoscaler | The number of NODES |

---

## 4. Example YAML

### Step A: the Deployment MUST have requests: [`autoscaling_hpa/nginx-deployment.yaml`](nginx-deployment.yaml)

Based on [`deployments/nginx-deployments.yaml`](../deployments/nginx-deployments.yaml).

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  # replicas: 3              # removed: HPA owns the replica count
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
          image: nginx:1.27
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 50m       # REQUIRED: HPA % is based on this
              memory: 32Mi
            limits:
              cpu: 200m
              memory: 128Mi
```

### Step B: the HPA: [`autoscaling_hpa/nginx-hpa.yaml`](nginx-hpa.yaml)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-hpa
spec:
  scaleTargetRef:                 # WHAT to scale
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-deployment
  minReplicas: 1                  # never fewer than 1
  maxReplicas: 10                 # never more than 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization       # percent of the REQUEST
          averageUtilization: 50  # keep average CPU near 50%
    - type: Resource
      resource:
        name: memory
        target:
          type: AverageValue      # absolute value per Pod
          averageValue: 100Mi
  behavior:                       # optional tuning
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100              # at most double the Pods ...
          periodSeconds: 15       # ... every 15 seconds
    scaleDown:
      stabilizationWindowSeconds: 120   # wait 2 min before scale in
      policies:
        - type: Pods
          value: 1                # remove max 1 Pod ...
          periodSeconds: 60       # ... per minute
```

With 2 metrics, HPA computes replicas for each and uses the HIGHEST.

---

## 5. Hands-on lab

### Step 1: Enable metrics-server

```bash
minikube addons enable metrics-server
kubectl get deploy metrics-server -n kube-system
```

Wait ~1 minute, then:

```bash
kubectl top nodes
# -> minikube   250m   6%   1200Mi   15%   (numbers will differ)
```

### Step 2: Deploy the app and Service

```bash
kubectl apply -f autoscaling_hpa/nginx-deployment.yaml
kubectl apply -f services/nginx-services.yaml
kubectl top pods -l app=nginx
# -> CPU about 0-1m (idle)
```

### Step 3a: Quick way (one command, CPU only)

```bash
kubectl autoscale deployment nginx-deployment \
  --cpu-percent=50 --min=1 --max=10
kubectl get hpa
kubectl delete hpa nginx-deployment     # we will use the YAML instead
```

### Step 3b: YAML way

```bash
kubectl apply -f autoscaling_hpa/nginx-hpa.yaml
kubectl get hpa nginx-hpa
# -> TARGETS  cpu: 0%/50%, memory: 3Mi/100Mi  MINPODS 1  MAXPODS 10
```

If you see `<unknown>`: wait 1-2 minutes, check requests are set.

### Step 4: Watch the HPA in terminal 1

```bash
kubectl get hpa nginx-hpa -w
```

### Step 5: Generate load in terminal 2 (busybox loop)

```bash
kubectl run load --image=busybox:1.36 --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- \
  http://nginx-service:8080 >/dev/null; done"
```

Start 2-3 of these (`load2`, `load3`) if CPU does not go above 50%. nginx is very fast, so it needs a lot of requests.

Better option: **k6** (a real load-testing tool with virtual users, ramp-up stages and nice reports). See [Topic 23: Load Testing with k6](../load_testing/load_testing.md) for the script ([`load_testing/k6-nginx-test.js`](../load_testing/k6-nginx-test.js)) and how to run it in the cluster against `http://nginx-service:8080`.

### Step 6: See it scale out (terminal 1)

```bash
# -> TARGETS cpu: 180%/50%   REPLICAS 1 -> 4 -> 8 ...
kubectl get pods -l app=nginx
kubectl describe hpa nginx-hpa | tail -10
# -> "New size: 4; reason: cpu resource utilization (percentage of
#    request) above target"
```

### Step 7: Stop the load and watch scale in

```bash
kubectl delete pod load load2 load3 --ignore-not-found
# -> CPU drops to 0%. After the scaleDown window (2 min here), Pods are
#    removed one per minute, down to minReplicas 1.
```

### Step 8: See HPA status details

```bash
kubectl get hpa nginx-hpa -o yaml | sed -n '/status:/,$p'
# -> currentMetrics, desiredReplicas, conditions (AbleToScale,
#    ScalingActive, ScalingLimited)
```

### Step 9: Clean up

```bash
kubectl delete -f autoscaling_hpa/nginx-hpa.yaml \
  -f autoscaling_hpa/nginx-deployment.yaml
kubectl delete -f services/nginx-services.yaml
```

---

## 6. Common mistakes & troubleshooting

- **TARGETS shows `<unknown>`**
  - metrics-server not running / not ready yet (`kubectl top pods` fails), or the containers have NO cpu request. `kubectl describe hpa NAME` -> "failed to get cpu utilization: missing request for cpu".
- **HPA does not scale above maxReplicas**
  - Working as designed. Condition `ScalingLimited` is True.
- **Scale up works, but new Pods stay Pending**
  - No room on the node. Lower requests, add nodes (`minikube node add`), or use a Cluster Autoscaler in the cloud.
- **Replicas jump back after `kubectl apply`**
  - Your Deployment YAML has `replicas: 3` and you re-apply it. Remove `replicas` from the YAML when HPA is used.
- **Scale down is "too slow"**
  - Default 5 minute stabilization window. Tune `behavior.scaleDown.stabilizationWindowSeconds`.
- **Pods scale up and down all the time (flapping)**
  - Target too close to normal usage, or windows too short. Add a scaleDown window, and use a readinessProbe so new Pods do not get traffic before they are ready.
- **Memory-based HPA never scales down**
  - Many apps never give memory back. CPU or request-rate metrics are usually better.

---

## 7. Cheat sheet

| Command | What it does |
|---|---|
| `minikube addons enable metrics-server` | Install metrics API |
| `kubectl top nodes` / `kubectl top pods` | Current CPU/memory usage |
| `kubectl autoscale deploy NAME --cpu-percent=50 --min=1 --max=10` | Quick CPU HPA |
| `kubectl get hpa` | List HPAs, targets, replicas |
| `kubectl get hpa NAME -w` | Watch it live |
| `kubectl describe hpa NAME` | Events, conditions, reasons |
| `kubectl edit hpa NAME` | Change min/max/targets |
| `kubectl delete hpa NAME` | Stop autoscaling |
| `kubectl api-resources \| grep -i autoscal` | Check HPA API versions |
| `kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods \| head` | Raw metrics-server data |

---

## 8. Practice tasks

1. Remove the cpu request from [`autoscaling_hpa/nginx-deployment.yaml`](nginx-deployment.yaml) (in a copy), re-apply, and read the HPA error in `kubectl describe hpa`. Put it back.
2. Change `averageUtilization` to 20. Run one busybox load Pod. How many replicas do you get? Check with the formula in section 3c.
3. Set scaleDown `stabilizationWindowSeconds` to 30 and compare how fast Pods go away.
4. Use the k6 script from [Topic 23: Load Testing with k6](../load_testing/load_testing.md) against `nginx-service` and record max replicas reached.
5. Make an HPA for the mongo StatefulSet from [Topic 12: StatefulSets](../statefulset/statefulset.md) (min 3, max 5). Think: is autoscaling a database a good idea? Why or why not?

---

## 9. Quiz

1. Which Minikube addon does HPA need for CPU/memory metrics?
2. CPU utilization in the HPA is a percent of what?
3. 3 Pods run at 100% CPU, target is 50%. How many Pods will HPA want (if maxReplicas allows)?
4. Why is scale down slower than scale up by default?
5. What is the difference between HPA, VPA and Cluster Autoscaler?

<details><summary>Quiz answers</summary>

1. metrics-server (`minikube addons enable metrics-server`).
2. Of the container CPU REQUEST.
3. `ceil(3 x 100 / 50) = 6` Pods.
4. A 300 second stabilization window on scale down prevents flapping; HPA removes Pods only when the lower count was stable for a while.
5. HPA changes the NUMBER of Pods. VPA changes the SIZE (requests/limits) of Pods. Cluster Autoscaler changes the number of NODES.

</details>

---

**Previous:** [Topic 15: Probes & Resources](../probes_resources/probes_resources.md) | **Next:** [Topic 17: RBAC & Security](../rbac_security/rbac_security.md) | [Back to README](../README.md)
