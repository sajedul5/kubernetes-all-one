# Topic 14: Ingress

| | |
|---|---|
| **Level** | Intermediate |
| **Time** | ~50 min |
| **Prereqs** | [Deployments](../deployments/deployments.md), [Services](../services/services.md), [ConfigMaps & Secrets](../configmaps_secrets/configmaps_secrets.md) |
| **Files** | [`ingress/nginx-ingress.yaml`](nginx-ingress.yaml), [`ingress/multi-ingress.yaml`](multi-ingress.yaml), [`deployments/nginx-deployments.yaml`](../deployments/nginx-deployments.yaml), [`services/nginx-services.yaml`](../services/nginx-services.yaml) |

> Run all commands from the repo root.

---

## 1. What is it?

An Ingress is a set of HTTP/HTTPS routing rules. It says:

- "requests for host `nginx.example.com`, path `/` -> Service `nginx-service`"
- "requests for host `api.example.com`, path `/v1` -> Service `api-svc`"

The Ingress object is ONLY rules. Something must read the rules and do the real work. That is the **Ingress Controller**: a reverse proxy (NGINX, Traefik, HAProxy, Envoy-based, cloud load balancers) running in the cluster. It:

- watches Ingress resources in the cluster
- provisions a load balancer or reverse proxy (e.g. NGINX)
- routes traffic to the right Services

```text
Browser --> Ingress Controller (one entry point, port 80/443)
                 |   host + path rules from Ingress objects
                 +--> Service A --> Pods
                 +--> Service B --> Pods
```

No controller installed = Ingress objects do nothing.

### Ingress vs Ingress Controller

| Ingress (resource) | Ingress Controller (component) |
|---|---|
| Defines HTTP rules | Implements the rules |
| Written in YAML | Runs as a Pod in the cluster |
| Passive (declarative) | Active (routes live traffic) |
| Needs a controller to work | `ingress-nginx`, Traefik, HAProxy, Istio Gateway, ... |

---

## 2. Why do we need it?

Without Ingress, each app needs its own NodePort or LoadBalancer:

- **NodePort**: ugly high ports (30000-32767), one per app.
- **LoadBalancer**: in the cloud, each one costs money (one IP per app).

With Ingress:

- ONE entry point (one IP / one load balancer) for many apps.
- Routing by host name (virtual hosts) and by URL path.
- TLS/HTTPS termination in one place.
- Extra features via the controller: redirects, rewrites, rate limits, auth, sticky sessions.

---

## 3. Key concepts

### a) Ingress controller on Minikube

```bash
minikube addons enable ingress
```

This installs ingress-nginx (the Kubernetes community NGINX controller) in namespace `ingress-nginx`, and an IngressClass named `nginx` that is marked as the DEFAULT class.

On a cloud cluster (AWS, GCP, Azure) you install the controller from its manifest instead, for example:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.2/deploy/static/provider/cloud/deploy.yaml
```

| Task | Minikube | Production cloud |
|---|---|---|
| Install Ingress Controller | `minikube addons enable ingress` | Apply the controller manifest / Helm chart |
| External access | `minikube tunnel` + `/etc/hosts` | LoadBalancer IP auto-assigned |
| Backend Service type | ClusterIP | ClusterIP + Ingress |
| Host-based routing | Supported | Supported |

### b) ingressClassName

`spec.ingressClassName: nginx` -> which controller handles this Ingress. If you leave it out, the default IngressClass is used (on minikube that is `nginx`). Best practice: always set it, like [`ingress/nginx-ingress.yaml`](nginx-ingress.yaml) in the repo does.

The old annotation `kubernetes.io/ingress.class` is deprecated.

### c) Rules: host + paths

| Host | Matches |
|---|---|
| `host: nginx.example.com` | The HTTP Host header |
| no host | ALL hosts (catch-all) |
| `*.example.com` | Wildcard (one label only) |

### d) pathType (required)

| pathType | Behaviour |
|---|---|
| `Exact` | `/foo` matches ONLY `/foo` |
| `Prefix` | `/foo` matches `/foo`, `/foo/`, `/foo/bar` (by path elements; NOT `/foobar`) |
| `ImplementationSpecific` | Depends on the controller (avoid) |

When many paths match, the longest one wins; Exact beats Prefix.

### e) Backend

`service.name` + `service.port.number` (or `port.name`). The Service must be in the SAME namespace as the Ingress.

`defaultBackend` -> where to send requests that match no rule.

### f) TLS

`spec.tls` lists hosts and a `secretName`. The Secret must be type `kubernetes.io/tls` (`tls.crt` + `tls.key`) in the same namespace. The controller terminates HTTPS and talks HTTP to the Pods.

Real certificates: use cert-manager + Let's Encrypt.

### g) Annotations

Controller-specific extras, for example (ingress-nginx):

```yaml
nginx.ingress.kubernetes.io/rewrite-target: /$2
nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

