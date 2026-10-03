# Topic 17: RBAC & Security

| | |
|---|---|
| **Level** | Advanced |
| **Time** | ~60 min |
| **Prereqs** | [Namespaces](../namespaces/namespaces.md), [ConfigMaps & Secrets](../configmaps_secrets/configmaps_secrets.md) |
| **Files** | [rbac-demo.yaml](rbac-demo.yaml), [node-reader-clusterrole.yaml](node-reader-clusterrole.yaml) (the lab also uses [deployments/nginx-deployments.yaml](../deployments/nginx-deployments.yaml)) |

> Run all commands from the repo root.

---

## 1. What is it?

Kubernetes security has many layers. In this topic we learn the most important ones:

| Layer | Meaning |
|---|---|
| **RBAC** | "Who can do WHAT on WHICH objects?" (Role-Based Access Control) |
| **ServiceAccount** | An identity for Pods (apps), not for humans. |
| **securityContext** | "How does the container run?" (which user, can it write to its disk, which Linux powers it has). |
| **Pod Security** | A built-in check (Pod Security Admission) that can REJECT Pods that are not safe enough. |
| **Image scanning** | Find known security bugs (CVEs) in images BEFORE you run them. |

Every request to the API server goes through 3 steps:

1. **Authentication** -> Who are you? (certificate, token, cloud login)
2. **Authorization** -> Are you allowed? (RBAC checks this)
3. **Admission** -> Is the object OK? (Pod Security Admission, ...)

---

## 2. Why do we need it?

- On Minikube you are "cluster-admin". You can do everything. In a real company, a developer should NOT be able to delete production.
- Apps inside Pods sometimes call the Kubernetes API (CI tools, operators, monitoring). They should get ONLY the rights they need.
- If a hacker breaks into a container, a non-root, read-only container with no extra Linux capabilities gives them much less power.
- One bad Pod with `privileged: true` can take over the whole node. Pod Security Admission stops this.

**Main idea: LEAST PRIVILEGE.** Give the minimum rights needed. Nothing more.

---

## 3. Key concepts

### a) Subjects (WHO)

- **User**: a human. Kubernetes has NO User object. Users come from certificates or an identity provider (OIDC).
- **Group**: a group of users (e.g. `system:masters`, `dev-team`).
- **ServiceAccount**: an identity for Pods. It IS a Kubernetes object and lives in a namespace. Full name: `system:serviceaccount:<namespace>:<name>`

### b) Role vs ClusterRole (WHAT)

- **Role**: rules inside ONE namespace.
- **ClusterRole**: rules for the whole cluster, OR for cluster-scoped objects (nodes, PVs, namespaces), OR a reusable rule set that you bind inside one namespace.

A rule = `apiGroups` + `resources` + `verbs`.

- **apiGroups**: `""` (core: pods, services, secrets, configmaps), `"apps"` (deployments, statefulsets, replicasets), `"batch"` (jobs, cronjobs)
- **verbs**: get, list, watch, create, update, patch, delete

RBAC is ALLOW only. There are no "deny" rules. If no rule allows it, it is denied.

### c) RoleBinding vs ClusterRoleBinding (CONNECT who + what)

- **RoleBinding**: gives a Role or ClusterRole to subjects, but ONLY inside the RoleBinding's namespace.
- **ClusterRoleBinding**: gives a ClusterRole in ALL namespaces.

Tip: bind the built-in ClusterRole `view` with a RoleBinding to give read-only access in one namespace only.

### d) Built-in ClusterRoles

| ClusterRole | Rights |
|---|---|
| `cluster-admin` | everything |
| `admin` | almost all in a namespace |
| `edit` | read/write apps |
| `view` | read only (no Secrets) |

### e) ServiceAccount tokens

- Every namespace has a ServiceAccount named `default`.
- A Pod uses `default` if you do not set `serviceAccountName`.
- Since v1.24, tokens are short-lived and mounted automatically at `/var/run/secrets/kubernetes.io/serviceaccount/token`
- Create a token by hand: `kubectl create token <sa-name> -n <ns>`
- If the app does not call the API, set `automountServiceAccountToken: false`

### f) securityContext (on Pod or container)

| Setting | Effect |
|---|---|
| `runAsNonRoot: true` | refuse to start if user is root (0) |
| `runAsUser: 101` | run as this user ID |
| `readOnlyRootFilesystem: true` | container cannot write to its disk (mount an emptyDir for /tmp etc.) |
| `allowPrivilegeEscalation: false` | process cannot gain more rights |
| `capabilities: drop: ["ALL"]` | remove all Linux "super powers" |
| `seccompProfile: RuntimeDefault` | block dangerous system calls |
| `privileged: true` | DANGER. Full access to the node. |

### g) Pod Security Admission (PSA)

Built in since v1.25. You turn it on with namespace LABELS.

3 levels:

- **privileged** -> no checks
- **baseline** -> blocks known bad things (privileged, hostNetwork, hostPath, hostPID ...)
- **restricted** -> strict: non-root, drop ALL capabilities, no privilege escalation, seccomp RuntimeDefault

3 modes:

