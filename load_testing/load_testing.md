# Topic 23: Load Testing with k6

| | |
|---|---|
| **Level** | Advanced |
| **Time** | ~60 min |
| **Prereqs** | [Services](../services/services.md), [Probes & Resources](../probes_resources/probes_resources.md), [Autoscaling (HPA)](../autoscaling_hpa/autoscaling_hpa.md), [Monitoring & Logging](../monitoring_logging/monitoring_logging.md) |
| **Files** | [k6-nginx-test.js](k6-nginx-test.js), [k6-pod.yaml](k6-pod.yaml), [k6-testrun.yaml](k6-testrun.yaml), [scripts/install-k6-ubuntu.sh](../scripts/install-k6-ubuntu.sh), [scripts/install-k6-macos.sh](../scripts/install-k6-macos.sh), [scripts/install-k6-windows.ps1](../scripts/install-k6-windows.ps1), [deployments/nginx-deployments.yaml](../deployments/nginx-deployments.yaml), [services/nginx-services.yaml](../services/nginx-services.yaml) |

> Run all commands from the repo root.

---

## 1. What is it?

k6 is an open-source LOAD TESTING tool from Grafana Labs.

You write a small test in JavaScript. k6 starts many "virtual users" (VUs). Each VU runs your test function again and again, like a real user clicking your site. k6 measures how fast and how stable your app is.

| Term | Meaning |
|---|---|
| **VU** | one virtual user (runs the default function in a loop) |
| **Iteration** | one run of the default function |
| **Stage** | "go to N VUs during T time" (ramp up / hold / ramp down) |
| **Check** | a test on one response (status is 200?). Does not stop the test. |
| **Threshold** | a PASS/FAIL rule for the whole test (p95 < 500ms). If a threshold fails, k6 exits with a non-zero code (99), so CI can fail the build. |

k6 itself is a single Go program. The test is JavaScript, but it is NOT Node.js: you cannot use npm packages that need Node.

---

## 2. Why do we need it?

- Know your limits: how many users can nginx handle before it gets slow?
- Check that HPA ([Autoscaling (HPA)](../autoscaling_hpa/autoscaling_hpa.md)) really adds Pods when load goes up, and removes them after.
- Find good resource requests/limits ([Probes & Resources](../probes_resources/probes_resources.md)) with real numbers.
- Catch performance bugs in CI before users see them.
- Check that rolling updates and PDBs ([Production Best Practices](../production_best_practices/production_best_practices.md)) keep errors at 0 while under load.

---

## 3. Key concepts

### a) Important built-in metrics in the k6 summary

| Metric | Meaning |
|---|---|
| `http_req_duration` | total time of a request (send + wait + receive). Shows avg, min, med, max, p(90), p(95). |
| `p(95)` | 95% of requests were FASTER than this value. Better than the average, because it shows what slow users feel. |
| `http_req_failed` | rate of failed requests (status >= 400 or network error). 0.00% is the goal. |
| `http_reqs` | total requests and requests per second (RPS). |
| `vus` / `vus_max` | current / max virtual users. |
| `iterations` | how many times the default function ran. |
| `checks` | % of checks that passed. |

### b) Load test types

| Type | Description |
|---|---|
| Smoke | 1-2 VUs, 1 min. "Does it work at all?" |
| Load | normal expected traffic, 10-30 min. |
| Stress | more than normal, find the breaking point. |
| Spike | very fast jump in users. |
| Soak | normal load for hours (memory leaks). |

### c) Where does traffic go?

`kubectl port-forward` sends ALL traffic to ONE Pod, even when you forward a Service. Good for a quick test of the app, but NOT good to test load balancing or HPA (new Pods get no traffic).

For HPA tests, run k6 INSIDE the cluster and call the Service DNS name (`http://nginx-service:8080`). kube-proxy then spreads the load.

### d) k6 Operator

A Kubernetes operator that runs k6 tests as Pods from a `TestRun` custom resource. It can split one test over many Pods (parallelism). Good for big or scheduled in-cluster tests.

---

## 4. Example code

### a) The repo test: [load_testing/k6-nginx-test.js](k6-nginx-test.js)

Open the file and read it together with these notes (annotated version):

```javascript
import http from 'k6/http';            // HTTP client module
import { check, sleep } from 'k6';    // check() and sleep()

// Target URL. Change it without editing the file:
//   BASE_URL=http://my-host:8080 k6 run ...
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export const options = {
  stages: [                            // ramp virtual users
    { duration: '30s', target: 10 },   // 0 -> 10 VUs in 30s
    { duration: '1m', target: 10 },    // stay at 10 VUs for 1 minute
    { duration: '30s', target: 50 },   // spike: 10 -> 50 VUs
    { duration: '30s', target: 0 },    // ramp down to 0
  ],                                   // total: about 2.5 minutes
  thresholds: {                        // PASS/FAIL rules
    http_req_failed: ['rate<0.01'],    // less than 1% errors
    http_req_duration: ['p(95)<500'],  // 95% faster than 500 ms
  },
};

export default function () {           // each VU runs this in a loop
  const res = http.get(`${BASE_URL}/`);   // GET the home page
  check(res, {                         // record pass/fail, never stop
    'status is 200': (r) => r.status === 200,
    'body has nginx welcome': (r) => r.body.includes('Welcome to nginx'),
  });
  sleep(1);                            // think time: 1s per iteration
}
```

