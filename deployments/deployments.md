# Topic 07: Deployments

| | |
|---|---|
| **Level** | Beginner |
| **Time** | ~45 min |
| **Prereqs** | [Topic 04: Pods](../pod/pod.md), [Topic 06: ReplicaSets](../replicaset/replicaset.md) |
| **Files** | [`nginx-deployments.yaml`](nginx-deployments.yaml), [`web-deploy.yaml`](web-deploy.yaml) |

> Run all commands from the repo root.

---

## 1. What is it?

A **Deployment** manages ReplicaSets, and ReplicaSets manage Pods:

```text
Deployment  --->  ReplicaSet (one per version)  --->  Pods
```

You describe the desired version and number of Pods. When you change
the Pod template (for example a new image), the Deployment creates a NEW
ReplicaSet and slowly moves Pods from the old one to the new one. This
is a **rolling update**. If something goes wrong, you can **roll back**.

Deployments are the standard way to run STATELESS apps (web servers,
APIs, workers).

---

## 2. Why do we need it?

A ReplicaSet keeps N Pods alive, but cannot update them ([Topic 06](../replicaset/replicaset.md)).
A Deployment adds:

- Zero-downtime rolling updates
- Rollback to an earlier version (revision history)
- Pause and resume of rollouts
- Scaling (it passes the number to its ReplicaSet)
- Declarative updates: change YAML, run `kubectl apply`, done

### Deployment vs ReplicaSet vs Pod

| Feature | Pod | ReplicaSet | Deployment |
|---------|-----|------------|------------|
| Self-healing | No | Yes | Yes |
| Scaling | No | Yes | Yes |
| Rolling updates | No | No | Yes |
| Rollback support | No | No | Yes |
| Declarative updates | No | No | Yes |

---

## 3. Key concepts

**Revision**
Every change to `spec.template` creates a new revision and a new
ReplicaSet. Changing only `replicas` does NOT create a revision.

**`pod-template-hash`**
A label Kubernetes adds to Pods and ReplicaSets so each RS only
owns Pods of its own version. You see it in `--show-labels`.

**Strategy types** (`spec.strategy.type`)

| Type | Behavior |
|------|----------|
| `RollingUpdate` (default) | Replace Pods step by step. No downtime. |
| `Recreate` | Delete ALL old Pods first, then create new. Short downtime. Use when two versions must never run at the same time. |

**Rolling update settings**

| Setting | Meaning | Default |
|---------|---------|---------|
| `maxSurge` | How many EXTRA Pods (above replicas) may exist during the update. Number or %. | 25% |
| `maxUnavailable` | How many Pods may be NOT ready during the update. Number or %. | 25% |

- Example with `replicas=4, maxSurge=1, maxUnavailable=0`:
  at most 5 Pods total, never fewer than 4 ready. Safest, slower.
- Example with `replicas=4, maxSurge=0, maxUnavailable=1`:
  never more than 4 Pods, may drop to 3 ready. Saves resources.
- Both cannot be 0 at the same time.
- Percentages: `maxSurge` rounds UP, `maxUnavailable` rounds DOWN.

**Other useful fields**

| Field | Meaning | Default |
|-------|---------|---------|
| `minReadySeconds` | A new Pod must be Ready this long before it counts as available | 0 |
| `revisionHistoryLimit` | How many old ReplicaSets to keep for rollback | 10 |
| `progressDeadlineSeconds` | Mark rollout as failed if no progress in this time | 600 |

**Change-cause**
`kubectl rollout history` shows a CHANGE-CAUSE column. It reads the
annotation `kubernetes.io/change-cause`. The old `--record` flag is
DEPRECATED. Set the annotation yourself:

```bash
kubectl annotate deployment/nginx-deployment \
  kubernetes.io/change-cause="update to nginx 1.25"
```

Or put it in YAML under `metadata.annotations`.

**Rollback**
`kubectl rollout undo` makes the old ReplicaSet the active one again.
It is fast because the old RS still exists (scaled to 0).

**Readiness matters**
A rolling update only moves on when new Pods are READY. Without a
readiness probe ([Topic 15](../probes_resources/probes_resources.md)), "Ready" just means "container started",
so a broken app may still roll out. Add probes in real apps.

---

## 4. Example YAML

### A) The repo file [`deployments/nginx-deployments.yaml`](nginx-deployments.yaml) with comments

It defines a Deployment named `nginx-deployment` with 3 replicas of an NGINX
container, label selector `app: nginx`, image `nginx:latest`.

```yaml
apiVersion: apps/v1              # Deployments are in the "apps" group
kind: Deployment
metadata:
  name: nginx-deployment         # Deployment name
  labels:
    app: nginx
spec:
  replicas: 3                    # desired Pod count
  selector:
    matchLabels:
      app: nginx                 # IMMUTABLE after creation
  template:                      # Pod template; any change = new revision
    metadata:
      labels:
        app: nginx               # must match the selector
    spec:
      containers:
      - name: nginx-container    # used by "kubectl set image"
        image: nginx:latest      # repo uses latest; prefer pinned tags
        ports:
        - containerPort: 80
```