- **enforce** -> reject bad Pods
- **audit** -> allow, but write to the audit log
- **warn** -> allow, but print a warning to the user

Label format:

```text
pod-security.kubernetes.io/<mode>=<level>
pod-security.kubernetes.io/<mode>-version=latest
```

### h) Image scanning (brief)

Tools like Trivy or Grype read an image and list known CVEs:

```bash
trivy image nginx:1.27.2
grype nginx:1.27.2
```

Run them in your CI pipeline. Fail the build on CRITICAL bugs. Also: use small images (alpine, distroless), pin tags (never `latest`), and pull only from trusted registries.

---

## 4. Example YAML

Saved as [rbac_security/rbac-demo.yaml](rbac-demo.yaml) (namespace `dev`).

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: dev
  labels:
    # Pod Security Admission: reject Pods that are not "restricted"
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    # Also show a warning to the user for "restricted" problems
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa                 # identity for our app Pods
  namespace: dev
automountServiceAccountToken: false   # do not mount a token by default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role                     # namespaced rules
metadata:
  name: pod-reader
  namespace: dev               # rules work only in "dev"
rules:
- apiGroups: [""]              # "" = core API group (pods live here)
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]   # read only. No create/delete.
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-sa-pod-reader
  namespace: dev
subjects:                      # WHO
- kind: ServiceAccount
  name: app-sa
  namespace: dev
roleRef:                       # WHAT (cannot be changed later)
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-nginx
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure-nginx
  template:
    metadata:
      labels:
        app: secure-nginx
    spec:
      serviceAccountName: app-sa        # use our ServiceAccount
      securityContext:                  # Pod level
        runAsNonRoot: true              # never run as root
        runAsUser: 101                  # "nginx" user in this image
        seccompProfile:
          type: RuntimeDefault          # required by "restricted"
      containers:
      - name: nginx
        # unprivileged nginx listens on 8080 (non-root cannot use 80)
        image: nginxinc/nginx-unprivileged:1.27.2-alpine
        ports:
        - containerPort: 8080
        securityContext:                # container level
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true  # cannot write to image files
          capabilities:
            drop: ["ALL"]               # remove all Linux capabilities
        volumeMounts:
        - name: tmp                     # nginx needs to write here
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}                    # writable scratch folder
```

A ClusterRole + ClusterRoleBinding example (read nodes everywhere), saved as [rbac_security/node-reader-clusterrole.yaml](node-reader-clusterrole.yaml):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader            # no namespace: cluster-scoped
rules:
- apiGroups: [""]
  resources: ["nodes"]         # nodes are cluster-scoped
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: alice-node-reader
subjects:
- kind: User
  name: alice                  # user name from certificate CN or OIDC
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
```

---

## 5. Hands-on lab

1. Start Minikube (RBAC is on by default) and check who you are:

   ```bash
   minikube start
   kubectl auth whoami
   ```

   You should see a user like `minikube-user` in group `system:masters`.

2. Apply the example:

   ```bash
   kubectl apply -f rbac_security/rbac-demo.yaml
   kubectl get sa,role,rolebinding -n dev
   kubectl get pods -n dev
   ```

   The `secure-nginx` Pod should be Running.

3. Test RBAC with `can-i` and impersonation (`--as`):

   ```bash
   SA=system:serviceaccount:dev:app-sa
   kubectl auth can-i list pods -n dev --as=$SA        # yes
   kubectl auth can-i delete pods -n dev --as=$SA      # no
   kubectl auth can-i list pods -n default --as=$SA    # no
   kubectl auth can-i list secrets -n dev --as=$SA     # no
   kubectl get pods -n dev --as=$SA                    # works
   kubectl get pods -n default --as=$SA                # Forbidden
   ```

   List all rights of the ServiceAccount:

   ```bash
   kubectl auth can-i --list -n dev --as=$SA
   ```

4. Create a short-lived token (what a Pod would get):

   ```bash
   kubectl create token app-sa -n dev --duration=10m
   ```

   You see a long JWT string. Do not share real tokens.

5. Test Pod Security Admission. Try to run the normal nginx image (it runs as root):

   ```bash
   kubectl run bad-nginx --image=nginx:1.27.2 -n dev
   ```

   You should see an error like:

   ```text
   Error from server (Forbidden): pods "bad-nginx" is forbidden:
   violates PodSecurity "restricted:latest": allowPrivilegeEscalation
   != false ... runAsNonRoot != true ...
   ```

6. Try the same with a Deployment (the repo nginx file):

   ```bash
   kubectl apply -f deployments/nginx-deployments.yaml -n dev
   ```

   The Deployment is created (with a warning), but NO Pods appear:

   ```bash
   kubectl get deploy,rs,pods -n dev
   kubectl describe rs -n dev -l app=nginx
   ```

   Events show `FailedCreate ... violates PodSecurity`. The check is on Pods, not on Deployments.

   ```bash
   kubectl delete -f deployments/nginx-deployments.yaml -n dev
   ```

7. Check the read-only filesystem:

   ```bash
   kubectl exec -n dev deploy/secure-nginx -- touch /etc/test
   ```

   Output: `touch: /etc/test: Read-only file system`

   ```bash
   kubectl exec -n dev deploy/secure-nginx -- id
   ```

   Output: `uid=101(nginx) ...` (not root)