Other controllers use other annotations.

### h) Reaching the controller from your laptop (Minikube)

**Linux (docker or VM driver):**

- Use the node IP: `minikube ip` -> e.g. `192.168.49.2`
- Add to `/etc/hosts`: `192.168.49.2  nginx.example.com`

**macOS / Windows with the docker driver:**

- The node IP is NOT reachable from the host. Run in another terminal: `minikube tunnel` (keep it open, may ask for sudo)
- Add to `/etc/hosts`: `127.0.0.1  nginx.example.com`
- (Windows file: `C:\Windows\System32\drivers\etc\hosts`)

### i) Gateway API = the successor

Ingress is stable but "frozen": no new features. The new standard is the **Gateway API** (GatewayClass, Gateway, HTTPRoute, GRPCRoute ...). It is more expressive (header matching, traffic split, roles for infra vs app teams). Many controllers support both.

Also note: the community ingress-nginx project was retired (its best-effort maintenance ended in March 2026). It is fine for learning on Minikube, but new production setups should pick a maintained controller or a Gateway API implementation. Learn Ingress first; it is still everywhere.

---

## 4. Example YAML

### [`ingress/nginx-ingress.yaml`](nginx-ingress.yaml)

```yaml
apiVersion: networking.k8s.io/v1   # Ingress API group (stable)
kind: Ingress
metadata:
  name: nginx-ingress
  labels:
    app: nginx
spec:
  ingressClassName: nginx          # handled by ingress-nginx
  rules:
    - host: nginx.example.com      # only for this Host header
      http:
        paths:
          - path: /
            pathType: Prefix       # / matches every path
            backend:
              service:
                name: nginx-service    # services/nginx-services.yaml
                port:
                  number: 8080         # the SERVICE port, not 80
```

### Two apps, path routing, TLS: [`ingress/multi-ingress.yaml`](multi-ingress.yaml)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"  # http -> https
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - demo.example.com         # must match a rule host
      secretName: demo-tls         # kubernetes.io/tls Secret
  rules:
    - host: demo.example.com
      http:
        paths:
          - path: /api             # /api, /api/users ... -> api
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 80
          - path: /                # everything else -> web
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
```

---

## 5. Hands-on lab

### Step 1: Enable the controller

```bash
minikube addons enable ingress
kubectl get pods -n ingress-nginx
# -> ingress-nginx-controller-xxxx   1/1   Running
kubectl get ingressclass
# -> nginx   k8s.io/ingress-nginx
kubectl get svc -n ingress-nginx
```

### Step 2: Deploy the nginx app from the repo

```bash
kubectl apply -f deployments/nginx-deployments.yaml
kubectl apply -f services/nginx-services.yaml
kubectl apply -f ingress/nginx-ingress.yaml
kubectl get ingress
# -> nginx-ingress  nginx  nginx.example.com  192.168.49.2  80
#    (ADDRESS may take ~30s to appear)
```

### Step 3: Test without touching /etc/hosts (Linux)

```bash
curl -H "Host: nginx.example.com" http://$(minikube ip)/
# -> "Welcome to nginx!" HTML
```

**macOS/Windows docker driver:**

```bash
# Terminal 2:
minikube tunnel
# Terminal 1:
curl -H "Host: nginx.example.com" http://127.0.0.1/
```

### Step 4: Use the real host name

```bash
# Linux:
echo "$(minikube ip) nginx.example.com" | sudo tee -a /etc/hosts
# macOS/Windows: add "127.0.0.1 nginx.example.com" to the hosts file
#                (tunnel must be running)
curl http://nginx.example.com/
```

Also open it in your browser.

### Step 5: Wrong host gets 404

```bash
curl -H "Host: other.example.com" http://$(minikube ip)/
# -> 404 Not Found (from the controller, not from your app)
```

### Step 6: Path routing with two apps

```bash
kubectl create deployment web --image=nginx:1.27
kubectl expose deployment web --port=80
kubectl create deployment api --image=hashicorp/http-echo:1.0 \
  -- /http-echo -text="hello from api" -listen=:5678
kubectl expose deployment api --port=80 --target-port=5678
```

### Step 7: TLS Secret (self-signed)

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=demo.example.com" \
  -addext "subjectAltName=DNS:demo.example.com"
kubectl create secret tls demo-tls --cert=tls.crt --key=tls.key
kubectl apply -f ingress/multi-ingress.yaml
```

### Step 8: Test HTTPS and paths (Linux; use 127.0.0.1 with tunnel)

