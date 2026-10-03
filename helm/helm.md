# Topic 19: Helm

| | |
|---|---|
| **Level** | Advanced |
| **Time** | ~60 min |
| **Prereqs** | [Deployments](../deployments/deployments.md), [Services](../services/services.md), [ConfigMaps & Secrets](../configmaps_secrets/configmaps_secrets.md) |
| **Files** | [podinfo-values.yaml](podinfo-values.yaml), [mychart-values.yaml](mychart-values.yaml), [values-prod.yaml](values-prod.yaml) (compare with [deployments/nginx-deployments.yaml](../deployments/nginx-deployments.yaml) and [services/nginx-services.yaml](../services/nginx-services.yaml)) |

> Run all commands from the repo root.

---

## 1. What is it?

Helm is the **PACKAGE MANAGER for Kubernetes**. Like apt, brew or npm, but for Kubernetes apps.

| Term | Meaning |
|---|---|
| **Chart** | a package: a folder of YAML templates + default values |
| **Values** | your settings (replicas, image tag, ports ...) |
| **Release** | one installed copy of a chart in your cluster |
| **Repository** | a web server (or OCI registry) that stores charts |

Helm takes the templates, fills them with values, and sends the final YAML to the cluster. It also remembers every version (revision) so you can roll back.

> Note: Helm 4 was released in late 2025. Helm 3 is still common. All commands in this file work the same in Helm 3 and Helm 4.

---

## 2. Why do we need it?

- Real apps have MANY YAML files (Deployment, Service, Ingress, ConfigMap, RBAC, HPA ...). Helm installs them as ONE unit.
- Same app, many environments: one chart + `values-dev.yaml`, `values-prod.yaml`. No copy-paste of YAML.
- Easy install of popular software: Prometheus, Grafana, Argo CD, cert-manager, databases ... one command each.
- Upgrade and rollback with history.
- Clean uninstall: removes all objects the chart created.

---

## 3. Key concepts

### a) Chart structure (from `helm create mychart`)

```text
mychart/
  Chart.yaml          -> name, chart version, appVersion
  values.yaml         -> default values
  charts/             -> sub-charts (dependencies)
  templates/          -> YAML templates
    deployment.yaml
    service.yaml
    ingress.yaml
    hpa.yaml
    serviceaccount.yaml
    _helpers.tpl      -> reusable template snippets (names, labels)
    NOTES.txt         -> text printed after install
    tests/            -> "helm test" Pods
  .helmignore         -> files to skip when packaging
```

### b) Chart version vs appVersion (in Chart.yaml)

- **version**: version of the CHART (change it on every chart change)
- **appVersion**: version of the APP inside (e.g. nginx 1.27.2)

### c) Templates use Go templates

| Template | Meaning |
|---|---|
| `{{ .Values.replicaCount }}` | value from values.yaml |
| `{{ .Release.Name }}` | release name you chose |
| `{{ .Chart.AppVersion }}` | from Chart.yaml |
| `{{ include "mychart.fullname" . }}` | helper from `_helpers.tpl` |
| `{{- if .Values.ingress.enabled }} ... {{- end }}` | condition |
| `{{ .Values.x \| default "abc" \| quote }}` | pipes |

### d) Value priority (last one wins)

```text
values.yaml in chart  <  -f my-values.yaml  <  --set key=value
```

### e) Release and revision

Every install/upgrade/rollback creates a new REVISION. Helm stores release data as Secrets in the release namespace (type `helm.sh/release.v1`).

### f) Repositories

- Classic HTTP repo: `helm repo add <name> <url>`
- OCI registry: `helm install x oci://registry/path/chart` (no `repo add` needed)
- Find charts on <https://artifacthub.io>

---

## 4. Example YAML

### a) A values file for the public "podinfo" chart

Saved as [helm/podinfo-values.yaml](podinfo-values.yaml):

```yaml
replicaCount: 2                # run 2 Pods
ui:
  message: "Hello from Helm"   # text shown on the web page
resources:
  requests:
    cpu: 50m                   # always set requests/limits
    memory: 64Mi
  limits:
    memory: 128Mi
```

### b) Our own chart

After `helm create mychart`, these are the important values to change. They are saved as [helm/mychart-values.yaml](mychart-values.yaml) so you can pass them with `-f` (or copy them into `mychart/values.yaml` by hand):

