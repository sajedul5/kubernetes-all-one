# Topic 18: Network Policies

| | |
|---|---|
| **Level** | Advanced |
| **Time** | ~50 min |
| **Prereqs** | [Services](../services/services.md), [Namespaces](../namespaces/namespaces.md), [RBAC & Security](../rbac_security/rbac_security.md) |
| **Files** | [default-deny-ingress.yaml](default-deny-ingress.yaml), [allow-frontend-to-nginx.yaml](allow-frontend-to-nginx.yaml), [frontend-egress.yaml](frontend-egress.yaml), [deployments/nginx-deployments.yaml](../deployments/nginx-deployments.yaml), [services/nginx-services.yaml](../services/nginx-services.yaml) |

> Run all commands from the repo root.

---

## 1. What is it?

A NetworkPolicy is a **FIREWALL RULE for Pods**.

It says which Pods may talk to which Pods (and on which ports).

- **Ingress rule** -> traffic coming IN to the selected Pods
- **Egress rule** -> traffic going OUT from the selected Pods

By default, Kubernetes allows ALL traffic: every Pod can talk to every other Pod, in every namespace. NetworkPolicy changes this.

> **IMPORTANT:** Kubernetes itself does not enforce NetworkPolicy. The network plugin (CNI) does it. Calico, Cilium and Antrea enforce policies. The default Minikube network does NOT. On Minikube you must start with:
>
> ```bash
> minikube start --cni=calico
> ```
>
> If the CNI does not support policies, your NetworkPolicy objects are accepted but silently do NOTHING.

---

## 2. Why do we need it?

- **Zero trust**: if one Pod is hacked, the attacker should not reach the database or every other service.
- **Separate teams/environments**: "dev" Pods should not call "prod" Pods.
- **Compliance**: many security standards require network segmentation.
- **Stop data leaks**: limit egress so Pods cannot send data to the internet.

---

## 3. Key concepts

### a) podSelector (in spec)

Chooses the Pods the policy is ABOUT. `podSelector: {}` = all Pods in the namespace.

### b) policyTypes

`["Ingress"]`, `["Egress"]` or both. If a type is listed and no rule allows the traffic, it is denied.

### c) Isolation

A Pod is "isolated" for ingress as soon as ANY policy with Ingress selects it. Then only traffic allowed by some policy can enter. Policies are ADDITIVE (union). There is no "deny" rule. Default deny = a policy that selects Pods but allows nothing.

### d) Who is allowed (from / to)

| Selector | Meaning |
|---|---|
| `podSelector` | Pods with these labels (same namespace) |
| `namespaceSelector` | all Pods in matching namespaces |
| both in ONE item | Pods with label X IN namespaces with label Y |
| `ipBlock` | IP ranges (CIDR), e.g. `10.0.0.0/8` |

Careful with YAML dashes:

```yaml
# = AND (one item)
from:
- namespaceSelector: {...}
  podSelector: {...}
```

```yaml
# = OR (two items)
from:
- namespaceSelector: {...}
- podSelector: {...}
```

### e) Ports

The port in a policy is the POD (container) port, not the Service port. Our `nginx-service` is 8080 -> targetPort 80. The policy must allow port 80.

### f) Namespace labels

Every namespace has an automatic label:

```text
kubernetes.io/metadata.name=<namespace-name>
```

Use it in `namespaceSelector`.

### g) DNS and egress

If you deny egress, Pods also cannot reach DNS (CoreDNS in `kube-system`, port 53 UDP and TCP). Always allow DNS when you limit egress.

### h) Policies are stateful

If a request is allowed, the reply is allowed automatically.

---

## 4. Example YAML

All in namespace `default`. Each policy is its own file in this folder.

**1) Default deny ALL ingress** - [network_policies/default-deny-ingress.yaml](default-deny-ingress.yaml)

```yaml
# Default deny ALL ingress to all Pods in this namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}              # {} = every Pod in the namespace
  policyTypes:
  - Ingress                    # isolate ingress; no rules = allow none
```

**2) Allow only `role=frontend` Pods to reach nginx on port 80** - [network_policies/allow-frontend-to-nginx.yaml](allow-frontend-to-nginx.yaml)

```yaml
# Allow only Pods with label role=frontend to reach nginx on port 80
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-nginx
spec:
  podSelector:
    matchLabels:
      app: nginx               # policy is about the nginx Pods
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend       # only these Pods may connect
    ports:
    - protocol: TCP
      port: 80                 # container port, NOT service port 8080
```

**3) Egress: frontend Pods may only talk to nginx and DNS** - [network_policies/frontend-egress.yaml](frontend-egress.yaml)

```yaml
# Egress: frontend Pods may only talk to nginx and DNS
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress
spec:
  podSelector:
    matchLabels:
      role: frontend
  policyTypes:
  - Egress                     # isolate egress for frontend Pods
  egress:
  - to:                        # rule 1: DNS to CoreDNS
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:             # same item = AND (kube-dns Pods there)
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  - to:                        # rule 2: nginx Pods on port 80
    - podSelector:
        matchLabels:
          app: nginx
    ports:
    - protocol: TCP
      port: 80
```

Extra example - allow from another namespace `monitoring`:

```yaml
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
```

---

## 5. Hands-on lab

1. Start a Minikube cluster WITH Calico. Use a new profile so your normal cluster is not touched:

   ```bash
   minikube start -p netpol --cni=calico
   kubectl get pods -n kube-system -l k8s-app=calico-node
   ```

   Wait until calico-node is Running (1/1). This can take 1-3 minutes. (Without `-p`, delete your old cluster first: `minikube delete`.)

