# Topic 10: ConfigMaps & Secrets

| | |
|---|---|
| **Level** | Beginner |
| **Time** | ~45 min |
| **Prereqs** | [Pods](../pod/pod.md), [Deployments](../deployments/deployments.md), [Namespaces](../namespaces/namespaces.md) |
| **Files** | [`configmaps_secrets/app-configmap.yaml`](app-configmap.yaml), [`configmaps_secrets/app-secret.yaml`](app-secret.yaml), [`configmaps_secrets/config-demo-pod.yaml`](config-demo-pod.yaml), [`configmaps_secrets/frozen-configmap.yaml`](frozen-configmap.yaml), [`volumes/deployment.yaml`](../volumes/deployment.yaml) (has a hard-coded password - we fix this idea here) |

> Run all commands from the repo root.

---

## 1. What is it?

| Object | Stores | Examples |
|---|---|---|
| **ConfigMap** | NON-secret settings as key/value pairs | `LOG_LEVEL=debug`, an `nginx.conf` file, an API URL |
| **Secret** | SENSITIVE data as key/value pairs | passwords, API tokens, TLS certificates |

Both are namespaced. A Pod can read them as:

- environment variables
- files inside a mounted volume

---

## 2. Why do we need it?

Rule: do **not** bake config into the container image.

Look at [`volumes/deployment.yaml`](../volumes/deployment.yaml) in this repo:

```yaml
env:
  - name: MONGO_INITDB_ROOT_PASSWORD
    value: "password"          # <- password in plain text in Git!
```

Problems:

- Everyone who reads the repo sees the password.
- To change it you must edit the Deployment YAML.
- The same image cannot easily run in dev and prod with other settings.

With ConfigMaps and Secrets:

- One image, many environments (dev/prod use different ConfigMaps).
- Secrets have separate RBAC: you can let people read ConfigMaps but not Secrets.
- Mounted files update automatically when the object changes.

---

## 3. Key concepts

### a) Size limit

A ConfigMap or Secret can hold max **1 MiB** of data.

### b) base64 is NOT encryption

Secret values are stored base64-**encoded**. Anyone can decode them:

```bash
echo cGFzc3dvcmQ= | base64 -d      # -> password
```

By default Secrets are stored in etcd without encryption. To protect them: turn on "encryption at rest" on the API server, limit RBAC (`get secrets`), and do not commit Secret YAML to Git.

### c) `data` vs `stringData` (in Secret YAML)

| Field | Meaning |
|---|---|
| `data` | Values must be base64-encoded by you |
| `stringData` | You write plain text, Kubernetes encodes it for you (write-only helper; `get -o yaml` shows it under `data`) |

### d) Secret types

| Type | Use |
|---|---|
| `Opaque` | Generic key/values (default) |
| `kubernetes.io/tls` | Keys `tls.crt` and `tls.key` |
| `kubernetes.io/dockerconfigjson` | Registry login (`imagePullSecrets`) |
| `kubernetes.io/service-account-token` | Legacy SA tokens |

### e) Ways to use them in a Pod

| Method | Result |
|---|---|
| `env` + `valueFrom` | One key -> one env variable |
| `envFrom` | ALL keys -> env variables (key name = var name) |
| volume mount | Each key becomes a FILE in a folder |

### f) Updates

- Env variables are read **only** when the container starts. If you change the ConfigMap, env vars do NOT change. Restart the Pods:

  ```bash
  kubectl rollout restart deployment <name>
  ```

- Mounted volumes DO update (after a short delay, up to ~1 min). Exception: mounts that use `subPath` never update.

### g) `immutable: true`

You can mark a ConfigMap/Secret as immutable. Then nobody can change its data (you must delete and recreate it). Benefits: safety, and less load on the API server (kubelet stops watching it).

### h) External secret managers

In real production, many teams keep secrets outside the cluster: HashiCorp Vault, AWS Secrets Manager, GCP Secret Manager, Azure Key Vault. Tools that bring them in:

- **External Secrets Operator** (syncs into normal K8s Secrets)
- **Secrets Store CSI Driver** (mounts secrets as files)
- **Sealed Secrets** (encrypt Secrets so you CAN store them in Git)

---

## 4. Example YAML

### ConfigMap: [`configmaps_secrets/app-configmap.yaml`](app-configmap.yaml)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: "debug"            # simple key/value (always strings)
  APP_COLOR: "blue"
  index.html: |                 # a whole file as one key
    <h1>Hello from a ConfigMap</h1>
