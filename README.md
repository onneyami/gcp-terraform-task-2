---

# GKE GitOps Infrastructure & Observability Stack

This repository contains the declarative infrastructure and application manifests for managing a secure, private Google Kubernetes Engine (GKE) cluster using a full GitOps workflow powered by **ArgoCD**.

---

## 🏗️ Architecture Overview

The platform consists of a private GKE cluster running microservices, operational tooling, and a complete observability stack—all managed declaratively through Git repository syncs.

* **Cluster Infrastructure:** GKE Private Cluster (`gke-private-cluster`) on `nodepool-n2-standard-4` worker nodes.
* **GitOps Engine:** ArgoCD managing Helm releases and raw K8s manifests directly from Git.
* **Networking & Ingress:** NGINX Ingress Controller with automated TLS certificates issued via `cert-manager` and Let's Encrypt.
* **Observability:** `kube-prometheus-stack` (Prometheus, Grafana, Alertmanager, Node Exporter, kube-state-metrics).
* **Workloads & Services:**
  * **NASA APOD Application** (`nasa-apod`)
  * **WireGuard UI** (`wireguard-ui`)

---

## 🚀 Managed Applications & Endpoints

| Service                  | Endpoint Domain                                | Namespace      | Sync Source                                 |
| :----------------------- | :--------------------------------------------- | :------------- | :------------------------------------------ |
| **Grafana UI**     | `https://grafana.andrei-test.lendo.dev`      | `monitoring` | Helm (`kube-prometheus-stack` v88.6.2)    |
| **Prometheus API** | `http://prometheus-operated.monitoring:9090` | `monitoring` | Operator CRD (`Prometheus`)               |
| **WireGuard UI**   | `https://vpn.andrei-test.lendo.dev`          | `default`    | Git Manifests (`k8s-manifests/wireguard`) |
| **NASA APOD API**  | `https://apod.andrei-test.lendo.dev`         | `default`    | Git Manifests (`k8s-manifests/nasa-apod`) |

---

## 📁 Repository Structure

```text
.
├── k8s-manifests/
│   ├── observability-app.yaml     # ArgoCD Application for kube-prometheus-stack
│   ├── wireguard-app.yaml         # ArgoCD Application for WireGuard UI
│   ├── nasa-apod-app.yaml         # ArgoCD Application for NASA APOD
│   └── wireguard/
│       └── wireguard.yaml         # Deployment, Service, & Ingress for WireGuard UI
├── terraform/                      # Infrastructure provisioner for GKE & GCP resources
└── README.md
```

## 🛠️ Stack Configuration & Settings

### 1. Observability Stack (`kube-prometheus-stack`)

* **Storage:** Configured with `standard-rwo` StorageClass on GCP (20Gi Persistent Volume).
* **Prometheus Operator:** Configured with open label selectors (`serviceMonitorSelectorNilUsesHelmValues: false`) to auto-discover all cluster monitors.
* **Grafana Datasource:** Linked directly to internal DNS endpoint `http://prometheus-operated.monitoring.svc.cluster.local:9090` using HTTP `POST`.

### 2. WireGuard UI

* **Management UI:** `ngoduykhanh/wireguard-ui:latest` (v0.6.2).
* **Service:** Exposed internally on port `51821/TCP` (mapped to container `5000/TCP`).
* **Ingress:** NGINX managed with TLS termination on `vpn.andrei-test.lendo.dev`.

---

## 🔐 Credentials Management

| Service                | Default Username | Default Password      | Password Override Command                                                                            |
| ---------------------- | ---------------- | --------------------- | ---------------------------------------------------------------------------------------------------- |
| **Grafana**      | `admin`        | `AdminPassword123!` | `kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" |
| **WireGuard UI** | `admin`        | `AdminPassword123!` | Configured via`WGUI_PASSWORD` in `wireguard.yaml`                                                |

---

## 🔄 Cluster Pause & Resume Workflow (Cost Optimization)

To save GCP compute costs when the cluster is idle, scale the worker node pool down to `0` and back up on demand.

### Pause Cluster (Scale Nodes to 0)

```bash
gcloud container clusters resize gke-private-cluster \
  --node-pool=nodepool-n2-standard-4 \
  --zone=europe-north1-a \
  --num-nodes=0

```

### Resume Cluster (Scale Nodes Back Up)

```bash
gcloud container clusters resize gke-private-cluster \
  --node-pool=nodepool-n2-standard-4 \
  --zone=europe-north1-a \
  --num-nodes=1

```

Once nodes reach `Ready` status (`kubectl get nodes`), Kubernetes and ArgoCD will automatically restore all persistent volume claims and reschedule all pods.

### Force ArgoCD Synchronization (If Required)

```bash
kubectl annotate application kube-prometheus-stack -n argocd argocd.argoproj.io/refresh=normal --overwrite
kubectl annotate application wireguard-ui -n argocd argocd.argoproj.io/refresh=normal --overwrite

```

---

## 📊 Verification & Diagnostics

```bash
# Check all running pods across namespaces
kubectl get pods -A

# Verify ArgoCD Application status
kubectl get applications -n argocd

# Check ingress status and IP assignments
kubectl get ingress -A

```

```

```