2. Deploy nginx from the repo:

   ```bash
   kubectl apply -f deployments/nginx-deployments.yaml
   kubectl apply -f services/nginx-services.yaml
   kubectl get pods -l app=nginx
   ```

3. Test BEFORE any policy (everything is open):

   ```bash
   kubectl run test --rm -it --image=busybox:1.36 --restart=Never \
     -- wget -qO- -T 3 http://nginx-service:8080
   ```

   You should see the HTML "Welcome to nginx!".

4. Apply the policies (all YAML files in the folder):

   ```bash
   kubectl apply -f network_policies/
   kubectl get networkpolicy
   ```

   You should see 3 policies.

5. Test from a Pod WITHOUT the frontend label:

   ```bash
   kubectl run test --rm -it --image=busybox:1.36 --restart=Never \
     -- wget -qO- -T 3 http://nginx-service:8080
   ```

   Now you see: `wget: download timed out`. Blocked.

6. Test from a Pod WITH `role=frontend`:

   ```bash
   kubectl run fe --rm -it --image=busybox:1.36 --restart=Never \
     --labels=role=frontend -- wget -qO- -T 3 http://nginx-service:8080
   ```

   You see "Welcome to nginx!" again. Allowed.

7. Test egress from the frontend Pod to the internet:

   ```bash
   kubectl run fe2 --rm -it --image=busybox:1.36 --restart=Never \
     --labels=role=frontend -- wget -qO- -T 3 http://example.com
   ```

   DNS works (allowed) but the connection times out (egress blocked).

8. Look at a policy in plain words:

   ```bash
   kubectl describe networkpolicy allow-frontend-to-nginx
   ```

9. Clean up:

   ```bash
   kubectl delete -f network_policies/
   minikube delete -p netpol      # or keep it for Production Best Practices
   ```

   (See [Production Best Practices](../production_best_practices/production_best_practices.md).)

---

## 6. Common mistakes & troubleshooting

- Policy has no effect -> your CNI does not enforce it. On Minikube use `--cni=calico` (or `--cni=cilium`). Check: `kubectl get pods -A | grep -iE "calico|cilium"`.
- Using the Service port (8080) instead of the Pod port (80) in `ports`.
- Default deny egress without a DNS rule -> every name lookup fails (`bad address 'nginx-service'`).
- AND vs OR mix-up: an extra `-` before `podSelector` makes it a separate rule (OR) and opens much more than you wanted.
- `namespaceSelector` with a custom label that the namespace does not have. Use `kubernetes.io/metadata.name` or label the namespace.
- Labels typo: `app: ngnix`. Check with `kubectl get pods --show-labels`.
- Ingress controller cannot reach Pods after default deny: allow the ingress controller namespace (e.g. `ingress-nginx`) to your app.
- Probes: kubelet health checks from the node are normally allowed by Calico, but some CNIs need extra rules. Check Pod events if probes start to fail.
- Testing with `curl` on the node or `kubectl port-forward` does not test Pod-to-Pod rules. Always test from inside a Pod.

---

## 7. Cheat sheet

| Command | Purpose |
|---|---|
| `minikube start --cni=calico` | cluster that enforces netpol |
| `kubectl get networkpolicy -A` (short: `netpol`) | list policies |
| `kubectl describe netpol <name>` | read rules in plain text |
| `kubectl get pods --show-labels` | check Pod labels |
| `kubectl get ns --show-labels` | check namespace labels |
| `kubectl label ns team-a team=a` | add a namespace label |
| `kubectl run t --rm -it --image=busybox:1.36 --restart=Never --labels=role=frontend -- wget -qO- -T 3 http://svc:port` | test as a labeled Pod |
| `kubectl delete netpol --all` | remove all policies in ns |

---

## 8. Practice tasks

1. Write a `default-deny-all` policy that blocks BOTH ingress and egress for every Pod in a namespace `secure`. Prove that DNS also fails.
2. Add a policy that allows only DNS egress in `secure`. Prove that `nslookup` works but `wget` to other Pods does not.
3. Create namespaces `frontend` and `backend`. Allow Pods in `frontend` to reach nginx in `backend` on port 80. Block all other namespaces.
4. Deploy the mongo StatefulSet from [statefulset/](../statefulset/statefulset.md) and allow port 27017 only from Pods with label `app=api`.
5. Use `ipBlock` to allow egress to `0.0.0.0/0` except `169.254.169.254/32` (the cloud metadata IP).

---

## 9. Quiz

1. What happens to a NetworkPolicy on a cluster whose CNI does not support it?
2. What does `podSelector: {}` with policyTypes `[Ingress]` and no rules do?
3. A Service maps port 8080 to targetPort 80. Which port goes into the NetworkPolicy?
4. Why must you allow port 53 when you deny egress?
5. In `from:`, is `- namespaceSelector + podSelector` in ONE item an AND or an OR?

<details>
<summary>Quiz answers</summary>

1. It is stored, but nothing is enforced. Traffic is still allowed.
2. Default deny ingress: no Pod in the namespace accepts any incoming traffic, unless another policy allows it.
3. Port 80 (the Pod/container port).
4. Pods need DNS (CoreDNS, port 53 UDP/TCP) to turn Service names into IPs. Without it, every name lookup fails.
5. AND. Pods with that label inside namespaces with that label.

</details>

---

**Previous:** [RBAC & Security](../rbac_security/rbac_security.md) | **Next:** [Helm](../helm/helm.md) | [Back to README](../README.md)