```bash
IP=$(minikube ip)
curl -k --resolve demo.example.com:443:$IP https://demo.example.com/api
# -> hello from api
curl -k --resolve demo.example.com:443:$IP https://demo.example.com/
# -> nginx welcome page
curl -I --resolve demo.example.com:80:$IP http://demo.example.com/
# -> 308 Permanent Redirect to https
```

(`-k` = accept self-signed cert)

### Step 9: Look at controller logs (great for debugging)

```bash
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller --tail=20
```

### Step 10: Clean up

```bash
kubectl delete ingress demo nginx-ingress
kubectl delete deploy web api; kubectl delete svc web api
kubectl delete secret demo-tls
```

Remove the lines you added to `/etc/hosts`.

---

## 6. Common mistakes & troubleshooting

- **Ingress has no ADDRESS / nothing happens**
  - No controller, or wrong `ingressClassName`. Check `kubectl get pods -n ingress-nginx` and `kubectl get ingressclass`.
- **404 from nginx**
  - Host header does not match (you used the IP, not the host name), or no path matches.
- **503 Service Temporarily Unavailable**
  - The Service has no ready endpoints. Check `kubectl get endpointslices -l kubernetes.io/service-name=<svc>` and the Service selector vs Pod labels.
- **502 Bad Gateway**
  - Wrong port: backend port must be the SERVICE port (8080 for `nginx-service`), and `targetPort` must match the container port (80).
- **Browser cannot reach nginx.example.com on macOS/Windows**
  - `minikube tunnel` is not running, or `/etc/hosts` points to `minikube ip` instead of `127.0.0.1`.
- **Browser shows "Kubernetes Ingress Controller Fake Certificate"**
  - The TLS Secret is missing, in another namespace, or the host in `spec.tls` does not match the rule host.
- **Backend Service in another namespace**
  - Not allowed. Put the Ingress in the Service's namespace (you can have many Ingress objects; the controller merges them).

---

## 7. Cheat sheet

| Command | What it does |
|---|---|
| `minikube addons enable ingress` | Install ingress-nginx |
| `minikube addons list \| grep ingress` | Check addon status |
| `minikube ip` | Node IP (Linux) |
| `minikube tunnel` | Expose on 127.0.0.1 (mac/win) |
| `kubectl get ingressclass` | List controllers / default |
| `kubectl get ing -A` | List Ingress objects |
| `kubectl describe ing NAME` | Rules, backends, events |
| `kubectl create ingress NAME --class=nginx --rule="host.com/*=svc:80"` | Quick Ingress (Prefix path) |
| `kubectl create ingress NAME --class=nginx --rule="host.com/*=svc:80,tls=my-tls"` | Quick Ingress with TLS |
| `kubectl create secret tls N --cert=c --key=k` | TLS Secret |
| `kubectl logs -n ingress-nginx deploy/ingress-nginx-controller` | Controller logs |
| `curl -H "Host: h.com" http://IP/` | Test without /etc/hosts |

---

## 8. Practice tasks

1. Remove `ingressClassName` from a copy of [`ingress/nginx-ingress.yaml`](nginx-ingress.yaml). Does it still work on minikube? Why? (hint: default IngressClass)
2. Create two hosts: `blue.example.com` -> a "blue" Deployment and `green.example.com` -> a "green" Deployment (use `hashicorp/http-echo:1.0` with different `-text`). Test both with `curl -H "Host: ..."`.
3. Make a path rule with pathType `Exact` for `/health`. Test `/health` and `/health/x`. Which one is 404?
4. Add TLS to the `nginx.example.com` Ingress with a self-signed cert.
5. Read about Gateway API and write the HTTPRoute that matches the repo's Ingress (host `nginx.example.com`, `/` -> `nginx-service:8080`).

---

## 9. Quiz

1. What happens to an Ingress object if no Ingress controller runs?
2. Does pathType `Prefix` with path `/foo` match `/foobar`?
3. In the repo Ingress, which port is used in the backend: 80 or 8080? Why?
4. On macOS with the docker driver, what IP do you put in `/etc/hosts`?
5. Which newer Kubernetes API is the successor of Ingress?

<details><summary>Quiz answers</summary>

1. Nothing. It is only stored rules; no traffic is routed.
2. No. Prefix matches by path elements: `/foo`, `/foo/`, `/foo/bar` only.
3. 8080. The backend points to the Service port. The Service then forwards to `targetPort` 80 on the Pods.
4. `127.0.0.1`, with `minikube tunnel` running.
5. The Gateway API (Gateway, HTTPRoute, ...).

</details>

---

**Previous:** [Topic 13: DaemonSets, Jobs & CronJobs](../daemonsets_jobs_cronjobs/daemonsets_jobs_cronjobs.md) | **Next:** [Topic 15: Probes & Resources](../probes_resources/probes_resources.md) | [Back to README](../README.md)
