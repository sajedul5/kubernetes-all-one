# Topic 01: Containers and Docker Basics

| | |
|---|---|
| **Level** | Beginner |
| **Time** | ~60 min |
| **Prereqs** | [Topic 00: Roadmap](../roadmap/roadmap.md), basic Linux terminal skills |
| **Files** | [`myweb/Dockerfile`](myweb/Dockerfile), [`myweb/index.html`](myweb/index.html), [`../kubernetes_install/docker-minikube-install.md`](../kubernetes_install/docker-minikube-install.md) |

> Run all commands from the repo root.

---

## 1. What is it?

A **container** is a running program that is packed together with everything
it needs: code, libraries, settings and a small file system. It runs in
an isolated box on a Linux kernel.

An **image** is the read-only template (the "recipe") for a container. You
build an image once. You can start many containers from the same image.

**Docker** is a popular tool to build images and run containers.

Kubernetes does NOT build images. Kubernetes RUNS containers from images.
So you must understand images and containers first.

---

## 2. Why do we need it?

The old problem: "It works on my machine, but not on the server."

- Different OS version
- Different library versions
- Missing config

Containers solve this. The image has everything inside. The same image
runs the same way on your laptop, on a test server and in production.

### Containers vs Virtual Machines (VMs)

| Virtual Machine | Container |
|-----------------|-----------|
| Has a full guest OS (GBs) | Shares the host kernel (MBs) |
| Starts in minutes | Starts in seconds or less |
| Strong isolation (hypervisor) | Process isolation (namespaces, cgroups) |
| Few per host | Many per host |

---

## 3. Key concepts

**Image**
A read-only package made of LAYERS. Each Dockerfile instruction adds
a layer. Layers are cached and shared, so builds and downloads are fast.

**Container**
A running (or stopped) instance of an image. It adds a thin writable
layer on top. When you delete the container, that layer is gone.

**Dockerfile**
A text file with steps to build an image (`FROM`, `COPY`, `RUN`, `CMD`...).

**Registry**
A server that stores images. Examples: Docker Hub, GitHub Container
Registry (ghcr.io), AWS ECR, Google Artifact Registry.

**Image name and tag**

- Format: `[registry/][namespace/]name:tag`
- Example: `docker.io/library/nginx:1.27`
- If you leave out the tag, Docker uses `latest`.

**Why `latest` is bad**

- `latest` is just a name. It does not mean "newest stable".
- It can change at any time. Today it is version A, tomorrow version B.
- Two nodes may pull different versions with the same tag.
- You cannot easily know which version is running or roll back.

Always pin a version: `nginx:1.27` (or even a digest: `nginx@sha256:...`).

**Linux features behind containers**

| Feature | What it does |
|---------|--------------|
| namespaces | Isolate what a process can SEE (PIDs, network, mounts) |
| cgroups | Limit what a process can USE (CPU, memory) |

**Container runtime**
The low-level software that runs containers. Kubernetes talks to a
runtime through the CRI (Container Runtime Interface). Common runtimes:
containerd and CRI-O. Note: Kubernetes removed "dockershim" in v1.24,
but images built with Docker still work everywhere (they follow the
OCI standard).

**Port mapping**
A container has its own network. `-p 8080:80` means: host port 8080
goes to container port 80.

**Volumes**
Containers lose their data when deleted. A volume keeps data outside
the container.

---

## 4. Example YAML (and a Dockerfile)

This topic is about Docker, so the main example is a Dockerfile.
The two files live in [`docker_basics/myweb/`](myweb/).

File: [`docker_basics/myweb/index.html`](myweb/index.html)

```html
<h1>Hello from my container</h1>
```

File: [`docker_basics/myweb/Dockerfile`](myweb/Dockerfile)

```dockerfile
# Start from a small, pinned base image (never use "latest")
FROM nginx:1.27-alpine

# Copy our web page into the folder nginx serves
COPY index.html /usr/share/nginx/html/index.html

# Document the port the app listens on (does not publish it)
EXPOSE 80

# nginx base image already has a CMD; shown here for learning
CMD ["nginx", "-g", "daemon off;"]
```

Preview: the same idea as a Kubernetes Pod (you learn this in [Topic 04: Pods](../pod/pod.md)):

```yaml
apiVersion: v1             # core API group
kind: Pod                  # the object type
metadata:
  name: myweb              # Pod name
spec:
  containers:
  - name: web              # container name inside the Pod
    image: nginx:1.27      # pinned image tag, NOT latest
    ports:
    - containerPort: 80    # port the app listens on
```

---

## 5. Hands-on lab

Install Docker first. See the [manual install guide](../kubernetes_install/docker-minikube-install.md)
or the scripts in [`scripts/`](../scripts/) ([`install-minikube-ubuntu.sh`](../scripts/install-minikube-ubuntu.sh),
[`install-minikube-macos.sh`](../scripts/install-minikube-macos.sh),
[`install-minikube-windows.ps1`](../scripts/install-minikube-windows.ps1)).

**Step 1. Check Docker works**