8. (Optional) Apply the cluster-wide example and test it with impersonation:

   ```bash
   kubectl apply -f rbac_security/node-reader-clusterrole.yaml
   kubectl auth can-i list nodes --as=alice            # yes
   kubectl auth can-i delete nodes --as=alice          # no
   kubectl delete -f rbac_security/node-reader-clusterrole.yaml
   ```

9. Dry-run a stricter label on an existing namespace (no change made):

   ```bash
   kubectl label --dry-run=server --overwrite ns default \
     pod-security.kubernetes.io/enforce=restricted
   ```

   It prints warnings for Pods that would break.

10. Clean up:

    ```bash
    kubectl delete ns dev
    ```

---

## 6. Common mistakes & troubleshooting

- `Forbidden: User ... cannot list resource pods`: no rule allows it. Check with `kubectl auth can-i --list --as=...` and check the RoleBinding namespace.
- Wrong apiGroup: deployments are in `apps`, not `""`. Jobs are `batch`.
- Role in namespace A + RoleBinding in namespace B does NOT work. A RoleBinding can only reference a Role in its OWN namespace.
- ServiceAccount subject without `namespace:` field -> binding has no effect.
- `roleRef` cannot be edited. Delete and re-create the binding.
- Giving `cluster-admin` to an app "to make it work" -> huge risk.
- Pod fails with `container has runAsNonRoot and image will run as root`: the image uses user 0. Use an unprivileged image or set `runAsUser`.
- App crashes with `Read-only file system`: add an emptyDir for the folders it writes (`/tmp`, `/var/cache/...`).
- Non-root process cannot bind port 80 -> use a port above 1024 (8080).
- `violates PodSecurity`: read the message, it lists every missing field.
- Secrets in RBAC: `list` on secrets also shows their VALUES. Treat get/list/watch on secrets as sensitive.

---

## 7. Cheat sheet

| Command | Purpose |
|---|---|
| `kubectl auth whoami` | who am I? |
| `kubectl auth can-i create deploy -n dev` | can I do this? |
| `kubectl auth can-i --list -n dev` | all my rights in "dev" |
| `kubectl ... --as=<user>` / `--as-group=<g>` | act as someone else |
| `kubectl create sa app-sa -n dev` | create ServiceAccount |
| `kubectl create token app-sa -n dev` | get a short-lived token |
| `kubectl create role pod-reader --verb=get,list --resource=pods -n dev` | create Role fast |
| `kubectl create rolebinding rb --role=pod-reader --serviceaccount=dev:app-sa -n dev` | bind Role to SA |
| `kubectl create clusterrolebinding crb --clusterrole=view --user=alice` | read-only everywhere |
| `kubectl get role,rolebinding -A` | list namespaced RBAC |
| `kubectl get clusterrole,clusterrolebinding` | list cluster RBAC |
| `kubectl describe clusterrole view` | see rules of a role |
| `kubectl label ns dev pod-security.kubernetes.io/enforce=baseline` | turn on PSA |
| `trivy image nginx:1.27.2` | scan image for CVEs |

---

## 8. Practice tasks

1. Create namespace `qa` and ServiceAccount `ci-bot`. Give it rights to create/update/delete Deployments ONLY in `qa`. Prove it with `can-i`.
2. Give user `bob` read-only access to namespace `qa` by binding the built-in ClusterRole `view` with a RoleBinding. Check that bob cannot read Secrets.
3. Label namespace `qa` with `enforce=baseline`. Try to run a Pod with `privileged: true`. Read the error.
4. Take [deployments/nginx-deployments.yaml](../deployments/nginx-deployments.yaml) and change it so it passes `restricted` (hint: unprivileged image, securityContext, emptyDir).
5. Install Trivy and scan `nginx:1.27.2` and `nginx:1.27.2-alpine`. Which one has fewer CVEs?

---

## 9. Quiz

1. What is the difference between a Role and a ClusterRole?
2. Can a RoleBinding reference a ClusterRole? What is the effect?
3. Which command shows if ServiceAccount `app-sa` in `dev` can delete Pods?
4. Name 3 securityContext settings required by the `restricted` level.
5. Which namespace label rejects Pods that do not meet `baseline`?

<details>
<summary>Quiz answers</summary>

1. A Role has rules for ONE namespace. A ClusterRole is cluster-wide and can also cover cluster-scoped objects like nodes and PVs.
2. Yes. The ClusterRole rules then apply ONLY in the RoleBinding's namespace. This is a common way to reuse `view` or `edit`.
3. ```bash
   kubectl auth can-i delete pods -n dev \
     --as=system:serviceaccount:dev:app-sa
   ```
4. Any 3 of: `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, capabilities drop `["ALL"]`, seccompProfile type `RuntimeDefault`.
5. `pod-security.kubernetes.io/enforce=baseline`

</details>

---

**Previous:** [Autoscaling (HPA)](../autoscaling_hpa/autoscaling_hpa.md) | **Next:** [Network Policies](../network_policies/network_policies.md) | [Back to README](../README.md)
