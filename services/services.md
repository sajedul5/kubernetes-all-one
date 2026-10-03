# Topic 08: Services

| | |
|---|---|
| **Level** | Beginner |
| **Time** | ~60 min |
| **Prereqs** | [Topic 05: Labels, selectors, annotations](../labels_selectors/labels_selectors.md), [Topic 07: Deployments](../deployments/deployments.md) |
| **Files** | [`nginx-services.yaml`](nginx-services.yaml), [`svc-types.yaml`](svc-types.yaml), [`../deployments/nginx-deployments.yaml`](../deployments/nginx-deployments.yaml) |

> Run all commands from the repo root.

---

## 1. What is it?

A **Service** gives a group of Pods ONE stable network address:

- a stable virtual IP (the ClusterIP),
- a stable DNS name (for example `nginx-service.default.svc.cluster.local`),
- load balancing across all matching, READY Pods.

The Service finds its Pods with a label **selector** ([Topic 05](../labels_selectors/labels_selectors.md)).

---

## 2. Why do we need it?

Pods come and go. Each new Pod gets a NEW IP. A Deployment with 3 Pods
has 3 IPs that change on every update. Clients cannot track that.

A Service solves this:

- Clients use one name/IP that never changes.
- Traffic is spread over healthy Pods.
- Pods that are not Ready get no traffic.
- You can expose apps inside the cluster or to the outside world.

---

## 3. Key concepts

### Ports (people mix these up!)

| Field | Meaning |
|-------|---------|
| `port` | The port of the SERVICE (clients connect here) |
| `targetPort` | The port on the POD/container (number or port name) |
| `nodePort` | A port opened on EVERY node (NodePort/LoadBalancer only, range 30000-32767 by default) |

Repo example: `port 8080` -> `targetPort 80`.

### Service types

| Type | Accessible from | What it does | Use for |
|------|-----------------|--------------|---------|
| **ClusterIP** (default) | Inside the cluster only | Internal virtual IP | Internal APIs, databases, backends (microservice-to-microservice) |
| **NodePort** | `<NodeIP>:<nodePort>` on every node | ClusterIP + a port on every node | Simple demos, on-prem, labs. Not great for production. |
| **LoadBalancer** | External IP from the cloud provider | NodePort + an external load balancer | Exposing a TCP/UDP service to the internet in the cloud. On Minikube: run `minikube tunnel` to get an external IP. |
| **ExternalName** | Inside the cluster (DNS only) | No proxying, no selector. DNS returns a CNAME to an outside name. | Giving an external DB/API a cluster-internal name |
| **Headless** (`clusterIP: None`) | Inside the cluster (DNS only) | No virtual IP, no load balancing. DNS returns the Pod IPs directly. | StatefulSets ([Topic 12](../statefulset/statefulset.md)), client-side load balancing, service discovery |

### Endpoints and EndpointSlices

Kubernetes keeps a list of Pod IP:port behind each Service. Modern
clusters use EndpointSlice objects (the old Endpoints API is
deprecated since v1.33 but still visible). If this list is empty,
the Service does not work (wrong selector or Pods not Ready).

### DNS names (CoreDNS)

| From | Hostname |
|------|----------|
| Full name | `<service>.<namespace>.svc.cluster.local` |
| Same namespace | `<service>` |
| Another namespace | `<service>.<namespace>` |
| Headless + StatefulSet Pods | `<pod>.<service>.<namespace>.svc...` |

### How traffic flows

```text
Client -> Service IP:port -> kube-proxy rules (iptables/IPVS/nftables)
       -> one Pod IP:targetPort
```

The ClusterIP is virtual: you cannot ping it.

### Session affinity

`sessionAffinity: ClientIP` sends the same client to the same Pod.
Default is `None`.

### Service without selector

You can create a Service with no selector and manage EndpointSlices
yourself (to point to an outside IP).

### Minikube helpers

| Command | What it does |
|---------|--------------|
| `minikube service <name> --url` | Prints a URL for NodePort/LB services |
| `minikube tunnel` | Gives LoadBalancer services an IP (keep it running in its own terminal) |
| `kubectl port-forward svc/<name> 8080:8080` | Works with any type |

---

## 4. Example YAML

### A) The repo file [`services/nginx-services.yaml`](nginx-services.yaml) with comments

A `ClusterIP` Service named `nginx-service` that selects Pods with label
`app: nginx` (from [`../deployments/nginx-deployments.yaml`](../deployments/nginx-deployments.yaml))
and listens on port `8080`, forwarding to container port `80`.

