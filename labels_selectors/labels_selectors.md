# Topic 05: Labels, Selectors and Annotations

| | |
|---|---|
| **Level** | Beginner |
| **Time** | ~40 min |
| **Prereqs** | [Topic 04: Pods](../pod/pod.md) |
| **Files** | [`labels-demo.yaml`](labels-demo.yaml), plus [`../pod/nginx-pod.yaml`](../pod/nginx-pod.yaml), [`../replicaset/nginx-replicaset.yaml`](../replicaset/nginx-replicaset.yaml), [`../services/nginx-services.yaml`](../services/nginx-services.yaml) (all use label `app=nginx`) |

> Run all commands from the repo root.

---

## 1. What is it?

**Labels** are key=value pairs you attach to objects. They are for
IDENTIFYING and GROUPING objects. Example: `app=nginx`, `env=prod`.

**Selectors** are queries that FIND objects by their labels. Example:
"give me all Pods where `app=nginx`".

**Annotations** are also key=value pairs, but they are NOT used to select.
They store extra information (notes, tool settings, build info, URLs).

---

## 2. Why do we need it?

Kubernetes connects objects with labels, NOT with names:

- A ReplicaSet/Deployment finds "its" Pods with a selector.
- A Service sends traffic to Pods that match its selector.
- A NetworkPolicy chooses Pods by labels.
- You filter `kubectl get` output by labels.

This loose coupling is powerful. A Service does not care which
Deployment made the Pods. It only cares about labels.

Annotations let tools store data on objects: for example
`kubernetes.io/change-cause` for rollout history, Ingress controller
settings, or Prometheus scrape hints.

---

## 3. Key concepts

### Label rules

- **Key**: optional prefix + name. Example: `app` or `example.com/team`.
  Name max 63 chars, letters, digits, `-`, `_`, `.`.
  Prefixes `kubernetes.io/` and `k8s.io/` are reserved for K8s.
- **Value**: max 63 chars, may be empty.
- Labels are small. Do not put big data in labels.

### Recommended labels (used by many tools)

| Label | Example value |
|-------|---------------|
| `app.kubernetes.io/name` | `nginx` |
| `app.kubernetes.io/instance` | `nginx-prod` |
| `app.kubernetes.io/version` | `"1.27"` |
| `app.kubernetes.io/component` | `web` |
| `app.kubernetes.io/part-of` | `shop` |
| `app.kubernetes.io/managed-by` | `helm` |

Simple labels like `app`, `env`, `tier` are also very common.

### Equality-based selectors

| Selector | Meaning |
|----------|---------|
| `app=nginx` | equal |
| `app!=nginx` | not equal |
| `app=nginx,env=dev` | comma means AND |

### Set-based selectors

| Selector | Meaning |
|----------|---------|
| `env in (dev,test)` | value is one of the list |
| `env notin (prod)` | value is not in the list |
| `tier` | key exists |
| `!tier` | key does not exist |

### Selectors in YAML

Service (only equality, simple map):

```yaml
selector:
  app: nginx
```

ReplicaSet / Deployment / Job / NetworkPolicy (richer):

```yaml
selector:
  matchLabels:
    app: nginx
  matchExpressions:
  - key: env
    operator: In          # In, NotIn, Exists, DoesNotExist
    values: ["dev", "test"]
```

All rules are ANDed together.

### Annotations

Can hold larger values (total size limit 256 KB for all annotations).
Not usable in selectors. Examples:

```yaml
kubernetes.io/change-cause: "update to nginx 1.27"
kubectl.kubernetes.io/last-applied-configuration: ...   # written by apply
description: "Owned by team A, contact a@example.com"
```

### Field selectors (bonus)

Select by some object FIELDS, not labels:

```bash
kubectl get pods --field-selector status.phase=Running
kubectl get pods --field-selector spec.nodeName=minikube
```

---

## 4. Example YAML

Saved as [`labels_selectors/labels-demo.yaml`](labels-demo.yaml):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-dev
  labels:                       # used for grouping and selecting
    app: nginx
    env: dev
    tier: frontend
  annotations:                  # extra info, NOT for selecting
    description: "Dev web server for the labels lab"
    owner: "team-a@example.com"
spec:
  containers:
  - name: nginx
    image: nginx:1.27
---
apiVersion: v1
kind: Pod
metadata:
  name: web-prod
  labels:
    app: nginx
    env: prod
    tier: frontend
spec:
  containers:
  - name: nginx
    image: nginx:1.27
---
apiVersion: v1
kind: Pod
metadata:
  name: db-dev
  labels:
    app: postgres
    env: dev
    tier: backend
spec:
  containers:
  - name: postgres
    image: postgres:16
    env:
    - name: POSTGRES_PASSWORD   # demo only; use a Secret (topic 10)
      value: "demo"