### b) Run the same test INSIDE the cluster (for HPA)

Saved as [load_testing/k6-pod.yaml](k6-pod.yaml). It mounts the script from a ConfigMap named `k6-script`, which you create from the repo file (`kubectl create configmap k6-script --from-file=load_testing/k6-nginx-test.js`), so the script lives in only one place.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: k6-load
spec:
  restartPolicy: Never                 # run once, then stop
  containers:
  - name: k6
    image: grafana/k6:1.1.0            # pinned k6 image
    args: ["run", "/scripts/k6-nginx-test.js"]
    env:
    - name: BASE_URL                   # call the Service by DNS name
      value: "http://nginx-service:8080"
    volumeMounts:
    - name: script
      mountPath: /scripts              # the test file is here
  volumes:
  - name: script
    configMap:
      name: k6-script                  # created from the repo file
```

### c) k6 Operator TestRun (operator must be installed first)

Saved as [load_testing/k6-testrun.yaml](k6-testrun.yaml):

```yaml
apiVersion: k6.io/v1alpha1
kind: TestRun
metadata:
  name: nginx-load
spec:
  parallelism: 2                       # split load over 2 runner Pods
  script:
    configMap:
      name: k6-script
      file: k6-nginx-test.js
  arguments: -e BASE_URL=http://nginx-service:8080
```

---

## 5. Hands-on lab

1. Install k6 with the repo scripts:

   | OS | Command |
   |---|---|
   | Ubuntu | `bash scripts/install-k6-ubuntu.sh` |
   | macOS | `bash scripts/install-k6-macos.sh` |
   | Windows | ``powershell -ExecutionPolicy Bypass -File scripts\install-k6-windows.ps1`` |

   Check:

   ```bash
   k6 version
   ```

   You should see `k6 v1.x.x ...`.

2. Deploy nginx:

   ```bash
   minikube start
   kubectl apply -f deployments/nginx-deployments.yaml
   kubectl apply -f services/nginx-services.yaml
   kubectl get pods -l app=nginx
   ```

3. Forward the Service to your laptop (keep this terminal open):

   ```bash
   kubectl port-forward svc/nginx-service 8080:8080
   ```

   Test: `curl -s http://localhost:8080 | head -4`

4. Run the test (new terminal, from the repo root):

   ```bash
   k6 run load_testing/k6-nginx-test.js
   ```

   k6 prints a live progress bar, then a summary. It looks similar to:

   ```text
   THRESHOLDS
     http_req_duration
     ok 'p(95)<500' p(95)=12.3ms
     http_req_failed
     ok 'rate<0.01' rate=0.00%

   TOTAL RESULTS
     checks_succeeded.....: 100.00% 4180 out of 4180
     HTTP
     http_req_duration....: avg=6.1ms min=1.2ms med=4.9ms
                            max=88ms p(90)=10ms p(95)=12.3ms
     http_req_failed......: 0.00%  0 out of 2090
     http_reqs............: 2090   13.9/s
     EXECUTION
     iterations...........: 2090   13.9/s
     vus..................: 1      min=1 max=50
     vus_max..............: 50
   ```

5. Read the results:

   - `p(95)=12.3ms` -> 95% of requests took less than 12.3 ms. Good.
   - `http_req_failed 0.00%` -> no errors. Good.
   - Both thresholds passed -> exit code 0. Check with: `echo $?`
   - `checks 100%` -> every response was 200 and had "Welcome to nginx".
   - `vus max=50` -> the spike stage reached 50 VUs.
   - `http_reqs 13.9/s` -> each VU sends about 1 request per second (because of `sleep(1)`), so RPS follows the number of VUs.

6. Use another URL with `BASE_URL` (no file change):

   ```bash
   BASE_URL=http://localhost:8080 k6 run load_testing/k6-nginx-test.js
   ```

   Windows PowerShell:

   ```powershell
   $env:BASE_URL="http://localhost:8080"; k6 run load_testing/k6-nginx-test.js
   ```

   Or with a flag on any OS:

   ```bash
   k6 run -e BASE_URL=http://localhost:8080 \
     load_testing/k6-nginx-test.js
   ```

7. Override load from the command line (quick smoke test):

   ```bash
   k6 run --vus 2 --duration 20s load_testing/k6-nginx-test.js
   ```

