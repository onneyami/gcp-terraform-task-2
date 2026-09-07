# GCP Infrastructure & GitOps Pipeline (GKE + ArgoCD)

This repository contains the end-to-end Infrastructure-as-Code (Terraform) and GitOps application delivery setup (ArgoCD, External Secrets Operator, cert-manager) running on Google Kubernetes Engine (GKE).

---

## 🏗 Infrastructure & Repository Structure

The repository uses the **App-of-Apps pattern** in ArgoCD to manage multi-workload deployments from a single root manifest (`root-app.yaml`).

```text
gcp-terraform-task-2/
├── terraform/                      # IaC: GKE Cluster, VPC, IAM, Service Accounts
├── k8s-manifests/
│   ├── argocd-ingress.yaml         # Ingress with cert-manager TLS offloading
│   ├── apps/                       # Root App destination (recurse: true)
│   │   ├── root-app.yaml           # Parent ArgoCD Application
│   │   ├── external-secrets-app.yaml # ESO Helm Chart (Sync-Wave: -1)
│   │   ├── secrets-app.yaml        # SecretStore & ExternalSecrets (Sync-Wave: 1)
│   │   ├── apod-api-app.yaml       # APOD Microservice
│   │   ├── guestbook-app.yaml      # Sample Guestbook App
│   │   ├── observability-app.yaml  # Monitoring Stack (Prometheus/Grafana)
│   │   └── wireguard-app.yaml      # VPN Overlay Service
│   ├── apod/                       # Manifests for APOD API
│   └── secrets/                    # SecretStore & ExternalSecret custom resources
```

---

## 🔄 GitOps Execution Order (Sync Waves)

To prevent race conditions during deployment (e.g., trying to create an `ExternalSecret` before the CRD exists), deployment order is controlled via ArgoCD **Sync Waves**:

| Wave                      | Component            | Description                                                                                                      |
| ------------------------- | -------------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Wave`-1**`            | `external-secrets` | Installs the External Secrets Operator & CRDs via Helm.                                                          |
| **Wave`1**`             | `secrets-config`   | Deploys`ClusterSecretStore` and `ExternalSecret` custom resources.                                           |
| **Default (`0`)** | Workloads            | Applications (`apod-api`, `guestbook`, `wireguard`, `observability`) fetch injected secrets and boot up. |

---

## 🔑 Secret Management Integration (ESO + GCP Secret Manager)

Secrets are stored securely in **GCP Secret Manager** and automatically injected into GKE namespaces as standard Kubernetes `Secrets`.

1. **Workload Identity**: ArgoCD and ESO use GCP Workload Identity to authenticate with GCP APIs without requiring static service account keys.
2. **Dynamic Syncing**: `ExternalSecret` resources observe GCP Secret Manager for updates and keep cluster secrets synced in real time.

---

## 🌐 Ingress & Traffic Routing

* **Ingress Controller**: `ingress-nginx`
* **TLS Management**: `cert-manager` with Let's Encrypt production issuer (`letsencrypt-prod`).
* **ArgoCD Server Architecture**:
* Ingress offloads SSL at the edge (`argocd.andrei-test.lendo.dev`).
* `argocd-server` runs with the `--insecure` flag, receiving HTTP traffic on port `80` (targetPort `8080`) internally to eliminate 502 Bad Gateway / SSL handshake mismatches.

---

## 🚀 Quickstart & Operations Guide

### 1. Apply Infrastructure with Terraform

```bash
cd terraform
terraform init
terraform apply

```

### 2. Connect to GKE Cluster

```bash
gcloud container clusters get-credentials <gke-cluster-name> --region <gcp-region> --project <gcp-project-id>

```

### 3. Bootstrap ArgoCD Root Application

To initialize the entire GitOps pipeline and launch all child applications:

```bash
kubectl apply -f k8s-manifests/apps/root-app.yaml

```

### 4. Verify Application & Sync Status

```bash
# Check all deployed ArgoCD Applications
kubectl get applications -n argocd

# Check live pod status
kubectl get pods -A

```

---

## 🛠 Branching & Automated CI Workflow

* **`main`**: Production-ready branch. Holds the validated infrastructure and manifest baselines.
* **`dev`**: Active deployment target for automated CI/CD write-backs (e.g., image tag updates triggered by build pipelines).

When updating application manifests, always pull changes with standard merges to preserve automated write-backs from Jenkins/CI:

```bash
git checkout dev
git pull origin dev --no-rebase
git merge main
git push origin dev

```

---
