
# GCP GKE Infrastructure & GitOps Pipeline

A production-grade Kubernetes deployment pipeline on **Google Kubernetes Engine (GKE)** managed via **Terraform (IaC)**, **Jenkins (CI Automation)**, **GCP Artifact Registry (Container Registry)**, and **ArgoCD (GitOps Engine)**.

---

## 🏗️ Architecture Overview

```text
[ Developer Push ] ──► [ GitHub Webhook ] ──► [ Jenkins Pipeline ]
                                                   │
                                                   ├─► 1. GET /api/v1/applications (App Discovery)
                                                   └─► 2. POST /api/v1/applications/{app}/sync
                                                                 │
                                                                 ▼
[ GKE Workloads ] ◄── [ GCP Artifact Registry ] ◄── [ ArgoCD Root-App Controller ]
```

* **Infrastructure**: Google Kubernetes Engine (GKE) provisioned with Terraform.
* **Ingress & TLS**: NGINX Ingress Controller with Let's Encrypt certificates.
* **Container Registry**: GCP Artifact Registry (`europe-north1-docker.pkg.dev/andrei-innowise-tests-120826/gke-repo`).
* **GitOps Engine**: ArgoCD applying the **App-of-Apps** pattern.
* **CI Orchestration**: Unified, dynamic `Jenkinsfile` triggered via GitHub Webhooks.

---

## 📦 Deployed Applications

| Application                     | Type                   | Public Endpoint                        | Namespace          | GitOps Source Path                   |
| ------------------------------- | ---------------------- | -------------------------------------- | ------------------ | ------------------------------------ |
| **Root Application**      | App-of-Apps Controller | Internal                               | `argocd`         | `k8s-manifests/apps/root-app.yaml` |
| **NASA APOD API**         | Node.js (Dockerized)   | `https://nasa.andrei-test.lendo.dev` | `default`        | `k8s-manifests/apod/`              |
| **WireGuard VPN & UI**    | Network / Security     | `https://vpn.andrei-test.lendo.dev`  | `default`        | `k8s-manifests/wireguard/`         |
| **Guestbook Demo**        | Sample App             | Internal                               | `guestbook-demo` | `argoproj/argocd-example-apps`     |
| **Kube-Prometheus-Stack** | Monitoring             | Internal                               | `monitoring`     | Helm Chart (`88.6.2`)              |

---

## 📂 Repository Structure

```text
.
├── app/
│   └── apod-api/
│       ├── Dockerfile              # Multi-arch container build specification
│       └── server.js               # Standalone Node.js NASA APOD service
├── k8s-manifests/
│   ├── apps/
│   │   └── root-app.yaml           # Master ArgoCD App-of-Apps parent manifest
│   ├── apod/
│   │   ├── apod-deployment.yaml    # References Artifact Registry container image
│   │   ├── apod-ingress.yaml
│   │   └── apod-service.yaml
│   ├── wireguard/
│   │   └── wireguard.yaml
│   ├── apod-app.yaml               # Child Application CRD for APOD API
│   └── wireguard-app.yaml          # Child Application CRD for WireGuard UI
├── .gitignore                      # Hardened ignore rules for Terraform & secrets
├── Jenkinsfile                     # Unified multi-app sync pipeline
└── README.md

```

---

## 🚀 CI/CD & GitOps Automation

### 1. App-of-Apps Deployment Pattern

ArgoCD uses `k8s-manifests/apps/root-app.yaml` as a supervisor app. When a new application manifest (`*-app.yaml`) is added to `k8s-manifests/` and pushed to Git, `root-app` automatically registers and manages it in GKE without manual `kubectl` intervention.

### 2. Event-Driven Multi-App Sync Pipeline

When changes are pushed to `main`, GitHub fires a webhook to Jenkins. The `Jenkinsfile` pipeline:

1. Queries ArgoCD's REST API (`GET /api/v1/applications`).
2. Extracts all registered application names using pure POSIX text processing.
3. Issues a sync request (`POST /api/v1/applications/{app}/sync`) for **every** discovered application, syncing them according to their native `targetRevision` (Git branches or Helm chart tags).

---

## 🛠️ Operational & Verification Commands

### Test End-to-End Pipeline

Push an empty commit to verify GitHub Webhook auto-triggering and ArgoCD synchronization:

```bash
git commit --allow-empty -m "test: verify github webhook and multi-app sync pipeline"
git push origin main

```

### Inspect Container Registry Image

```bash
gcloud artifacts docker images list europe-north1-docker.pkg.dev/andrei-innowise-tests-120826/gke-repo/apod-api

```

### Verify Application Health in GKE

```bash
# Check all ArgoCD Applications
kubectl get applications -n argocd

# Check APOD API pods and image version
kubectl get pods -l app=apod-api -n default
kubectl get deployment apod-api -n default -o jsonpath='{.spec.template.spec.containers[0].image}'
```
