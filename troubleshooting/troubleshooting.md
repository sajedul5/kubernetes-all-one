# Topic 21: Troubleshooting

| | |
|---|---|
| **Level** | Advanced |
| **Time** | ~90 min |
| **Prereqs** | [Deployments](../deployments/deployments.md), [Services](../services/services.md), [Storage (PV, PVC, StorageClass)](../volumes/volumes.md), [Ingress](../ingress/ingress.md), [Probes & Resources](../probes_resources/probes_resources.md), [Monitoring & Logging](../monitoring_logging/monitoring_logging.md) |
| **Files** | [broken.yaml](broken.yaml), [deployments/nginx-deployments.yaml](../deployments/nginx-deployments.yaml), [services/nginx-services.yaml](../services/nginx-services.yaml), [ingress/nginx-ingress.yaml](../ingress/nginx-ingress.yaml) |

> Run all commands from the repo root.

---

## 1. What is it?

Troubleshooting = finding WHY something does not work, step by step.

Do not guess. Follow a FLOW. Most problems are found with 4 commands:

| Command | Question |
|---|---|
| `kubectl get` | what is the STATUS? |
| `kubectl describe` | what do the EVENTS say? |
| `kubectl logs` | what does the APP say? |
| `kubectl exec` / `kubectl debug` | what does it look like INSIDE? |

---

## 2. Why do we need it?

- Things break: wrong image tag, missing Secret, low memory, typo in a label. You must fix it fast, often under pressure.
- Kubernetes has many layers (Pod, Service, Ingress, node, storage). A clear flow tells you which layer is broken.
- It is the most asked topic in CKA/CKAD exams and job interviews.

---

## 3. Key concepts

### a) The systematic flow (top to bottom)

1. `kubectl get pods -o wide` -> STATUS, RESTARTS, NODE
2. `kubectl describe pod <pod>` -> read "Events" at the bottom
3. `kubectl logs <pod> [--previous]` -> app errors
4. `kubectl get events --sort-by=.lastTimestamp`
5. Pod OK? -> check the Service: `kubectl get svc,endpointslices`
6. Service OK? -> check Ingress / DNS / NetworkPolicy
7. Still unknown? -> exec / debug inside the Pod or node
8. Node problem? -> `kubectl describe node`, `minikube ssh`

### b) Pod STATUS -> where to look

| STATUS | FIRST LOOK AT |
|---|---|
| Pending | describe pod (Events: scheduling) |
| ContainerCreating (long) | describe pod (volumes, image pull, CNI) |
| ImagePullBackOff / ErrImagePull | describe pod (image name, tag, auth) |
| CrashLoopBackOff | logs --previous, exit code |
| OOMKilled | describe pod (Last State), limits |
| CreateContainerConfigError | describe pod (missing ConfigMap/Secret) |
| Running but 0/1 READY | describe pod (readiness probe) |
| Terminating (stuck) | finalizers, node down |

### c) Exit codes (in describe -> Last State)

| Code | Meaning |
|---|---|
| 0 | finished OK (wrong for a long-running app; check command) |
| 1 | app error (read logs) |
| 126 / 127 | command not executable / not found |
| 137 | killed by SIGKILL (OOMKilled or liveness probe kill) |
| 143 | SIGTERM (normal stop) |

### d) kubectl debug and ephemeral containers

Many images have no shell (distroless). An EPHEMERAL container is a temporary debug container added to a RUNNING Pod (GA since v1.25). `--target=<container>` lets it see the processes of that container.

```bash
kubectl debug -it <pod> --image=busybox:1.36 --target=<container>
```

Other modes:

- `--copy-to=<new-pod>` -> copy the Pod and change it (e.g. new command) without touching the original
- `node/<node>` -> a Pod on the node, node disk at `/host`

---

## 4. Example YAML

Broken examples, saved as [troubleshooting/broken.yaml](broken.yaml). Each one shows a different error.