### B) A production-style version

Saved as [`deployments/web-deploy.yaml`](web-deploy.yaml):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
  annotations:
    kubernetes.io/change-cause: "initial release nginx 1.26"
spec:
  replicas: 4
  revisionHistoryLimit: 5          # keep 5 old RS for rollback
  minReadySeconds: 5               # Pod must stay Ready 5s to count
  progressDeadlineSeconds: 120     # fail rollout after 2 min stuck
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1                  # max 5 Pods during update
      maxUnavailable: 0            # never less than 4 ready Pods
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: nginx:1.26          # pinned; "latest" breaks rollback
        ports:
        - containerPort: 80
        readinessProbe:            # only send traffic when ready
          httpGet:
            path: /
            port: 80
          periodSeconds: 5
```

**Why `latest` is extra bad for Deployments:** if you change nothing in the
template but `latest` moves to a new version, Kubernetes does NOT see a
change, so no rollout happens. And new Pods (after a crash) may run a
different version than old Pods. Rollback to `latest` does not bring
back the old code either.

---

## 5. Hands-on lab

**Step 0. Clean up old labs (avoid label conflicts)**

```bash
kubectl delete rs nginx-replicaset --ignore-not-found
kubectl delete pod nginx-pod --ignore-not-found
```

**Step 1. Create the Deployment**

```bash
kubectl apply -f deployments/nginx-deployments.yaml
kubectl get deploy,rs,pods -l app=nginx
```

You should see: deployment READY `3/3`, one ReplicaSet
`nginx-deployment-<hash>`, three Pods `nginx-deployment-<hash>-<id>`.

**Step 2. Pin a known version and record why**

```bash
kubectl set image deployment/nginx-deployment nginx-container=nginx:1.25
kubectl annotate deployment/nginx-deployment \
  kubernetes.io/change-cause="pin image to nginx 1.25" --overwrite
kubectl rollout status deployment/nginx-deployment
```

You should see: `deployment "nginx-deployment" successfully rolled out`

**Step 3. Watch a rolling update (open 2 terminals)**

Terminal 1:

```bash
kubectl get pods -l app=nginx -w
```

Terminal 2:

```bash
kubectl set image deployment/nginx-deployment nginx-container=nginx:1.27
kubectl annotate deployment/nginx-deployment \
  kubernetes.io/change-cause="update to nginx 1.27" --overwrite
```

In terminal 1 you should see: new Pods created, old Pods Terminating,
a few at a time (default maxSurge 25%, maxUnavailable 25%).

**Step 4. Look at ReplicaSets and history**

```bash
kubectl get rs -l app=nginx
```

You should see: the new RS with 3 Pods, old ones with 0.

```bash
kubectl rollout history deployment/nginx-deployment
```

You should see: REVISION numbers and your CHANGE-CAUSE texts.

```bash
kubectl rollout history deployment/nginx-deployment --revision=2
```

**Step 5. Make a bad update**

```bash
kubectl set image deployment/nginx-deployment nginx-container=nginx:9.99-bad
kubectl annotate deployment/nginx-deployment \
  kubernetes.io/change-cause="bad image test" --overwrite
kubectl rollout status deployment/nginx-deployment --timeout=60s
kubectl get pods -l app=nginx
```

You should see: new Pods in `ErrImagePull` / `ImagePullBackOff`, but most
OLD Pods still Running. The app keeps working. This is the power of
`maxUnavailable`.

**Step 6. Roll back**

```bash
kubectl rollout undo deployment/nginx-deployment
kubectl rollout status deployment/nginx-deployment
kubectl get deploy nginx-deployment \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

You should see: `nginx:1.27`. Roll back to a specific revision:

```bash
kubectl rollout undo deployment/nginx-deployment --to-revision=2
```

**Step 7. Scale**

```bash
kubectl scale deployment/nginx-deployment --replicas=5
kubectl get deploy nginx-deployment
```

Check history: scaling did NOT add a revision.

**Step 8. Pause, make many changes, resume (one rollout)**

```bash
kubectl rollout pause deployment/nginx-deployment
kubectl set image deployment/nginx-deployment nginx-container=nginx:1.27
kubectl set resources deployment/nginx-deployment \
  -c nginx-container --requests=cpu=50m,memory=64Mi
kubectl rollout resume deployment/nginx-deployment
kubectl rollout status deployment/nginx-deployment
```

**Step 9. Restart all Pods (for example to reload config)**

```bash
kubectl rollout restart deployment/nginx-deployment
```

**Step 10. Try your own strategy**

```bash
kubectl apply -f deployments/web-deploy.yaml
```

Edit the image to `nginx:1.27` and change the change-cause annotation in
`deployments/web-deploy.yaml`, then:

```bash
kubectl apply -f deployments/web-deploy.yaml
kubectl get pods -l app=web -w
```

You should see: one extra Pod at a time; ready count never below 4.
(Change the file back when done, to keep the repo clean.)

