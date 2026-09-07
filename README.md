# GCP GKE Infrastructure & Automated GitOps CI/CD Pipeline

An enterprise-grade, fully automated GitOps deployment pipeline on **Google Kubernetes Engine (GKE)**. The environment integrates **Terraform (IaC)**, **Workload Identity (Passwordless GCP Security)**, **Jenkins (Dynamic CI Agents)**, **GCP Artifact Registry & Cloud Build (Container Lifecycle)**, and **ArgoCD (GitOps Synchronization)**.

---

## 🏗️ End-to-End Architecture Flow

```text
[ Developer Git Push ] ──► [ GitHub Webhook ] ──► [ Dynamic Jenkins Agent (Workload Identity) ]
                                                                │
                                                                ├─► 1. gcloud builds submit (GCP Cloud Build)
                                                                │        │
                                                                │        ▼
                                                                │   [ Artifact Registry: europe-north1 ]
                                                                │
                                                                ├─► 2. Manifest Update & Git Write-Back
                                                                │        (git commit [skip ci] -> main)
                                                                │
                                                                └─► 3. ArgoCD REST API Sync
                                                                         │
                                                                         ▼
[ Public Ingress / Users ] ◄── [ GKE Private Cluster ] ◄── [ ArgoCD App-of-Apps Controller ]
```

---

## 🔑 Security Architecture: Workload Identity & GCP Integration

To eliminate hardcoded GCP credentials (`service-account-key.json`), the cluster implements **GCP Workload Identity**:

* **GCP Service Account**: `jenkins-gsa@andrei-innowise-tests-120826.iam.gserviceaccount.com`
* **Kubernetes Service Account**: `jenkins-sa` (Namespace: `jenkins`)
* **Binding**: The K8s service account is mapped via `roles/iam.workloadIdentityUser` to the GCP service account.
* **Service Access**: Dynamic Jenkins agent pods run under `jenkins-sa`, allowing native token exchange to authenticate with **Artifact Registry**, **Cloud Build**, and **Cloud Storage** without storing static credentials.

---

## 📦 Deployed Applications

| Application                     | Type / Framework      | Public Endpoint / Scope                | Namespace          | GitOps Source Path                          |
| ------------------------------- | --------------------- | -------------------------------------- | ------------------ | ------------------------------------------- |
| **Root Application**      | ArgoCD App-of-Apps    | Internal Cluster Controller            | `argocd`         | `k8s-manifests/apps/root-app.yaml`        |
| **NASA APOD API**         | Node.js (Dockerized)  | `https://nasa.andrei-test.lendo.dev` | `default`        | `app/apod-api/` & `k8s-manifests/apod/` |
| **WireGuard VPN**         | Network & Admin UI    | `https://vpn.andrei-test.lendo.dev`  | `default`        | `k8s-manifests/wireguard/`                |
| **Guestbook**             | Sample Workload       | Internal                               | `guestbook-demo` | `argoproj/argocd-example-apps`            |
| **Kube-Prometheus-Stack** | Monitoring & Alerting | Internal Cluster Scope                 | `monitoring`     | Helm Chart (`88.6.2`)                     |

---

## 🚀 CI/CD Automated Workflow (Jenkins + Git Write-Back)

When changes are pushed to `main`, a GitHub Webhook triggers the dynamic `Jenkinsfile` pipeline:

1. **Source Checkout**: Dynamic pod (`google/cloud-sdk:slim`) provisions in `jenkins` namespace.
2. **Container Build & Push**: Jenkins submits a build to **GCP Cloud Build**, generating an immutable image tag (`v1.0.${BUILD_NUMBER}-${GIT_COMMIT_SHORT}`) pushed directly to **GCP Artifact Registry** (`europe-north1`).
3. **Automated Git Write-Back**: Jenkins updates the image tag inside `k8s-manifests/apod/apod-deployment.yaml` and commits the change back to `main` using `[skip ci]` (preventing recursive webhook loops).
4. **ArgoCD Automated Sync**: Jenkins queries ArgoCD's REST API and triggers a sync across all managed applications, automatically pulling the newly tagged container image into GKE.

---

## 📂 Repository Structure

```text
.
├── app/
│   └── apod-api/
│       ├── Dockerfile              # Multi-arch container build definition
│       └── server.js               # Standalone Node.js HTTP application
├── k8s-manifests/
│   ├── apps/
│   │   └── root-app.yaml           # Master ArgoCD App-of-Apps parent manifest
│   ├── apod/
│   │   ├── apod-deployment.yaml    # References Artifact Registry container image
│   │   ├── apod-ingress.yaml
│   │   └── apod-service.yaml
│   └── wireguard/
│       └── wireguard.yaml
├── Jenkinsfile                     # Multi-stage CI pipeline with Git Write-Back
└── README.md
```

---

## 🛠️ Verification & Diagnostic Commands

### Check Workload Identity & Pod Image Version

```bash
# Verify deployed container image tag in GKE
kubectl get deployment apod-api -n default -o jsonpath='{.spec.template.spec.containers[0].image}'

# Inspect Artifact Registry stored tags
gcloud artifacts docker tags list europe-north1-docker.pkg.dev/andrei-innowise-tests-120826/gke-repo/apod-api

# Check ArgoCD cluster sync state
kubectl get applications -n argocd
```