```

### Secret: [`configmaps_secrets/app-secret.yaml`](app-secret.yaml)

Demo values only. Never commit real Secret YAML to Git.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongo-creds
type: Opaque
stringData:                     # plain text here; stored as base64
  username: admin
  password: demo-pass-123
```

### Pod using both: [`configmaps_secrets/config-demo-pod.yaml`](config-demo-pod.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-demo
spec:
  containers:
    - name: web
      image: nginx:1.27
      env:
        - name: LOG_LEVEL               # 1) one key -> one env var
          valueFrom:
            configMapKeyRef:
              name: app-config          # ConfigMap name
              key: LOG_LEVEL            # key inside the ConfigMap
        - name: DB_PASSWORD             # 1) same for a Secret
          valueFrom:
            secretKeyRef:
              name: mongo-creds
              key: password
      envFrom:                          # 2) ALL keys as env vars
        - secretRef:
            name: mongo-creds           # gives env "username", "password"
          prefix: MONGO_                # -> MONGO_username, MONGO_password
      volumeMounts:
        - name: html                    # 3) mount as files
          mountPath: /usr/share/nginx/html
          readOnly: true
  volumes:
    - name: html
      configMap:
        name: app-config
        items:                          # only take these keys
          - key: index.html
            path: index.html            # file name inside mountPath
```

### Fixing the repo's mongo Deployment (only the env part)

```yaml
          env:
            - name: MONGO_INITDB_ROOT_USERNAME
              valueFrom:
                secretKeyRef:
                  name: mongo-creds
                  key: username
            - name: MONGO_INITDB_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mongo-creds
                  key: password
```

### An immutable ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-v2           # put a version in the name
data:
  APP_COLOR: "green"
immutable: true                 # data can never be edited now
```

The lab uses a tiny immutable ConfigMap, [`configmaps_secrets/frozen-configmap.yaml`](frozen-configmap.yaml):

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frozen
data:
  A: "1"
immutable: true
```

---

## 5. Hands-on lab

### Step 1: Create everything

```bash
kubectl apply -f configmaps_secrets/app-configmap.yaml
kubectl apply -f configmaps_secrets/app-secret.yaml
kubectl apply -f configmaps_secrets/config-demo-pod.yaml
kubectl get configmap,secret
# -> app-config (DATA 3), mongo-creds (Opaque, DATA 2)
```

### Step 2: Check the env variables

```bash
kubectl exec config-demo -- env | grep -E 'LOG_LEVEL|DB_|MONGO_'
# -> LOG_LEVEL=debug
#    DB_PASSWORD=demo-pass-123
#    MONGO_username=admin
#    MONGO_password=demo-pass-123
```

### Step 3: Check the mounted file

```bash
kubectl exec config-demo -- cat /usr/share/nginx/html/index.html
# -> <h1>Hello from a ConfigMap</h1>
```

### Step 4: Prove base64 is not secret

```bash
kubectl get secret mongo-creds -o jsonpath='{.data.password}'; echo
# -> ZGVtby1wYXNzLTEyMw==
kubectl get secret mongo-creds -o jsonpath='{.data.password}' \
  | base64 -d; echo
# -> demo-pass-123
```

### Step 5: Update the ConfigMap and watch the difference

```bash
kubectl patch configmap app-config --type merge \
  -p '{"data":{"LOG_LEVEL":"info","index.html":"<h1>v2</h1>\n"}}'
```

Wait ~60 seconds, then:

```bash
kubectl exec config-demo -- cat /usr/share/nginx/html/index.html
# -> <h1>v2</h1>                (file updated)
kubectl exec config-demo -- printenv LOG_LEVEL
# -> debug                       (env NOT updated, needs restart)
```

### Step 6: Create objects with kubectl (no YAML)

```bash
kubectl create configmap web-cfg --from-literal=MODE=prod \
  --from-file=nginx.conf=./nginx.conf     # file must exist
kubectl create secret generic db-secret \
  --from-literal=user=app --from-literal=pass='p@ss w0rd'
```

Tip: quote values with special characters.

### Step 7: Create a TLS secret

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=nginx.example.com"
kubectl create secret tls nginx-tls --cert=tls.crt --key=tls.key
kubectl get secret nginx-tls
# -> TYPE kubernetes.io/tls
```

This kind of Secret is used later in [Topic 14: Ingress](../ingress/ingress.md).

### Step 8: Generate YAML safely without applying

