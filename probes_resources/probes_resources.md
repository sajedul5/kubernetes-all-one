# Topic 15: Probes & Resources (Requests / Limits)

| | |
|---|---|
| **Level** | Intermediate |
| **Time** | ~50 min |
| **Prereqs** | [Pods](../pod/pod.md), [Deployments](../deployments/deployments.md), [Services](../services/services.md), [Namespaces](../namespaces/namespaces.md) |
| **Files** | [`probes_resources/nginx-probes.yaml`](nginx-probes.yaml), [`probes_resources/live-demo.yaml`](live-demo.yaml), [`probes_resources/oom-demo.yaml`](oom-demo.yaml), [`deployments/nginx-deployments.yaml`](../deployments/nginx-deployments.yaml) (has NO probes and NO resources - we add them here), [`services/nginx-services.yaml`](../services/nginx-services.yaml) |

> Run all commands from the repo root.

---

## 1. What is it?

Two things that make your Pods healthy and good neighbours.

**PROBES** = health checks that the kubelet runs against your container.

| Probe | Question | On failure |
|---|---|---|
| `livenessProbe` | "Is the app alive?" | RESTART the container |
| `readinessProbe` | "Can it take traffic?" | REMOVE from Service endpoints (no restart) |
| `startupProbe` | "Has it finished starting?" | Until yes, liveness and readiness are NOT run. If it fails too long -> restart |

**RESOURCES** = how much CPU and memory a container needs and may use.

| Field | Meaning |
|---|---|
| `requests` | What the container is GUARANTEED. Used by the scheduler to choose a node |
| `limits` | The MAXIMUM it may use. Enforced on the node |

---

## 2. Why do we need it?

Without probes:

- A Pod with a deadlocked app stays "Running" forever, but it is broken.
- During a rolling update, traffic goes to a new Pod that is not ready yet -> users get errors.
- A slow-starting Java app gets killed by a too-strict liveness check.

Without resources:

- The scheduler puts too many Pods on one node. The node runs out of memory and Pods are killed at random.
- One buggy Pod can eat all CPU and slow down every other Pod.
- HPA ([Topic 16: Autoscaling](../autoscaling_hpa/autoscaling_hpa.md)) can NOT work: it needs CPU/memory requests.

---

## 3. Key concepts

### a) Probe types (how to check)

| Type | Success when |
|---|---|
| `httpGet` | HTTP GET returns status 200-399 |
| `tcpSocket` | TCP connect works |
| `exec` | Command run in the container exits with code 0 |
| `grpc` | gRPC health check protocol says serving (stable since v1.27) |

### b) Probe timing fields

| Field | Default | Meaning |
|---|---|---|
| `initialDelaySeconds` | 0 | Wait before first check |
| `periodSeconds` | 10 | Check every N seconds |
| `timeoutSeconds` | 1 | One check fails if slower than this |
| `failureThreshold` | 3 | N failures in a row = "failed" |
| `successThreshold` | 1 | N successes = "ok" (must be 1 for liveness and startup) |

### c) Startup probe math

Max start time = `failureThreshold` x `periodSeconds`.
Example: 30 x 5s = 150 seconds to start before restart.

### d) Good probe rules

- Liveness should check ONLY the process itself. Do NOT check the database in liveness: if the DB is down, restarting your app does not help, and all Pods restart together.
- Readiness may check dependencies (it only removes traffic).
- Use a startupProbe for slow apps instead of a huge `initialDelaySeconds`.

### e) CPU and memory units

- **CPU**: `1` = 1 core (vCPU). `500m` = 0.5 core. `100m` = 0.1 core.
- **Memory**: bytes. `Mi`/`Gi` = power of 2 (`128Mi`). `M`/`G` = power of 10.
  Careful: `128m` means 0.128 BYTES. Use `128Mi`.

### f) What happens at the limit

| Situation | Result |
|---|---|
| CPU over limit | THROTTLED (slowed down). Not killed. CPU is "compressible" |
| Memory over limit | Container is KILLED: reason `OOMKilled`, exit code 137. Memory is "not compressible" |
| Node short on memory | kubelet EVICTS Pods (lowest QoS first) |

### g) QoS classes (set automatically from requests/limits)

| QoS class | Rule | Eviction |
|---|---|---|
| `Guaranteed` | EVERY container has cpu AND memory requests == limits | Last to be evicted |
| `Burstable` | At least one container has a request or limit, but not Guaranteed | Middle |
| `BestEffort` | NO requests or limits at all | First to be evicted |

See it:

```bash
kubectl get pod NAME -o jsonpath='{.status.qosClass}'
```

### h) Only a limit set