```yaml
---
# A) ImagePullBackOff - tag does not exist
apiVersion: v1
kind: Pod
metadata:
  name: bad-image
spec:
  containers:
  - name: web
    image: nginx:1.27.99-doesnotexist   # wrong tag
---
# B) CrashLoopBackOff - app exits with error
apiVersion: v1
kind: Pod
metadata:
  name: crashy
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo starting; sleep 3; echo boom; exit 1"]
---
# C) OOMKilled - uses more memory than the limit
apiVersion: v1
kind: Pod
metadata:
  name: memory-hog
spec:
  containers:
  - name: hog
    image: busybox:1.36
    command: ["sh", "-c", "tail /dev/zero"]  # eats memory fast
    resources:
      limits:
        memory: 64Mi                         # killed above 64Mi
---
# D) CreateContainerConfigError - ConfigMap does not exist
apiVersion: v1
kind: Pod
metadata:
  name: missing-config
spec:
  containers:
  - name: web
    image: nginx:1.27.2
    env:
    - name: MODE
      valueFrom:
        configMapKeyRef:
          name: app-config                  # not created
          key: mode
---
# E) Pending - asks for more CPU than any node has
apiVersion: v1
kind: Pod
metadata:
  name: too-big
spec:
  containers:
  - name: web
    image: nginx:1.27.2
    resources:
      requests:
        cpu: "100"                           # 100 cores!
---
# F) PVC Pending - StorageClass does not exist
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  storageClassName: fast-ssd-missing        # wrong class name
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
---
# G) Service with NO endpoints - selector typo
apiVersion: v1
kind: Service
metadata:
  name: broken-svc
spec:
  selector:
    app: ngnix                               # typo: nginx Pods not found
  ports:
  - port: 8080
    targetPort: 80
```

---

## 5. Hands-on lab

1. Setup:

   ```bash
   minikube start
   kubectl apply -f deployments/nginx-deployments.yaml
   kubectl apply -f services/nginx-services.yaml
   kubectl apply -f troubleshooting/broken.yaml
   kubectl get pods -o wide
   ```

   After ~1 minute you see many different STATUS values.

2. ImagePullBackOff / ErrImagePull (`bad-image`):

   ```bash
   kubectl describe pod bad-image | tail -15
   ```

   Events: "Failed to pull image ... not found". Fix: correct the image name/tag. For private registries check `imagePullSecrets`. ErrImagePull = first failure. ImagePullBackOff = waiting to retry.

3. CrashLoopBackOff (`crashy`):

   ```bash
   kubectl get pod crashy -w           # RESTARTS goes up. Ctrl+C.
   kubectl logs crashy --previous      # "starting" "boom"
   kubectl describe pod crashy | grep -A5 "Last State"
   ```

   Exit Code 1. Fix: the app or its command/config. The wait between restarts grows: 10s, 20s, 40s ... up to 5 minutes.

4. OOMKilled (`memory-hog`):

   ```bash
   kubectl describe pod memory-hog | grep -A5 "Last State"
   ```

   Reason: OOMKilled, Exit Code: 137. Fix: raise the memory limit, or fix a memory leak. Check real use with `kubectl top pod`.

5. CreateContainerConfigError (`missing-config`):

   ```bash
   kubectl describe pod missing-config | tail -5
   ```

   `configmap "app-config" not found`. Fix it:

   ```bash
   kubectl create configmap app-config --from-literal=mode=prod
   ```

   Wait a few seconds -> the Pod becomes Running by itself.

6. Pending (`too-big`):

   ```bash
   kubectl describe pod too-big | tail -5
   ```

   `0/1 nodes are available: 1 Insufficient cpu.` Other Pending reasons: taints, nodeSelector/affinity no match, PVC not bound, quota.

7. PVC Pending (`data-pvc`):

   ```bash
   kubectl get pvc
   kubectl describe pvc data-pvc
   kubectl get storageclass
   ```

   `storageclass "fast-ssd-missing" not found`. Fix: use an existing class (on Minikube: `standard`) or remove `storageClassName`.

   Note: with `WaitForFirstConsumer` the PVC stays Pending until a Pod uses it. That is normal.

