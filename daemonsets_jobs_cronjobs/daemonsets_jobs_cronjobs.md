# Topic 13: DaemonSets, Jobs & CronJobs

| | |
|---|---|
| **Level** | Intermediate |
| **Time** | ~45 min |
| **Prereqs** | [Pods](../pod/pod.md), [Deployments](../deployments/deployments.md), [Namespaces](../namespaces/namespaces.md) |
| **Files** | [`daemonsets_jobs_cronjobs/daemonset.yaml`](daemonset.yaml), [`daemonsets_jobs_cronjobs/job.yaml`](job.yaml), [`daemonsets_jobs_cronjobs/cronjob.yaml`](cronjob.yaml) |

> Run all commands from the repo root.

---

## 1. What is it?

Three more workload controllers. Each one is good for a different job:

| Controller | What it does | Example |
|---|---|---|
| **DaemonSet** | Runs ONE Pod on EVERY node (or on selected nodes). New node joins -> it gets the Pod automatically. | Log collector, node agent |
| **Job** | Runs Pods until a task FINISHES successfully, then stops. | A database migration, a batch report |
| **CronJob** | Creates a Job on a SCHEDULE (cron format). | A backup every night at 02:00 |

Compare:

| Controller | Runs |
|---|---|
| Deployment | N copies forever (web apps) |
| StatefulSet | N copies forever, each with identity (databases) |
| DaemonSet | 1 copy per node forever (node agents) |
| Job | To completion once |
| CronJob | To completion again and again on a schedule |

---

## 2. Why do we need it?

**DaemonSet use cases:**

- log collectors (Fluent Bit, Promtail, Vector)
- monitoring agents (Prometheus node-exporter, Datadog agent)
- network plugins (Calico, Cilium) and kube-proxy itself
- storage drivers (CSI node plugins)

**Job use cases:**

- DB schema migration before a release
- process a batch of files / images
- one-time data import

**CronJob use cases:**

- nightly backups (mongodump, pg_dump)
- clean old data every hour
- send a daily report

---

## 3. Key concepts

### DaemonSet

- **a)** No `replicas` field. The number of Pods = number of matching nodes.
- **b)** `nodeSelector` / affinity -> run only on some nodes.
- **c)** `tolerations` -> also run on tainted nodes (like control-plane nodes). On Minikube the single node is not tainted, so you see 1 Pod.
- **d)** `updateStrategy`: `RollingUpdate` (default, `maxUnavailable: 1`) or `OnDelete`.

### Job

| Field | Meaning |
|---|---|
| **e)** `completions` | How many successful Pods are needed (default 1) |
| **f)** `parallelism` | How many Pods run at the same time (default 1) |
| **g)** `backoffLimit` | How many retries before the Job is "Failed" (default 6). Retries wait longer each time (10s, 20s, 40s ... max 6m) |
| **h)** `activeDeadlineSeconds` | Max total run time. After it, the Job fails |
| **i)** `restartPolicy` | Must be `OnFailure` or `Never` (NOT `Always`) |
| **j)** `ttlSecondsAfterFinished` | Delete the Job (and its Pods) N seconds after it finishes. Keeps the cluster clean |
| **k)** `completionMode: Indexed` | Each Pod gets an index 0..N-1 in env `JOB_COMPLETION_INDEX`. Good for splitting work |

About `restartPolicy`:

- `Never`: a failed Pod stays; a NEW Pod is created for the retry. Good for reading logs of failed tries.
- `OnFailure`: the same Pod restarts the container.

### CronJob

**l)** `schedule` uses standard cron: `MIN HOUR DAY-OF-MONTH MONTH DAY-OF-WEEK`

| Schedule | Meaning |
|---|---|
| `*/5 * * * *` | Every 5 minutes |
| `0 2 * * *` | Every day at 02:00 |
| `0 9 * * 1-5` | 09:00 Monday to Friday |

Also macros: `@hourly`, `@daily`, `@weekly`, `@monthly`.

**m)** `timeZone: "Asia/Dhaka"` (stable since v1.27). Without it, the kube-controller-manager time zone is used (usually UTC).

**n)** `concurrencyPolicy`:

| Value | Behaviour |
|---|---|
| `Allow` (default) | New Job can run while the old one still runs |
| `Forbid` | Skip the new run if the old one still runs |
| `Replace` | Stop the old one, start the new one |

**o)** `successfulJobsHistoryLimit` (default 3), `failedJobsHistoryLimit` (default 1) -> how many old Jobs to keep.