```

> Passwords belong in a Secret: see [Topic 10: ConfigMaps & Secrets](../configmaps_secrets/configmaps_secrets.md).

---

## 5. Hands-on lab

**Step 1. Create the Pods**

```bash
kubectl apply -f labels_selectors/labels-demo.yaml
kubectl get pods --show-labels
```

You should see: 3 Pods, each with its labels in the LABELS column.

**Step 2. Filter with equality selectors**

```bash
kubectl get pods -l app=nginx
# You should see: web-dev, web-prod
kubectl get pods -l env=dev,tier=backend
# You should see: db-dev
kubectl get pods -l 'env!=prod'
# You should see: web-dev, db-dev
```

**Step 3. Filter with set-based selectors**

```bash
kubectl get pods -l 'env in (dev,test)'
kubectl get pods -l 'tier notin (backend)'
kubectl get pods -l '!owner'
```

You should see (last command): all 3 (no Pod has a LABEL `owner`; it is an
annotation on `web-dev`).

**Step 4. Show labels as columns**

```bash
kubectl get pods -L app,env,tier
```

**Step 5. Add, change and remove labels**

```bash
kubectl label pod web-dev version=v1
kubectl label pod web-dev env=staging --overwrite
kubectl label pod web-dev version-
kubectl get pod web-dev --show-labels
```

The `-` at the end removes the label.

**Step 6. Annotations**

```bash
kubectl annotate pod web-prod note="checked by Ali"
kubectl describe pod web-prod | grep -A3 Annotations
kubectl annotate pod web-prod note-
```

**Step 7. See how a Service uses labels**

```bash
kubectl apply -f services/nginx-services.yaml
kubectl get endpointslices -l kubernetes.io/service-name=nginx-service
```

You should see: the IPs of the Pods with `app=nginx` (`web-dev` and
`web-prod`; also `nginx-pod` if it is running).

**Step 8. Remove a Pod from the Service by changing its label**

```bash
kubectl label pod web-prod app=nginx-old --overwrite
kubectl get endpointslices -l kubernetes.io/service-name=nginx-service
```

You should see: `web-prod`'s IP is gone. This trick is useful for
debugging a bad Pod without killing it.

**Step 9. Clean up**

```bash
kubectl delete -f labels_selectors/labels-demo.yaml
kubectl delete -f services/nginx-services.yaml
```

---

## 6. Common mistakes & troubleshooting

| Problem | Cause / Fix |
|---------|-------------|
| Service has no endpoints | Service selector does not match Pod labels (typo, case-sensitive). Compare `kubectl get svc <svc> -o yaml` vs `kubectl get pods --show-labels`. |
| Deployment error "selector does not match template labels" | `spec.selector.matchLabels` must be a subset of `spec.template.metadata.labels`. |
| Trying to change a Deployment selector after creation | `spec.selector` is IMMUTABLE in `apps/v1`. Delete and recreate. |
| Two controllers with overlapping selectors | Two ReplicaSets with the same selector fight over Pods. Use unique labels per app (for example app + component). |
| Using annotations in selectors | Does not work. Only labels can be selected. |
| Forgetting quotes in shell | `kubectl get pods -l env in (dev,test)` -> shell error. Use quotes: `-l 'env in (dev,test)'` |
| Number-like values in YAML | `version: 1.27` is a number in YAML. Labels need strings. Write `version: "1.27"`. |

---

## 7. Cheat sheet

| Command | What it does |
|---------|--------------|
| `kubectl get pods --show-labels` | Show all labels |
| `kubectl get pods -L app,env` | Labels as columns |
| `kubectl get pods -l app=nginx` | Filter (equality) |
| `kubectl get pods -l 'env in (dev,test)'` | Filter (set-based) |
| `kubectl get all -l app=nginx` | All types with label |
| `kubectl label pod web env=dev` | Add label |
| `kubectl label pod web env=prod --overwrite` | Change label |
| `kubectl label pod web env-` | Remove label |
| `kubectl label pods -l app=nginx team=a` | Label many objects |
| `kubectl annotate pod web key="value"` | Add annotation |
| `kubectl annotate pod web key-` | Remove annotation |
| `kubectl delete pods -l env=dev` | Delete by label |
| `kubectl get pods --field-selector status.phase=Running` | Filter by field |

---

## 8. Practice tasks

1. Create 4 Pods with labels: `app` (web/api), `env` (dev/prod). List only
   the prod api Pod with one command.
2. Add label `team=blue` to all Pods with `env=dev` in one command.
3. Write a Deployment selector using `matchExpressions` that matches Pods
   where tier is `frontend` or `edge`.
4. Add an annotation with a Git commit hash to a Pod. Show it with
   `-o jsonpath='{.metadata.annotations}'`.
5. Delete all Pods where the label `team` does NOT exist.

---

## 9. Quiz

1. What is the main difference between labels and annotations?
2. Write a selector for "env is dev AND tier is not backend".
3. Which selector style can a Service use: `matchLabels`, `matchExpressions`
   or a simple map?
4. How do you remove the label `env` from Pod `web`?
5. Why might a Service have zero endpoints even when Pods are running?

<details><summary>Quiz answers</summary>

1. Labels identify and are used by selectors. Annotations hold extra
   non-identifying info and cannot be used in selectors.
2. `-l 'env=dev,tier!=backend'`
3. A simple map (equality only), for example `selector: {app: nginx}`.
4. `kubectl label pod web env-`
5. The Service selector does not match the Pod labels (or the Pods are
   not Ready).

</details>

---

## 10. Next topic

[Topic 06: ReplicaSets](../replicaset/replicaset.md)

---

**Previous:** [Topic 04: Pods](../pod/pod.md) | **Next:** [Topic 06: ReplicaSets](../replicaset/replicaset.md) | [Back to README](../README.md)