If you set only a limit, the request is set equal to the limit.

### i) A common team policy

Many teams set memory limit = memory request (avoid OOM surprises) and set a CPU request but NO CPU limit (avoid throttling). Decide with your team; always set requests.

---

## 4. Example YAML

### nginx Deployment with probes and resources: [`probes_resources/nginx-probes.yaml`](nginx-probes.yaml)

Like [`deployments/nginx-deployments.yaml`](../deployments/nginx-deployments.yaml), but with probes and resources.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
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
          image: nginx:1.27            # pinned (repo uses nginx:latest)
          ports:
            - containerPort: 80
          resources:
            requests:                  # used for scheduling
              cpu: 100m                # 0.1 core guaranteed
              memory: 64Mi
            limits:                    # hard maximum
              cpu: 250m                # throttled above this
              memory: 128Mi            # OOMKilled above this
          startupProbe:                # runs first
            httpGet:
              path: /
              port: 80
            periodSeconds: 5
            failureThreshold: 12       # up to 60s to start
          readinessProbe:              # controls traffic
            httpGet:
              path: /
              port: 80
            periodSeconds: 5
            failureThreshold: 2
          livenessProbe:               # controls restarts
            tcpSocket:
              port: 80
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3        # 3 x 10s = 30s broken -> restart
```

### exec probe example (file-based)

```yaml
          livenessProbe:
            exec:
              command: ["cat", "/tmp/healthy"]   # exit 0 = alive
            initialDelaySeconds: 5
            periodSeconds: 5
```

### Liveness demo Pod: [`probes_resources/live-demo.yaml`](live-demo.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: live-demo
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c",
        "touch /tmp/healthy; sleep 30; rm /tmp/healthy; sleep 600"]
      livenessProbe:
        exec:
          command: ["cat", "/tmp/healthy"]   # exit 0 = alive
        initialDelaySeconds: 5
        periodSeconds: 5
```

### OOM demo Pod: [`probes_resources/oom-demo.yaml`](oom-demo.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: oom-demo
spec:
  restartPolicy: Never
  containers:
    - name: hog
      image: polinux/stress:1.0.4    # small stress-test tool
      command: ["stress"]
      args: ["--vm", "1", "--vm-bytes", "150M", "--vm-hang", "1"]
      resources:
        limits:
          memory: 50Mi               # it tries 150M -> killed
```

---

## 5. Hands-on lab

### Step 1: Apply and check

```bash
kubectl apply -f probes_resources/nginx-probes.yaml
kubectl get pods -l app=nginx
kubectl describe pod -l app=nginx \
  | grep -E 'Liveness|Readiness|Startup'
kubectl get pod -l app=nginx -o jsonpath='{.items[0].status.qosClass}'
# -> Burstable (requests are lower than limits)
```

### Step 2: Break readiness, see traffic stop (no restart)

```bash
kubectl apply -f services/nginx-services.yaml
POD=$(kubectl get pod -l app=nginx \
  -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- rm /usr/share/nginx/html/index.html
kubectl get pods -l app=nginx
# -> that Pod shows READY 0/1, RESTARTS 0
kubectl get endpointslices -l kubernetes.io/service-name=nginx-service
# -> only 2 ready IPs
kubectl exec $POD -- \
  sh -c 'echo ok > /usr/share/nginx/html/index.html'
# -> READY 1/1 again
```

### Step 3: Liveness restart with an exec probe

```bash
kubectl apply -f probes_resources/live-demo.yaml
kubectl get pod live-demo -w
# -> after ~45s RESTARTS goes to 1. Ctrl+C.
kubectl get events --field-selector involvedObject.name=live-demo
# -> "Liveness probe failed ... Container app failed liveness probe,
#    will be restarted"
```

### Step 4: OOMKilled

```bash
kubectl apply -f probes_resources/oom-demo.yaml
kubectl get pod oom-demo
# -> STATUS OOMKilled
kubectl get pod oom-demo \
  -o jsonpath='{.status.containerStatuses[0].state.terminated}'
# -> "exitCode":137, "reason":"OOMKilled"
```

### Step 5: CPU throttling (not killed)

```bash
kubectl run cpu-demo --image=busybox:1.36 \
  --overrides='{"spec":{"containers":[{"name":"cpu-demo",
    "image":"busybox:1.36","command":["sh","-c","while :; do :; done"],
    "resources":{"limits":{"cpu":"200m"}}}]}}'
minikube addons enable metrics-server     # wait ~1 minute
kubectl top pod cpu-demo
# -> CPU about 200m (never above), Pod keeps running.
```

### Step 6: QoS classes

```bash
kubectl get pods -o \
  custom-columns=NAME:.metadata.name,QOS:.status.qosClass