**p)** `startingDeadlineSeconds` -> if a run is missed (controller down), how late it may still start.

**q)** `suspend: true` -> pause the CronJob (no new Jobs).

---

## 4. Example YAML

### [`daemonsets_jobs_cronjobs/daemonset.yaml`](daemonset.yaml): a tiny "node agent" that prints the node name

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-agent
  namespace: kube-system       # agents often live here; any ns works
spec:
  selector:
    matchLabels:
      app: node-agent
  template:
    metadata:
      labels:
        app: node-agent        # must match selector
    spec:
      tolerations:             # also run on control-plane nodes
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      containers:
        - name: agent
          image: busybox:1.36
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName   # Downward API: my node
          command: ["sh", "-c",
            "while true; do echo agent on $NODE_NAME; sleep 30; done"]
          resources:
            requests: {cpu: 10m, memory: 16Mi}
            limits:   {cpu: 50m, memory: 32Mi}
          volumeMounts:
            - name: varlog
              mountPath: /host/var/log       # read node logs
              readOnly: true
      volumes:
        - name: varlog
          hostPath:
            path: /var/log                   # folder on the node
```

### [`daemonsets_jobs_cronjobs/job.yaml`](job.yaml): compute pi, 3 successful runs, 2 at a time

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  completions: 3               # need 3 successful Pods
  parallelism: 2               # run 2 at the same time
  backoffLimit: 4              # retry max 4 times
  activeDeadlineSeconds: 300   # whole Job must end in 5 minutes
  ttlSecondsAfterFinished: 600 # auto-delete 10 min after finish
  template:
    spec:
      restartPolicy: Never     # Job Pods: Never or OnFailure only
      containers:
        - name: pi
          image: perl:5.40
          command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(500)"]
```

### [`daemonsets_jobs_cronjobs/cronjob.yaml`](cronjob.yaml): runs every minute

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"      # every minute
  timeZone: "Etc/UTC"          # optional, IANA name
  concurrencyPolicy: Forbid    # never two runs at the same time
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  startingDeadlineSeconds: 60
  jobTemplate:                 # this is a Job spec
    spec:
      backoffLimit: 2
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: hello
              image: busybox:1.36
              command: ["sh", "-c", "date; echo Hello from CronJob"]
```

### Real-life idea: nightly mongo backup (sketch)

- schedule `"0 2 * * *"`, image `mongo:7.0`
- command: `mongodump --uri=mongodb://mongo-0.mongo:27017 --out=/backup`
- with `/backup` mounted from a PVC.

---

## 5. Hands-on lab

### Step 1: Create the DaemonSet

```bash
kubectl apply -f daemonsets_jobs_cronjobs/daemonset.yaml
kubectl get ds -n kube-system
# -> node-agent   DESIRED 1   CURRENT 1   READY 1
#    (also see kube-proxy: it is a DaemonSet too)
```

### Step 2: Read its logs

```bash
kubectl logs -n kube-system -l app=node-agent
# -> agent on minikube
```

### Step 3: (Optional) Add a node and see a new Pod

```bash
minikube node add
kubectl get pods -n kube-system -l app=node-agent -o wide
# -> 2 Pods, one per node (minikube, minikube-m02).
minikube node delete minikube-m02
```

### Step 4: Run the Job and watch

```bash
kubectl apply -f daemonsets_jobs_cronjobs/job.yaml
kubectl get pods -l job-name=pi -w
# -> 2 Pods Running, then Completed, then the third one. Ctrl+C.
kubectl get job pi
# -> STATUS Complete   COMPLETIONS 3/3
```

### Step 5: Read the result

```bash
kubectl logs job/pi
# -> 3.14159265358979323846...
```

### Step 6: A failing Job

```bash
kubectl create job fail --image=busybox:1.36 -- sh -c "exit 1"
kubectl get pods -l job-name=fail -w
# -> Pods with STATUS Error, new ones after a backoff.
```

The default `backoffLimit` is 6 and the wait doubles each time, so this takes several minutes. Then:

```bash
kubectl describe job fail | tail -5
# -> "Job has reached the specified backoff limit"
```

### Step 7: Create the CronJob

```bash
kubectl apply -f daemonsets_jobs_cronjobs/cronjob.yaml
kubectl get cronjob hello
# -> SCHEDULE */1 * * * *   SUSPEND False   ACTIVE 0
```

Wait 2-3 minutes:

```bash
kubectl get jobs
# -> hello-29xxxxxx  Complete ...   (name = time-based number)
```