```yaml
apiVersion: v1               # Services are in the core API group
kind: Service
metadata:
  name: nginx-service        # also the DNS name
  labels:
    app: nginx
spec:
  # type: ClusterIP          # default when "type" is not set
  selector:
    app: nginx               # send traffic to Pods with this label
  ports:
  - protocol: TCP
    port: 8080               # clients use nginx-service:8080
    targetPort: 80           # nginx in the Pod listens on 80
```

### B) Other types

Saved as [`services/svc-types.yaml`](svc-types.yaml):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80                 # ClusterIP port (inside cluster)
    targetPort: 80           # container port
    nodePort: 30080          # optional; 30000-32767; random if empty
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb
spec:
  type: LoadBalancer         # needs cloud LB or "minikube tunnel"
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
spec:
  clusterIP: None            # headless: DNS returns Pod IPs
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  type: ExternalName         # DNS CNAME, no selector, no proxy
  externalName: api.github.com
```

### C) Named target port (good practice)

In the Pod template:

```yaml
ports:
- name: http
  containerPort: 80
```

In the Service:

```yaml
targetPort: http          # survives a container port change
```

---

## 5. Hands-on lab

**Step 1. Create Pods to send traffic to**

```bash
kubectl apply -f deployments/nginx-deployments.yaml
kubectl get pods -l app=nginx -o wide
```

Note the 3 Pod IPs.

**Step 2. Create the ClusterIP Service**

```bash
kubectl apply -f services/nginx-services.yaml
kubectl get svc nginx-service
```

You should see: TYPE `ClusterIP`, a CLUSTER-IP like `10.x.x.x`,
PORT(S) `8080/TCP`.

**Step 3. Check endpoints**

```bash
kubectl get endpointslices -l kubernetes.io/service-name=nginx-service
```

You should see: the same 3 Pod IPs, port 80.

```bash
kubectl describe svc nginx-service   # see the "Endpoints:" line
```

**Step 4. Call it from inside the cluster**

```bash
kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- sh
  wget -qO- http://nginx-service:8080 | head -4
  wget -qO- http://nginx-service.default.svc.cluster.local:8080 | head -4
  nslookup nginx-service
  exit
```

You should see: the nginx welcome page HTML and the Service IP in
nslookup.

**Step 5. See load balancing**

Give each Pod a different page:

```bash
for p in $(kubectl get pods -l app=nginx -o name); do
  kubectl exec $p -- sh -c "echo $p > /usr/share/nginx/html/index.html"
done
kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- \
  sh -c 'for i in 1 2 3 4 5 6; do wget -qO- nginx-service:8080; done'
```

You should see: different Pod names in the output.

**Step 6. Self-updating endpoints**

```bash
kubectl scale deployment/nginx-deployment --replicas=5
kubectl get endpointslices -l kubernetes.io/service-name=nginx-service
```

You should see: 5 IPs now.

**Step 7. Port-forward from your laptop**

```bash
kubectl port-forward svc/nginx-service 8080:8080
# in another terminal:
curl http://localhost:8080      # Ctrl+C to stop the port-forward
```

**Step 8. NodePort, LoadBalancer, headless, ExternalName**

```bash
kubectl apply -f services/svc-types.yaml
kubectl get svc
```

NodePort:

```bash
minikube service nginx-nodeport --url
curl <the URL printed>
```

(On Linux you can also: `curl http://$(minikube ip):30080`. With
the docker driver on macOS/Windows, use the `minikube service` URL.)

LoadBalancer:

```bash
kubectl get svc nginx-lb     # EXTERNAL-IP is <pending>
# In a NEW terminal (may ask for your password):
minikube tunnel
kubectl get svc nginx-lb     # now it has an EXTERNAL-IP
curl http://<EXTERNAL-IP>
```

Headless:

```bash
kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup nginx-headless
```

You should see: several addresses (the Pod IPs), not one.

ExternalName:

```bash
kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup external-api
```

You should see: a CNAME to `api.github.com`.

**Step 9. Break it on purpose**

```bash
kubectl patch svc nginx-service -p '{"spec":{"selector":{"app":"wrong"}}}'
kubectl get endpointslices -l kubernetes.io/service-name=nginx-service
```

You should see: no endpoints. Requests now fail. Fix it:

```bash
kubectl apply -f services/nginx-services.yaml
```

**Step 10. Clean up**

Stop `minikube tunnel` with Ctrl+C.