# -> cpu-demo  : Burstable  (CPU limit only; request copied from the
#                            limit, but no memory values)
#    live-demo : BestEffort (no requests, no limits)
#    oom-demo  : Burstable  (memory limit only)
```

### Step 7: A Pod that can not be scheduled

```bash
kubectl run big --image=nginx:1.27 \
  --overrides='{"spec":{"containers":[{"name":"big",
    "image":"nginx:1.27","resources":{"requests":{"cpu":"64"}}}]}}'
kubectl describe pod big | tail -3
# -> "0/1 nodes are available: 1 Insufficient cpu."
```

### Step 8: See node capacity

```bash
kubectl describe node minikube | sed -n '/Allocated resources/,/Events/p'
```

### Step 9: Clean up

```bash
kubectl delete pod live-demo oom-demo cpu-demo big
kubectl delete -f probes_resources/nginx-probes.yaml
kubectl delete -f services/nginx-services.yaml
```

---

## 6. Common mistakes & troubleshooting

- **CrashLoopBackOff with "Liveness probe failed"**
  - Probe too strict, wrong port/path, or app starts slowly. Add a startupProbe. Check: `kubectl describe pod`, Events section.
- **Pod Running but READY 0/1 forever**
  - Readiness probe fails. Test the same URL by hand: `kubectl exec POD -- wget -qO- localhost:80/path`
- **Liveness checks the database**
  - All Pods restart in a loop when the DB is down. Remove external checks from liveness.
- **Exit code 137 / OOMKilled**
  - Memory limit too small or memory leak. Look at real usage with `kubectl top pod`, then raise the limit. (Java/Node: also set heap size to fit the limit.)
- **App is slow but CPU looks "fine"**
  - CPU throttling. Usage is stuck at the limit. Raise or remove the CPU limit.
- **Pod Pending "Insufficient cpu/memory"**
  - Requests are bigger than free node capacity. Lower requests or add nodes. Remember: scheduling uses REQUESTS, not real usage.
- **`128m` memory**
  - That is 0.128 bytes. You meant `128Mi`.

---

## 7. Cheat sheet

| Command | What it does |
|---|---|
| `kubectl describe pod NAME` | Probe config, events, last state |
| `kubectl get pod NAME -o jsonpath='{.status.qosClass}'` | QoS class |
| `kubectl get events --sort-by=.lastTimestamp` | Recent probe failures, OOMs |
| `kubectl top pod` / `kubectl top node` | Real CPU/memory (metrics-server) |
| `kubectl describe node NAME` | Allocated resources on a node |
| `kubectl set resources deploy NAME --requests=cpu=100m,memory=64Mi --limits=memory=128Mi` | Set resources quickly |
| `kubectl logs POD --previous` | Logs of the crashed container |
| `kubectl get pod POD -o jsonpath='{.status.containerStatuses[0].lastState}'` | Why the last run ended |

---

## 8. Practice tasks

1. Add probes and resources to a copy of [`deployments/nginx-deployments.yaml`](../deployments/nginx-deployments.yaml). Make it QoS `Guaranteed`.
2. Give the readinessProbe a wrong path (`/nothing`). What do `kubectl get pods` and the Service endpoints show? Does it restart?
3. Make a startupProbe for a container that sleeps 40s before it creates `/tmp/started`. Pick `failureThreshold` and `periodSeconds` so it does not get killed.
4. Make a Pod hit OOMKilled, then fix it by changing only the limit.
5. Write one sentence each: when do you use liveness, readiness, startup?

---

## 9. Quiz

1. A readiness probe fails. Is the container restarted?
2. What happens when a container uses more memory than its limit? And more CPU than its limit?
3. A Pod has two containers. Both have cpu and memory requests equal to limits. Which QoS class?
4. What does the scheduler use to place a Pod: requests or limits?
5. Why use a startupProbe instead of a long `initialDelaySeconds` on the livenessProbe?

<details><summary>Quiz answers</summary>

1. No. It is only removed from Service endpoints until it is ready.
2. Memory: the container is killed (OOMKilled, exit 137). CPU: it is throttled (slowed), not killed.
3. Guaranteed.
4. Requests.
5. The startupProbe only protects the start. After the app is up, liveness checks run fast again. A long `initialDelaySeconds` delays failure detection on every start and is a fixed guess.

</details>

---

**Previous:** [Topic 14: Ingress](../ingress/ingress.md) | **Next:** [Topic 16: Autoscaling (HPA)](../autoscaling_hpa/autoscaling_hpa.md) | [Back to README](../README.md)
