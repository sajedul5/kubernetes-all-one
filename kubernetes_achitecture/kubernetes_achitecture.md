# Kubernetes Architecture Diagram

(kubernetes-cluster-architecture.svg)


# Kubernetes Architecture Overview (End-to-End)

Kubernetes is a container orchestration platform that automates the deployment, scaling, and management of containerized applications.

# Key Components:

# Master Node (Control Plane)
The brain of the Kubernetes cluster, responsible for managing the cluster state and orchestrating workloads.

    1. API Server
    Exposes the Kubernetes API. All cluster communication (kubectl commands, other components) goes through this.

    2. etcd
    Distributed key-value store that stores all cluster data (configuration, state, metadata).

    3. Controller Manager
    Runs controllers that regulate the state of the cluster, e.g., node controller, replication controller, endpoints controller.

    4. Scheduler
    Watches for newly created pods without assigned nodes and assigns them to nodes based on resource availability and policies.

# Worker Nodes (Minions)
These nodes run the containerized applications.

    1. Kubelet
    An agent that runs on each node. It ensures containers are running in pods as specified by the control plane.

    2. Kube-proxy
    Handles networking and load balancing within the cluster. Maintains network rules on nodes for pod communication.

    3. Container Runtime
    Software that runs containers (Docker, containerd, CRI-O).

# How Kubernetes Works End to End:
    => User Interaction
    You interact with the cluster by sending commands (via kubectl or dashboard) to the API Server.

    => API Server
    Receives and validates requests, stores desired state in etcd.

    => Scheduler
    Detects new pods needing nodes, assigns pods to nodes based on resources.

    => Controller Manager
    Watches for the desired state and takes action to reach that state, e.g., starts pods, replicates them, manages nodes.

    => Kubelet on Worker Nodes
    Receives pod specs from the API server and ensures containers are running on the node.

    => Kube-proxy on Worker Nodes
    Maintains network rules so pods and services can communicate internally and externally.

    => Container Runtime
    Actually launches and manages containers inside pods.

    => Networking
    Pods communicate with each other and external users through Services and Ingress.

    => Monitoring and Logging
    Additional tools gather metrics, logs, and traces.