```yaml
replicaCount: 3                # same as repo nginx-deployment
image:
  repository: nginx
  tag: "1.27.2"                # PIN the tag (default uses appVersion)
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  port: 80                     # helm create ALSO uses this value as the
                               # containerPort. nginx listens on 80, so
                               # keep 80 here (or change the template)
ingress:
  enabled: false               # turn on later with --set
resources:
  requests:
    cpu: 100m
    memory: 64Mi
  limits:
    memory: 128Mi
```

### c) A template (`mychart/templates/service.yaml`, simplified)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "mychart.fullname" . }}   # e.g. "web-mychart"
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}           # ClusterIP from values
  ports:
    - port: {{ .Values.service.port }}       # 80 from values
      targetPort: http                       # named container port
      protocol: TCP
      name: http
  selector:
    {{- include "mychart.selectorLabels" . | nindent 4 }}
```

### d) An environment file

Saved as [helm/values-prod.yaml](values-prod.yaml):

```yaml
replicaCount: 5
image:
  tag: "1.27.3"
```

---

## 5. Hands-on lab

1. Install Helm:

   | OS | Command |
   |---|---|
   | macOS | `brew install helm` |
   | Windows | `winget install Helm.Helm` (or: `choco install kubernetes-helm`) |
   | Ubuntu | `sudo snap install helm --classic` (or see <https://helm.sh/docs/intro/install/>) |

   Check:

   ```bash
   helm version
   ```

   You should see a version like v3.x or v4.x.

2. Add a repository and search it:

   ```bash
   helm repo add podinfo https://stefanprodan.github.io/podinfo
   helm repo update
   helm search repo podinfo
   helm show values podinfo/podinfo | less
   ```

3. Install a release with your values:

   ```bash
   helm install my-podinfo podinfo/podinfo -f helm/podinfo-values.yaml
   helm list
   kubectl get pods,svc -l app.kubernetes.io/name=my-podinfo
   ```

   You should see 2 Pods and Service `my-podinfo` on port 9898.

4. Open it:

   ```bash
   kubectl port-forward svc/my-podinfo 9898:9898
   ```

   Open <http://localhost:9898>. You see "Hello from Helm". Ctrl+C.

5. Upgrade (change a value):

   ```bash
   helm upgrade my-podinfo podinfo/podinfo -f helm/podinfo-values.yaml \
     --set replicaCount=3 --set ui.message="Version 2"
   helm history my-podinfo
   ```

   You see REVISION 1 and 2.

   ```bash
   helm get values my-podinfo        # values used now
   ```

6. Roll back to revision 1:

   ```bash
   helm rollback my-podinfo 1
   helm history my-podinfo
   ```

   A NEW revision 3 is created (a copy of revision 1). Replicas = 2.

7. Uninstall:

   ```bash
   helm uninstall my-podinfo
   helm list                          # empty
   ```

8. Create your own chart (it is created in the repo root; it is removed in step 10):

   ```bash
   helm create mychart
   tree mychart          # or: ls -R mychart
   ```

   Either edit `mychart/values.yaml` as in section 4b, or pass [helm/mychart-values.yaml](mychart-values.yaml) with `-f`. Then:

   ```bash
   helm lint mychart -f helm/mychart-values.yaml
   helm template web mychart -f helm/mychart-values.yaml | less     # render YAML, no install
   helm template web mychart -f helm/mychart-values.yaml --set replicaCount=1 \
     | grep replicas
   ```

   You should see `replicas: 1`.

9. Install your chart in its own namespace:

   ```bash
   helm install web mychart -n web --create-namespace -f helm/mychart-values.yaml
   kubectl get all -n web
   helm upgrade web mychart -n web -f helm/mychart-values.yaml -f helm/values-prod.yaml
   kubectl get deploy -n web -o wide     # 5 replicas, nginx:1.27.3
   ```

10. Package it (makes `mychart-0.1.0.tgz`) and clean up:

    ```bash
    helm package mychart
    helm uninstall web -n web
    kubectl delete ns web
    rm -rf mychart mychart-0.1.0.tgz
    ```

---

## 6. Common mistakes & troubleshooting

- `Error: INSTALLATION FAILED: cannot re-use a name that is still in use` -> the release exists. Use `helm upgrade --install` instead.
- Forgot `-n <namespace>` on upgrade/uninstall -> "release not found". Releases are per namespace.
- YAML indentation errors in templates -> run `helm template` and `helm lint` before install. Use `nindent`, not `indent`, after newlines.
- `--set` with lists or dots is hard: `--set 'a.b[0].c=x'`. Prefer a values file.
- Upgrade overwrote values: `helm upgrade` without `-f` or `--reuse-values` goes back to chart defaults + only what you pass now. Always pass the same `-f` files on every upgrade.
- Release stuck in `pending-upgrade` after a crash: run `helm history` then `helm rollback <release> <good-revision>`.
- Changing a ConfigMap does not restart Pods. Add a checksum annotation in the Deployment template:

  ```yaml
  checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
  ```

- Secrets in values files committed to Git -> do NOT. Use external-secrets, sealed-secrets or SOPS.
- Image tag empty -> `helm create` uses appVersion as tag. Pin it.
- Pods fail probes after you set `service.port` to 8080 in a `helm create` chart: the template uses `service.port` as containerPort too, but nginx listens on 80. Keep 80, or add a separate containerPort value.

---

## 7. Cheat sheet

| Command | Purpose |
|---|---|
| `helm repo add <name> <url>` | add a chart repository |
| `helm repo update` | refresh repo index |
| `helm search repo <word>` | find charts in added repos |
| `helm search hub <word>` | search Artifact Hub |
| `helm show values <repo/chart>` | default values of a chart |
| `helm install <rel> <chart> -f v.yaml` | install a release |
| `helm upgrade --install <rel> <chart>` | install or upgrade (CI safe) |
| `helm upgrade <rel> <chart> --set k=v` | upgrade with a new value |
| `helm list -A` | releases in all namespaces |
| `helm status <rel>` | release status + NOTES |
| `helm history <rel>` | all revisions |
| `helm rollback <rel> <rev>` | go back to a revision |
| `helm uninstall <rel>` | delete the release |
| `helm get values <rel>` | values used by a release |
| `helm get manifest <rel>` | final YAML applied |
| `helm create <name>` | new chart skeleton |
| `helm lint <chart-dir>` | check a chart for errors |
| `helm template <rel> <chart-dir>` | render YAML locally |
| `helm install <rel> <chart> --dry-run` | simulate install |
| `helm package <chart-dir>` | make a .tgz |
| `helm dependency update <chart-dir>` | download sub-charts |
| `helm pull <repo/chart> --untar` | download a chart to read it |

---

## 8. Practice tasks

1. Convert [deployments/nginx-deployments.yaml](../deployments/nginx-deployments.yaml) and [services/nginx-services.yaml](../services/nginx-services.yaml) into a chart `nginx-app`. Make replicas, image tag and service port values.
2. Add an Ingress template to your chart that uses host `nginx.example.com` (like [ingress/nginx-ingress.yaml](../ingress/nginx-ingress.yaml)). Turn it on only when `ingress.enabled=true`.
3. Create `values-dev.yaml` (1 replica) and `values-prod.yaml` (3 replicas). Install both into namespaces `dev` and `prod`.
4. Upgrade with a broken image tag. Watch Pods fail. Fix it with `helm rollback`.
5. Run `helm get manifest` on a release and compare it with `helm template` output.

---

## 9. Quiz

1. What is the difference between a chart and a release?
2. Which wins: a value in values.yaml, in `-f` file, or in `--set`?
3. What does `helm template` do?
4. After `helm rollback app 1` from revision 2, what is the new revision number?
5. In Chart.yaml, what is the difference between `version` and `appVersion`?

<details>
<summary>Quiz answers</summary>

1. A chart is the package (templates + values). A release is one installed copy of that chart in a cluster, with its own name.
2. `--set` wins, then `-f` files (last file wins), then values.yaml.
3. It renders the templates with values into plain YAML on your machine. Nothing is sent to the cluster.
4. Revision 3. Rollback creates a new revision.
5. `version` is the chart's own version. `appVersion` is the version of the application the chart deploys.

</details>

---

**Previous:** [Network Policies](../network_policies/network_policies.md) | **Next:** [Monitoring & Logging](../monitoring_logging/monitoring_logging.md) | [Back to README](../README.md)