8. Combine with HPA ([Autoscaling (HPA)](../autoscaling_hpa/autoscaling_hpa.md)). Make sure metrics-server is on, nginx has CPU requests, and the HPA from that topic exists (e.g. `nginx-hpa` from `autoscaling_hpa/nginx-hpa.yaml`).

   Terminal A:

   ```bash
   kubectl get hpa -w
   ```

   Terminal B:

   ```bash
   kubectl get pods -l app=nginx -w
   ```

   Terminal C - run k6 IN the cluster so load is spread:

   ```bash
   kubectl create configmap k6-script \
     --from-file=load_testing/k6-nginx-test.js
   kubectl apply -f load_testing/k6-pod.yaml
   kubectl logs -f k6-load
   ```

   Watch terminal A: TARGETS (CPU %) goes up, then REPLICAS goes up. After the test, replicas go down again after ~5 minutes (the default scale-down stabilization window).

   Tip: nginx serving a static page uses very little CPU. If the HPA does not scale, use a lower CPU request or more VUs (edit the stage targets or remove `sleep` in a copy of the script).

9. Clean up:

   ```bash
   kubectl delete -f load_testing/k6-pod.yaml
   kubectl delete configmap k6-script
   ```

10. (Optional) k6 Operator:

    ```bash
    helm repo add grafana https://grafana.github.io/helm-charts
    helm install k6-operator grafana/k6-operator \
      -n k6-operator-system --create-namespace
    kubectl create configmap k6-script \
      --from-file=load_testing/k6-nginx-test.js
    kubectl apply -f load_testing/k6-testrun.yaml    # the TestRun from 4c
    kubectl get testrun,pods
    ```

---

## 6. Common mistakes & troubleshooting

- "connection refused" errors -> port-forward is not running, or wrong port. Test with curl first.
- port-forward dies under heavy load ("lost connection to pod") -> port-forward is not built for load. Run k6 in the cluster.
- HPA does not scale with port-forward -> all traffic goes to one Pod. Use the in-cluster Pod (section 4b).
- HPA shows `<unknown>/50%` -> metrics-server is missing or the container has no CPU request.
- Testing from a weak laptop -> the LAPTOP becomes the bottleneck, not the app. Watch your own CPU. Keep VUs reasonable on Minikube.
- Thinking "avg is fine, so all is fine" -> look at p(95) and max.
- No `sleep()` in the default function -> each VU sends requests as fast as possible. This is a stress test, not a normal user pattern.
- Never load test systems you do not own or have no permission to test.
- In CI, forgetting that k6 exits with code 99 when thresholds fail. That is a feature: let the pipeline fail.

---

## 7. Cheat sheet

| Command | Purpose |
|---|---|
| `k6 version` | check install |
| `k6 run script.js` | run a test |
| `k6 run -e BASE_URL=http://host:8080 s.js` | pass an env variable |
| `BASE_URL=http://host:8080 k6 run s.js` | same, Linux/macOS shell |
| `k6 run --vus 20 --duration 1m s.js` | override load |
| `k6 run --summary-export=out.json s.js` | save summary as JSON |
| `k6 run --out json=raw.json s.js` | save every data point |
| `k6 new test.js` | create a sample script |
| `kubectl port-forward svc/nginx-service 8080:8080` | reach nginx locally |
| `kubectl get hpa -w` | watch autoscaling live |
| `kubectl top pods -l app=nginx` | CPU/memory during the test |
| `kubectl create configmap k6-script --from-file=load_testing/k6-nginx-test.js` | put script in the cluster |

---

## 8. Practice tasks

1. Copy the repo script and make it a smoke test: 1 VU for 30s. Run it.
2. Make a stress version: ramp to 100 VUs, remove `sleep()`. At which point does p(95) go above 500 ms on your laptop?
3. Add a threshold `checks: ['rate>0.99']` to a copy of the script. Then point `BASE_URL` to a wrong path (e.g. `http://localhost:8080/x`). Which checks and thresholds fail? What is the exit code?
4. Run the in-cluster test while the HPA is active. Write down: start replicas, max replicas, time to scale up, time to scale down.
5. During a k6 run, do a rolling update of nginx (`kubectl set image ... nginx:1.27.3`). Does `http_req_failed` stay at 0%? If not, add a readinessProbe ([Probes & Resources](../probes_resources/probes_resources.md)) and try again.

---

## 9. Quiz

1. What is a VU in k6?
2. What does `p(95)<500` in thresholds mean?
3. What is the difference between a check and a threshold?
4. Why is `kubectl port-forward` a bad way to test HPA?
5. How do you change the target URL of `load_testing/k6-nginx-test.js` without editing it?

<details>
<summary>Quiz answers</summary>

1. A virtual user: a loop that runs the default function again and again, like one real user.
2. 95% of requests must take less than 500 ms, or the test fails.
3. A check tests one response and only records pass/fail. A threshold is a rule on a metric for the whole test; if it fails, k6 exits with a non-zero code.
4. port-forward sends all traffic to ONE Pod, so new Pods made by the HPA get no load. It is also not built for high traffic.
5. Set the `BASE_URL` env variable:

   ```bash
   BASE_URL=http://host:port k6 run load_testing/k6-nginx-test.js
   # or:
   k6 run -e BASE_URL=http://host:port load_testing/k6-nginx-test.js
   ```

</details>

---

**Previous:** [Production Best Practices](../production_best_practices/production_best_practices.md) | **Next:** [Cheat Sheet & Interview Questions](../cheatsheet_interview/cheatsheet_interview.md) | [Back to README](../README.md)