8. Service has no endpoints (`broken-svc`):

   ```bash
   kubectl get endpointslices -l kubernetes.io/service-name=broken-svc
   kubectl describe svc broken-svc | grep -i endpoints
   ```

   No addresses. Compare:

   ```bash
   kubectl get svc broken-svc -o jsonpath='{.spec.selector}'; echo
   kubectl get pods --show-labels
   ```

   Fix the selector to `app: nginx`. Other causes: Pods not READY (readiness probe fails), targetPort wrong.

   Test from inside the cluster:

   ```bash
   kubectl run t --rm -it --image=busybox:1.36 --restart=Never \
     -- wget -qO- -T 3 http://nginx-service:8080
   ```

9. Ingress 404 / 503:

   ```bash
   minikube addons enable ingress
   kubectl apply -f ingress/nginx-ingress.yaml
   kubectl get ingress
   curl -H "Host: nginx.example.com" http://$(minikube ip)/
   ```

   (On macOS/Windows with the Docker driver run `minikube tunnel` in another terminal and use `http://127.0.0.1/` instead.)

   | Response | Cause |
   |---|---|
   | 404 Not Found | host or path does not match any rule, or wrong `ingressClassName` |
   | 503 Service Unavailable | rule matches but the Service has no ready endpoints, or wrong service name/port |
   | 502 Bad Gateway | endpoints exist but the app does not answer on targetPort |

   Look at the controller logs:

   ```bash
   kubectl logs -n ingress-nginx deploy/ingress-nginx-controller \
     --tail=20
   ```

10. Ephemeral debug container (nginx image has no ps/netstat tools):

    ```bash
    POD=$(kubectl get pod -l app=nginx -o name | head -1)
    kubectl debug -it $POD --image=busybox:1.36 \
      --target=nginx-container
    # inside:  ps aux ; wget -qO- localhost:80 ; exit
    kubectl get $POD -o jsonpath='{.spec.ephemeralContainers[*].name}'
    ```

    You see the debugger container name.

11. Debug a copy (change the command of a crashing Pod):

    ```bash
    kubectl debug crashy -it --copy-to=crashy-debug --container=app \
      -- sh
    ```

    Now you have a shell in a copy of crashy. Look around, then exit.

12. exec into a running container:

    ```bash
    kubectl exec -it deploy/nginx-deployment -- sh
    # inside: cat /etc/nginx/conf.d/default.conf ; env ; exit
    ```

13. Node problems (NotReady):

    ```bash
    kubectl get nodes
    kubectl describe node minikube | grep -A8 Conditions
    ```

    Look at MemoryPressure, DiskPressure, PIDPressure, Ready. Then:

    ```bash
    minikube ssh
    sudo systemctl status kubelet
    sudo journalctl -u kubelet --no-pager | tail -30
    df -h ; free -m ; exit
    ```

    Or start a debug Pod on the node:

    ```bash
    kubectl debug node/minikube -it --image=busybox:1.36
    # node files are under /host ; exit
    ```

14. Clean up:

    ```bash
    kubectl delete -f troubleshooting/broken.yaml --ignore-not-found
    kubectl delete pod crashy-debug --ignore-not-found
    kubectl delete configmap app-config
    kubectl get pods -o name | grep node-debugger | xargs kubectl delete
    ```

    (`kubectl debug node/...` leaves a `node-debugger-...` Pod behind.)

---

## 6. Common mistakes & troubleshooting

