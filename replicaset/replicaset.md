# Topic 06: ReplicaSets

| | |
|---|---|
| **Level** | Beginner |
| **Time** | ~40 min |
| **Prereqs** | [Topic 04: Pods](../pod/pod.md), [Topic 05: Labels, selectors, annotations](../labels_selectors/labels_selectors.md) |
| **Files** | [`nginx-replicaset.yaml`](nginx-replicaset.yaml) |

> Run all commands from the repo root.

---

## 1. What is it?

A **ReplicaSet** (RS) makes sure that a fixed number of identical Pods is
running at all times. You say "I want 3 replicas". The ReplicaSet
creates Pods until there are 3. If one dies, it creates a new one. If
there are too many, it deletes the extra ones.

It finds "its" Pods using a label **selector**.

---

## 2. Why do we need it?

Bare Pods do not heal ([Topic 04](../pod/pod.md)). A ReplicaSet gives you:

- **Self-healing**: a deleted or failed Pod is replaced.
- **Scaling**: change one number to get more or fewer Pods.
- **High availability**: many copies, so one failure is not an outage.

BUT: in real life you almost never create ReplicaSets directly. You
create a **Deployment** ([Topic 07](../deployments/deployments.md)), and the Deployment creates and manages
ReplicaSets for you. Deployments add rolling updates and rollbacks.
We learn ReplicaSets so you understand what a Deployment does inside.

Old name: ReplicationController (RC). It is legacy. Do not use it.

---

## 3. Key concepts

**Three main parts of `spec`**

| Field | Meaning |
|-------|---------|
| `replicas` | How many Pods you want (default 1) |
| `selector` | Which Pods belong to this RS (by label) |
| `template` | The Pod "cookie cutter" used to create new Pods |

**Rule: template labels MUST match the selector**
Otherwise the API rejects the RS (it would create Pods it cannot see).

**Control loop**

```text
current = count Pods that match selector (and are not being deleted)
if current < replicas -> create Pods from template
if current > replicas -> delete some Pods
```

**Owner references**
Each Pod created by an RS has `metadata.ownerReferences` pointing to
the RS. When you delete the RS, its Pods are deleted too (cascading
delete).

**Adoption (be careful)**
An RS also "adopts" EXISTING bare Pods that match its selector and
have no owner. So if `nginx-pod` (label `app=nginx`) is running, a new RS
with selector `app=nginx` counts it as one of its replicas!

**Template changes do not update existing Pods**
If you change the image in the RS template, old Pods keep the old
image. Only NEW Pods use the new template. This is why we need
Deployments for updates.

**Pod names**
`<rs-name>-<random 5 chars>`, for example `nginx-replicaset-7xk2p`.

---

## 4. Example YAML

The repo file [`replicaset/nginx-replicaset.yaml`](nginx-replicaset.yaml) with comments. It:

- Deploys **3 Pods** of the `nginx:latest` container
- Uses the label `app: nginx` to identify and manage Pods
- Exposes **port 80** inside each container

```yaml
apiVersion: apps/v1            # ReplicaSet is in the "apps" API group
kind: ReplicaSet
metadata:
  name: nginx-replicaset       # RS name; Pods get this as a prefix
  labels:
    app: nginx                 # label on the RS object itself
spec:
  replicas: 3                  # desired number of Pods
  selector:                    # how the RS finds its Pods
    matchLabels:
      app: nginx               # must match template labels below
  template:                    # Pod template (same as a Pod, no name)
    metadata:
      labels:
        app: nginx             # every new Pod gets this label
    spec:
      containers:
      - name: nginx-container
        image: nginx:latest    # repo uses latest; prefer nginx:1.27
        ports:
        - containerPort: 80
```

A better version with a pinned tag and a more unique selector:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: web-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
      component: frontend      # extra label = less chance to adopt
  template:                    #   unrelated Pods by accident
    metadata:
      labels:
        app: web
        component: frontend
    spec:
      containers:
      - name: web
        image: nginx:1.27      # pinned: every replica runs the same