```bash
kubectl create secret generic demo --from-literal=a=b \
  --dry-run=client -o yaml
```

### Step 9: Try to edit an immutable ConfigMap

```bash
kubectl apply -f configmaps_secrets/frozen-configmap.yaml
kubectl patch configmap frozen -p '{"data":{"A":"2"}}'
# -> Error: field is immutable when `immutable` is set
```

### Step 10: Clean up

```bash
kubectl delete pod config-demo
kubectl delete cm app-config web-cfg frozen
kubectl delete secret mongo-creds db-secret nginx-tls demo
```

---

## 6. Common mistakes & troubleshooting

- **Pod stuck in `CreateContainerConfigError`**
  - The ConfigMap/Secret or the key does not exist. Run `kubectl describe pod <name>` and read Events. Note: it must be in the SAME namespace as the Pod.
  - Use `optional: true` in the ref if the key may be missing.
- **Wrong value because of base64 newline**
  - `echo password | base64` adds `\n`. Use `echo -n password | base64`, or use `stringData` / `kubectl create secret`.
- **Changed ConfigMap but app still uses old value**
  - Env vars never refresh. Run `kubectl rollout restart deployment X`.
  - `subPath` mounts never refresh either.
- **Mounting a ConfigMap over a folder hides the original files**
  - The mount REPLACES the whole folder. Use `subPath` for a single file, or mount into an empty folder.
- **`envFrom` skips some keys**
  - Keys that are not valid env names (like `index.html`) are skipped. Check events for `InvalidEnvironmentVariableNames`.
- **Secret YAML committed to Git**
  - Treat it as leaked. Rotate the password. Use Sealed Secrets or an external secret manager.

---

## 7. Cheat sheet

| Command | What it does |
|---|---|
| `kubectl create cm NAME --from-literal=K=V` | ConfigMap from values |
| `kubectl create cm NAME --from-file=FILE` | Key = file name |
| `kubectl create cm NAME --from-env-file=.env` | One key per line in `.env` |
| `kubectl create secret generic NAME --from-literal=K=V` | Opaque Secret |
| `kubectl create secret tls NAME --cert=c --key=k` | TLS Secret |
| `kubectl create secret docker-registry NAME --docker-server=S --docker-username=U --docker-password=P` | Image pull Secret |
| `kubectl get cm NAME -o yaml` | Show ConfigMap data |
| `kubectl get secret NAME -o jsonpath='{.data.K}' \| base64 -d` | Decode one Secret key |
| `kubectl describe secret NAME` | Keys and sizes only |
| `kubectl rollout restart deploy NAME` | Reload env vars |
| `... --dry-run=client -o yaml` | Print YAML, do not create |

---

## 8. Practice tasks

1. Create a Secret `mongo-creds` and change a copy of [`volumes/deployment.yaml`](../volumes/deployment.yaml) to read the username/password from it. Use image `mongo:7.0`. Check with: `kubectl exec ... -- env`.
2. Make a ConfigMap with a custom nginx `default.conf` (listen 8081) and mount it at `/etc/nginx/conf.d/` in an `nginx:1.27` Pod. Test with `kubectl port-forward pod/<name> 8081:8081`.
3. Use `envFrom` with a ConfigMap of 3 keys. Print them with `env`.
4. Create an immutable ConfigMap. Try to change it. Then roll out a new version `app-config-v3` and point your Deployment to it.
5. Decode every key of a Secret in one command (hint: go-template or jq with `@base64d`).

---

## 9. Quiz

1. Is base64 encoding a form of encryption?
2. You change a ConfigMap. Which updates automatically: env vars or mounted files?
3. What is the difference between `data` and `stringData` in a Secret?
4. Which two keys does a `kubernetes.io/tls` Secret contain?
5. Name one benefit of `immutable: true`.

<details><summary>Quiz answers</summary>

1. No. Anyone with read access can decode it. Protect Secrets with RBAC, encryption at rest, and/or an external secret manager.
2. Mounted files (not via `subPath`). Env vars need a Pod restart.
3. `data` needs base64 values. `stringData` takes plain text and the API server encodes it for you.
4. `tls.crt` and `tls.key`
5. Protects from accidental changes, and reduces API server load because kubelet does not need to watch it.

</details>

---

**Previous:** [Topic 09: Namespaces](../namespaces/namespaces.md) | **Next:** [Topic 11: Storage - Volumes, PV, PVC & StorageClass](../volumes/volumes.md) | [Back to README](../README.md)