- Reading only `kubectl get`. The STATUS is a hint; the EVENTS give the real reason. Always run describe.
- Forgetting `--previous`: `kubectl logs` shows the NEW (empty) container, not the one that crashed.
- Looking in the wrong namespace. Add `-n` or `-A`.
- Liveness probe too strict -> Pod restarts forever (exit 137 without OOMKilled). Check "Liveness probe failed" in events. Add startupProbe or raise `initialDelaySeconds`/`failureThreshold`.
- Running but not READY -> readiness probe fails. The Service sends no traffic to it.
- Stuck Terminating -> check `finalizers` in `-o yaml`. Force delete (`kubectl delete pod x --grace-period=0 --force`) only as a last step.
- DNS problems -> `kubectl run t --rm -it --image=busybox:1.36 --restart=Never -- nslookup kubernetes.default`. Check CoreDNS Pods in kube-system.
- NetworkPolicy blocks traffic ([Network Policies](../network_policies/network_policies.md)). Check: `kubectl get netpol -A`.
- `kubectl get endpoints` prints a deprecation warning since v1.33. Use EndpointSlices instead.
- Changing a Deployment by `kubectl edit` on a Pod -> the change is lost when the Pod is replaced. Edit the Deployment.

---

## 7. Cheat sheet

| Command | Purpose |
|---|---|
| `kubectl get pods -o wide` | status, node, IP |
| `kubectl get pods -A \| grep -v Running` | find bad Pods fast |
| `kubectl describe pod <pod>` | events and states |
| `kubectl logs <pod> --previous` | crashed container logs |
| `kubectl get events --sort-by=.lastTimestamp` | what just happened |
| `kubectl get events -A --field-selector type=Warning` | only warnings |
| `kubectl get pod <pod> -o yaml` | full spec and status |
| `kubectl exec -it <pod> -- sh` | shell in container |
| `kubectl debug -it <pod> --image=busybox:1.36 --target=<container>` | ephemeral debug container |
| `kubectl debug <pod> -it --copy-to=<copy> --container=<c> -- sh` | debug a copy |
| `kubectl debug node/<node> -it --image=busybox:1.36` | debug a node |
| `kubectl get endpointslices -l kubernetes.io/service-name=<svc>` | Service backends |
| `kubectl describe node <node>` | node conditions |
| `kubectl top pods` / `kubectl top nodes` | resource use |
| `kubectl rollout history deploy/<name>` | what changed |
| `kubectl rollout undo deploy/<name>` | go back |
| `kubectl auth can-i <verb> <resource>` | RBAC problems |
| `minikube ssh` | shell on the node |
| `minikube logs` | Minikube/cluster logs |

---

## 8. Practice tasks

1. Change [deployments/nginx-deployments.yaml](../deployments/nginx-deployments.yaml) image to `nginx:1.27.2x`. Apply it. Find the error in 2 commands. Fix it with `rollout undo`.
2. Add a liveness probe on port 81 to nginx. Watch the restarts. What does describe say? Fix the port.
3. Scale nginx to 20 replicas with requests `cpu: 500m`. How many are Pending and why?
4. Break the nginx-service targetPort (set 81). Find the problem from inside a busybox Pod.
5. Run `kubectl debug` with `--target` on an nginx Pod and list the nginx processes with `ps`.

---

## 9. Quiz

1. A Pod shows CrashLoopBackOff. Which 2 commands do you run first?
2. Exit code 137 and reason OOMKilled. What does it mean and what can you do?
3. What is the difference between ErrImagePull and ImagePullBackOff?
4. A Service exists but has no endpoints. Name 2 possible causes.
5. The image has no shell. How can you still debug inside the Pod?

<details>
<summary>Quiz answers</summary>

1. `kubectl describe pod <pod>` and `kubectl logs <pod> --previous`
2. The container used more memory than its limit and the kernel killed it. Raise the memory limit or fix the app's memory use.
3. ErrImagePull is the first pull failure. ImagePullBackOff means Kubernetes is waiting (with growing delay) before trying again.
4. Any 2: selector does not match Pod labels; Pods are not READY; no Pods are running; wrong namespace.
5. Use an ephemeral container: `kubectl debug -it <pod> --image=busybox:1.36 --target=<container>`

</details>

---

**Previous:** [Monitoring & Logging](../monitoring_logging/monitoring_logging.md) | **Next:** [Production Best Practices](../production_best_practices/production_best_practices.md) | [Back to README](../README.md)