```bash
docker version
docker run --rm hello-world
```

You should see: `Hello from Docker!`

**Step 2. Pull an image**

```bash
docker pull nginx:1.27
docker images
```

You should see: `nginx   1.27   <image id>   ...`

**Step 3. Run a container in the background**

```bash
docker run -d --name web -p 8080:80 nginx:1.27
docker ps
```

You should see: a container named `web`, status `Up`, and
`0.0.0.0:8080->80/tcp`.

**Step 4. Test it**

```bash
curl http://localhost:8080
```

You should see: HTML with `Welcome to nginx!`

**Step 5. Look inside**

```bash
docker logs web
docker exec -it web sh
  # inside the container:
  ls /usr/share/nginx/html
  exit
```

**Step 6. Build your own image** (from the files in `docker_basics/myweb/`)

```bash
docker build -t myweb:1.0 docker_basics/myweb
docker run -d --name myweb -p 8081:80 myweb:1.0
curl http://localhost:8081
```

You should see: `<h1>Hello from my container</h1>`

**Step 7. See the layers**

```bash
docker history myweb:1.0
```

**Step 8. Clean up**

```bash
docker rm -f web myweb
docker rmi myweb:1.0
```

**Bonus: use your image in Minikube** (after [Topic 03](../kubernetes_install/kubernetes_install.md))

```bash
minikube image load myweb:1.0
kubectl run myweb --image=myweb:1.0 --image-pull-policy=Never
```

---

## 6. Common mistakes & troubleshooting

| Problem | Fix |
|---------|-----|
| `permission denied while trying to connect to the Docker daemon` | (Linux) `sudo usermod -aG docker $USER`, then log out and log in. |
| `port is already allocated` | Another program uses that host port. Use a different one: `-p 8090:80` |
| Container exits right away | The main process ended. Check: `docker logs <name>`. A container lives only as long as its main process (PID 1). |
| Changes inside the container are lost | That is normal. Containers are disposable. Put changes in the Dockerfile, or use a volume for data. |
| Using `:latest` and getting a surprise version | Pin the tag. Example: `nginx:1.27` |
| Image is huge | Use small base images (alpine, distroless, slim). Use multi-stage builds. Add a `.dockerignore` file. |
| `manifest unknown` / `not found` when pulling | The tag does not exist. Check spelling and the tag list on the registry. |

---

## 7. Cheat sheet

| Command | What it does |
|---------|--------------|
| `docker pull nginx:1.27` | Download an image |
| `docker images` | List local images |
| `docker run -d -p 8080:80 nginx:1.27` | Run container in background |
| `docker run -it --rm alpine:3.20 sh` | Run interactive shell, auto delete |
| `docker ps` | List running containers |
| `docker ps -a` | List all containers (also stopped) |
| `docker logs -f <name>` | Follow container logs |
| `docker exec -it <name> sh` | Open shell inside container |
| `docker stop <name>` | Stop container |
| `docker rm -f <name>` | Force remove container |
| `docker build -t app:1.0 .` | Build image from Dockerfile |
| `docker tag app:1.0 user/app:1.0` | Add a new name to an image |
| `docker push user/app:1.0` | Upload image to a registry |
| `docker rmi <image>` | Remove image |
| `docker history <image>` | Show image layers |
| `docker inspect <name>` | Full JSON details |
| `docker system prune` | Remove unused data |

---

## 8. Practice tasks

1. Run `httpd:2.4` (Apache) on host port 9090. Open it with curl.
2. Run `redis:7.4`, then use `docker exec` to run `redis-cli ping`.
   You should get `PONG`.
3. Change the myweb `index.html`, build it as `myweb:1.1`, and run both
   1.0 and 1.1 at the same time on different ports.
4. Run `docker run --rm alpine:3.20 echo hi`. Why does it exit at once?
5. Find the size of `nginx:1.27` and `nginx:1.27-alpine`. Which is smaller?

---

## 9. Quiz

1. What is the difference between an image and a container?
2. Why should you not use the `latest` tag?
3. Which two Linux features make containers possible?
4. Does Kubernetes need Docker installed on every node to run images?
5. What does `-p 8080:80` mean?

<details><summary>Quiz answers</summary>

1. An image is a read-only template. A container is a running instance
   of an image, with its own writable layer.
2. `latest` can point to different versions over time. You do not know
   what runs, nodes may differ, and rollback is hard. Pin a version.
3. Namespaces (isolation) and cgroups (resource limits).
4. No. Kubernetes uses a CRI runtime like containerd or CRI-O. Images
   built with Docker are OCI images and run fine.
5. Traffic to host port 8080 is forwarded to port 80 in the container.

</details>

---

## 10. Next topic

[Topic 02: Kubernetes architecture](../kubernetes_architecture/kubernetes_architecture.md)

---

**Previous:** [Topic 00: Roadmap](../roadmap/roadmap.md) | **Next:** [Topic 02: Kubernetes architecture](../kubernetes_architecture/kubernetes_architecture.md) | [Back to README](../README.md)