**Step 11. Clean up**

```bash
kubectl delete -f deployments/nginx-deployments.yaml
kubectl delete -f deployments/web-deploy.yaml
```

---

## 6. Common mistakes & troubleshooting

| Problem | Cause / Fix |
|---------|-------------|
| Using the wrong container name in `kubectl set image` | Format is `<container-name>=<image>`. In the repo file the container is `nginx-container`, NOT `nginx`. Check with `kubectl get deploy nginx-deployment -o jsonpath='{.spec.template.spec.containers[*].name}'` |
| Using `--record` | Deprecated. Use the `kubernetes.io/change-cause` annotation. |
| Rollout stuck (`Waiting for deployment ... rollout to finish`) | New Pods are not Ready. Check `kubectl describe deploy <name>` (Conditions), `kubectl get pods`, `kubectl describe pod <new-pod>`. Fix the problem or `kubectl rollout undo`. |
| `ProgressDeadlineExceeded` in conditions | No progress within `progressDeadlineSeconds`. Same fix as above. Note: Kubernetes does NOT auto-rollback. You must undo. |
| Changing `spec.selector` | Not allowed (immutable). Delete and recreate the Deployment. |
| `kubectl edit` / `set image`, then `kubectl apply` old YAML | apply puts the OLD image back. Keep YAML in Git as the source of truth. |
| Using `:latest` | No rollout when `latest` changes, mixed versions, useless rollback. |
| Rollout "succeeds" but app is broken | No readiness probe. Add probes ([Topic 15](../probes_resources/probes_resources.md)). |

---

## 7. Cheat sheet

| Command | What it does |
|---------|--------------|
| `kubectl create deployment web --image=nginx:1.27 --replicas=3` | Quick create |
| `kubectl apply -f deployments/nginx-deployments.yaml` | Create/update from YAML |
| `kubectl get deploy [-o wide]` | List Deployments |
| `kubectl describe deploy <name>` | Details, conditions, events |
| `kubectl scale deploy/<name> --replicas=5` | Scale |
| `kubectl set image deploy/<name> <container>=<image>` | Update image (new rollout) |
| `kubectl annotate deploy/<name> kubernetes.io/change-cause="..." --overwrite` | Record why you changed it |
| `kubectl rollout status deploy/<name>` | Wait for rollout to finish |
| `kubectl rollout history deploy/<name>` | List revisions |
| `kubectl rollout history deploy/<name> --revision=N` | Details of one revision |
| `kubectl rollout undo deploy/<name>` | Go back one revision |
| `kubectl rollout undo deploy/<name> --to-revision=N` | Go to revision N |
| `kubectl rollout pause\|resume deploy/<name>` | Pause/resume rollouts |
| `kubectl rollout restart deploy/<name>` | Recreate all Pods gradually |
| `kubectl logs <pod-name>` | Logs from a Pod |
| `kubectl port-forward pod/<pod-name> 8080:80` | Local port to a Pod |
| `kubectl delete -f deployments/nginx-deployments.yaml` | Delete the Deployment |

---

## 8. Practice tasks

1. Create a Deployment `api` with `httpd:2.4.62`, 4 replicas, strategy
   `maxSurge=2`, `maxUnavailable=1`. Update it to `httpd:2.4.63` and watch.
2. Set a change-cause for each update. Show the history with 3+
   revisions. Roll back to revision 1.
3. Change the strategy to `Recreate`. Update the image. What is
   different in `kubectl get pods -w`?
4. Break a rollout with a bad image. Find the reason using only
   `kubectl describe`. Then undo.
5. With `replicas=10, maxSurge=25%, maxUnavailable=25%`, what is the
   maximum Pod count and minimum ready count during an update?

---

## 9. Quiz

1. What is the relationship between Deployment, ReplicaSet and Pod?
2. What do `maxSurge` and `maxUnavailable` control? What are the defaults?
3. Does `kubectl scale` create a new revision?
4. What should you use instead of the deprecated `--record` flag?
5. When is the `Recreate` strategy a good choice?

<details><summary>Quiz answers</summary>

1. A Deployment creates and manages ReplicaSets (one per template
   version). Each ReplicaSet creates and manages Pods.
2. `maxSurge` = how many Pods above `replicas` may exist during the
   update. `maxUnavailable` = how many Pods may be not ready. Both
   default to 25%.
3. No. Only changes to `spec.template` create a revision.
4. The annotation `kubernetes.io/change-cause`, set with
   `kubectl annotate ... --overwrite` or in the YAML.
5. When two versions must never run at the same time (for example a
   database schema change, or an app that locks a shared file), and
   short downtime is OK.

(Practice task 5: max 13 Pods (10 + ceil(2.5)=3), min 8 ready
(10 - floor(2.5)=2).)

</details>

---

## 10. Next topic

[Topic 08: Services](../services/services.md)

---

**Previous:** [Topic 06: ReplicaSets](../replicaset/replicaset.md) | **Next:** [Topic 08: Services](../services/services.md) | [Back to README](../README.md)