```

---

## 5. Hands-on lab

**Step 0. Start clean (avoid adoption surprises)**

```bash
kubectl get pods -l app=nginx
# If nginx-pod exists:
kubectl delete pod nginx-pod
```

**Step 1. Create the ReplicaSet**

```bash
kubectl apply -f replicaset/nginx-replicaset.yaml
kubectl get rs
```

You should see: `nginx-replicaset   DESIRED 3   CURRENT 3   READY 3`

```bash
kubectl get pods -l app=nginx
```

You should see: 3 Pods named `nginx-replicaset-xxxxx`

**Step 2. Self-healing**

```bash
kubectl delete pod <one-of-the-pod-names>
kubectl get pods -l app=nginx
```

You should see: a NEW Pod with a new name and small AGE. Still 3.

**Step 3. Scale imperatively**

```bash
kubectl scale rs nginx-replicaset --replicas=5
kubectl get pods -l app=nginx
```

You should see: 5 Pods.

**Step 4. Scale declaratively (the better way)**

Edit `replicaset/nginx-replicaset.yaml` locally: `replicas: 2`

```bash
kubectl apply -f replicaset/nginx-replicaset.yaml
```

You should see: 3 Pods Terminating, 2 left.
(Change the file back to 3 when done, to keep the repo clean.)

**Step 5. See the owner reference**

```bash
kubectl get pod <pod-name> -o jsonpath='{.metadata.ownerReferences[0].name}'
```

You should see: `nginx-replicaset`

**Step 6. Adoption demo**

```bash
kubectl run extra --image=nginx:1.27 --labels=app=nginx
kubectl get pods -l app=nginx
```

You should see: one Pod Terminating (usually `extra`, because it is
the newest). The RS adopted `extra`, found 4 Pods, and deleted one.

**Step 7. Template change does NOT roll out**

```bash
kubectl set image rs/nginx-replicaset nginx-container=nginx:1.27
kubectl get pods -l app=nginx \
  -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image
```

You should see: Pods still use `nginx:latest`.

```bash
kubectl delete pod <one-pod>
```

Run the get again: only the NEW Pod has `nginx:1.27`.

**Step 8. Remove a Pod from the RS by changing its label**

```bash
kubectl label pod <one-pod> app=debug --overwrite
kubectl get pods --show-labels
```

You should see: the RS created a replacement; the relabeled Pod
keeps running alone (now an orphan you can debug).

**Step 9. Clean up**

```bash
kubectl delete rs nginx-replicaset      # or: kubectl delete -f replicaset/nginx-replicaset.yaml
kubectl delete pod -l app=debug
```

Tip: `kubectl delete rs X --cascade=orphan` deletes only the RS and
leaves Pods running.

---

## 6. Common mistakes & troubleshooting

| Problem | Cause / Fix |
|---------|-------------|
| "selector does not match template labels" | Make `spec.selector.matchLabels` a subset of template labels. |
| RS has fewer Pods than expected / Pods disappear | An old bare Pod with the same labels was adopted. Use unique labels. |
| RS created, but 0 Pods | Check events: `kubectl describe rs <name>`. Often a quota, a bad Pod spec, or an admission error. |
| Changed image but Pods did not update | Expected. RS does not do rolling updates. Use a Deployment. |
| Pods keep restarting but RS shows READY < DESIRED | That is a Pod problem, not an RS problem. Check logs/describe of the Pods (`CrashLoopBackOff`, `ImagePullBackOff`...). |
| Using ReplicationController | Legacy. Use Deployment (or ReplicaSet only for learning). |

---

## 7. Cheat sheet

| Command | What it does |
|---------|--------------|
| `kubectl apply -f replicaset/nginx-replicaset.yaml` | Create/update RS |
| `kubectl get rs [-o wide]` | List RS (wide: images, selector) |
| `kubectl describe rs <name>` | Details + events |
| `kubectl scale rs <name> --replicas=5` | Change replica count |
| `kubectl get pods -l app=nginx` | Pods of the RS |
| `kubectl delete pod <pod-name>` | Delete a Pod (RS recreates it) |
| `kubectl delete rs <name>` | Delete RS and its Pods |
| `kubectl delete rs <name> --cascade=orphan` | Delete RS, keep Pods |
| `kubectl get pod <p> -o jsonpath='{.metadata.ownerReferences}'` | Who owns this Pod |

---

## 8. Practice tasks

1. Write an RS `api-rs` with 2 replicas of `httpd:2.4` and labels
   `app=api`, `tier=backend`. Apply it and check it.
2. Scale it to 4 with kubectl, then back to 2 with the YAML file.
3. Delete the RS with `--cascade=orphan`. Then create it again. What
   happens to the old Pods? (Hint: adoption.)
4. Try to create an RS where the selector is `app=a` but the template
   label is `app=b`. Read the error.
5. Explain in your own words why a Deployment is better than an RS.

---

## 9. Quiz

1. What are the three main fields in a ReplicaSet spec?
2. What happens if you delete one Pod of a ReplicaSet with 3 replicas?
3. You change the image in the RS template. Do running Pods change?
4. What is "adoption"?
5. Which object should you normally use instead of a ReplicaSet?

<details><summary>Quiz answers</summary>

1. `replicas`, `selector`, `template`.
2. The RS sees only 2 Pods and creates a new one to get back to 3.
3. No. Only new Pods use the new template.
4. An RS takes ownership of existing Pods that match its selector and
   have no owner, and counts them as replicas.
5. A Deployment (it manages ReplicaSets and adds rolling updates and
   rollbacks).

</details>

---

## 10. Next topic

[Topic 07: Deployments](../deployments/deployments.md)

---

**Previous:** [Topic 05: Labels, selectors, annotations](../labels_selectors/labels_selectors.md) | **Next:** [Topic 07: Deployments](../deployments/deployments.md) | [Back to README](../README.md)