```bash
kubectl delete -f services/svc-types.yaml
kubectl delete -f services/nginx-services.yaml
kubectl delete -f deployments/nginx-deployments.yaml
```

---

## 6. Common mistakes & troubleshooting

| Problem | Cause / Fix |
|---------|-------------|
| Service has no endpoints | 1) Compare selector and Pod labels: `kubectl get svc <s> -o jsonpath='{.spec.selector}'` and `kubectl get pods --show-labels`. 2) Are the Pods Ready? Not-ready Pods are removed from endpoints. |
| "Connection refused" but endpoints exist | Wrong `targetPort`. The app does not listen on that port. Check with `kubectl exec <pod> -- netstat -tlnp` (or `ss`), or the app docs. |
| Mixing up `port` and `targetPort` | Clients use `port`. Pods receive on `targetPort`. |
| Trying to ping the ClusterIP | ClusterIP is virtual. ping usually fails. Test with curl/wget. |
| Service in another namespace not found | Use `<service>.<namespace>` as the hostname. |
| LoadBalancer EXTERNAL-IP stays `<pending>` on Minikube | Run `minikube tunnel` in a separate terminal. |
| NodePort not reachable on macOS/Windows with docker driver | Use `minikube service <name> --url` (it opens a tunnel for you). |
| Using NodePort for production internet traffic | Prefer LoadBalancer or Ingress ([Topic 14](../ingress/ingress.md)). |

---

## 7. Cheat sheet

| Command | What it does |
|---------|--------------|
| `kubectl expose deploy nginx-deployment --name=web --port=80 --target-port=80 [--type=NodePort]` | Create Service for a Deployment |
| `kubectl apply -f services/nginx-services.yaml` | Create/update the repo Service |
| `kubectl get svc [-o wide]` | List Services |
| `kubectl describe svc <name>` | Selector, ports, endpoints |
| `kubectl get endpointslices -l kubernetes.io/service-name=<name>` | Pod IPs behind the Service |
| `kubectl port-forward svc/<name> L:R` | Local port L to service port R |
| `kubectl port-forward pod/<pod-name> 8080:80` | Port-forward a single Pod (alternative) |
| `kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- sh` | Temp Pod for testing |
| `nslookup <svc>.<ns>.svc.cluster.local` | Test DNS (inside a Pod) |
| `minikube service <name> --url` | URL for NodePort/LB |
| `minikube service list` | All services with URLs |
| `minikube tunnel` | External IP for LoadBalancer |
| `kubectl create service clusterip web --tcp=80:80 --dry-run=client -o yaml` | Generate Service YAML |
| `kubectl delete -f services/nginx-services.yaml` | Delete the repo Service |

---

## 8. Practice tasks

1. Create a Deployment `api` (`httpd:2.4`, 2 replicas). Expose it with a
   ClusterIP Service on port 9000 -> 80. Test from a busybox Pod.
2. Change it to NodePort with nodePort 31000. Reach it from your
   laptop with `minikube service`.
3. Create the Service in namespace `nginx`
   ([`namespaces/nginx-namespaces.yaml`](../namespaces/nginx-namespaces.yaml)) and call it from the `default`
   namespace. What hostname did you use?
4. Make a headless Service for `api` and show that nslookup returns
   2 IPs. Scale to 4 and check again.
5. Use a named port `http` in the Deployment and `targetPort: http` in
   the Service. Verify it works.

---

## 9. Quiz

1. In `services/nginx-services.yaml`, which port does a client use and
   which port does nginx listen on?
2. Name the 4 Service types plus the special "headless" form.
3. What is the full DNS name of `nginx-service` in namespace `default`?
4. A Service has no endpoints. Give two possible reasons.
5. How do you get an EXTERNAL-IP for a LoadBalancer Service on Minikube?

<details><summary>Quiz answers</summary>

1. Clients use port 8080 (the Service port). nginx listens on 80
   (the targetPort).
2. ClusterIP, NodePort, LoadBalancer, ExternalName. Headless is a
   ClusterIP Service with `clusterIP: None`.
3. `nginx-service.default.svc.cluster.local`
4. The selector does not match Pod labels, or the matching Pods are
   not Ready (or there are no Pods at all).
5. Run `minikube tunnel` in a separate terminal and keep it running.

</details>

---

## 10. Next topic

[Topic 09: Namespaces](../namespaces/namespaces.md)

---

**Previous:** [Topic 07: Deployments](../deployments/deployments.md) | **Next:** [Topic 09: Namespaces](../namespaces/namespaces.md) | [Back to README](../README.md)