### Step 8: Run a CronJob now, without waiting

```bash
kubectl create job hello-manual --from=cronjob/hello
kubectl logs job/hello-manual
```

### Step 9: Pause and resume

```bash
kubectl patch cronjob hello -p '{"spec":{"suspend":true}}'
kubectl patch cronjob hello -p '{"spec":{"suspend":false}}'
```

### Step 10: Clean up

```bash
kubectl delete -f daemonsets_jobs_cronjobs/daemonset.yaml \
  -f daemonsets_jobs_cronjobs/job.yaml \
  -f daemonsets_jobs_cronjobs/cronjob.yaml
kubectl delete job fail hello-manual
```

---

## 6. Common mistakes & troubleshooting

- **"Unsupported value: Always" for a Job**
  - Job Pods need `restartPolicy` `Never` or `OnFailure`.
- **Job never finishes**
  - The container never exits (for example a web server). Jobs are only for programs that END. Use `activeDeadlineSeconds` as a guard.
- **Too many old Pods/Jobs everywhere**
  - Use `ttlSecondsAfterFinished` for Jobs and history limits for CronJobs.
- **CronJob did not run at the time I expected**
  - Time zone. Without `timeZone` it is the controller's zone (often UTC). Check `LAST SCHEDULE` in `kubectl get cronjob`.
- **Two backup runs at the same time corrupt data**
  - `concurrencyPolicy: Forbid`.
- **CronJob stopped running after downtime: "too many missed start times"**
  - More than 100 missed schedules. Set `startingDeadlineSeconds`.
- **DaemonSet has DESIRED 3 but CURRENT 2**
  - A node has a taint and the DaemonSet has no matching toleration, or the node does not have enough CPU/memory. `kubectl describe ds`.
- **Job can run more than once!**
  - Kubernetes Jobs are "at least once". Make your task idempotent (safe to run twice).

---

## 7. Cheat sheet

| Command | What it does |
|---|---|
| `kubectl get ds -A` | DaemonSets in all namespaces |
| `kubectl rollout status ds/NAME -n NS` | Watch a DaemonSet update |
| `kubectl rollout restart ds/NAME -n NS` | Restart all its Pods |
| `kubectl create job NAME --image=IMG -- CMD` | Quick Job |
| `kubectl get jobs` | List Jobs |
| `kubectl logs job/NAME` | Logs of a Job Pod |
| `kubectl get pods -l job-name=NAME` | Pods of a Job |
| `kubectl delete job NAME` | Delete Job and its Pods |
| `kubectl create cronjob NAME --image=IMG --schedule="*/5 * * * *" -- CMD` | Quick CronJob |
| `kubectl get cj` | List CronJobs |
| `kubectl create job X --from=cronjob/NAME` | Trigger a CronJob now |
| `kubectl patch cj NAME -p '{"spec":{"suspend":true}}'` | Pause a CronJob |

---

## 8. Practice tasks

1. Make a DaemonSet that runs only on nodes with label `disk=ssd`. Label the minikube node and see the Pod appear. Remove the label and see it go away.
2. Make a Job with `completions: 6`, `parallelism: 3`, and `completionMode: Indexed`. Each Pod prints "I am task $JOB_COMPLETION_INDEX". Check the logs.
3. Make a CronJob that runs every 2 minutes and prints the date in the `Asia/Dhaka` time zone (use `timeZone`). Keep only 2 successful Jobs.
4. Make a Job that sleeps 120 seconds with `activeDeadlineSeconds: 30`. What is the final status and reason?
5. Write a CronJob that runs `mongodump` against the StatefulSet from [Topic 12: StatefulSets](../statefulset/statefulset.md) every night at 02:00 and saves to a PVC.

---

## 9. Quiz

1. A DaemonSet runs on a 4-node cluster with no taints. How many Pods?
2. Which `restartPolicy` values are allowed in a Job Pod?
3. What does the cron `0 2 * * *` mean?
4. Which `concurrencyPolicy` skips a new run if the old one is still running?
5. What does `ttlSecondsAfterFinished` do?

<details><summary>Quiz answers</summary>

1. 4 (one per node).
2. `Never` and `OnFailure`.
3. Every day at 02:00 (in the CronJob's time zone).
4. `Forbid`.
5. It deletes the finished Job (and its Pods) after that many seconds.

</details>

---

**Previous:** [Topic 12: StatefulSets](../statefulset/statefulset.md) | **Next:** [Topic 14: Ingress](../ingress/ingress.md) | [Back to README](../README.md)
