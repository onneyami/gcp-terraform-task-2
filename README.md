
# GCP GKE Infrastructure & GitOps Pipeline

This repository manages Google Kubernetes Engine (GKE) applications and infrastructure using **Terraform**, **ArgoCD**, and **Jenkins**.

---

## 🏗️ Architecture Overview

* **Cloud Provider**: Google Cloud Platform (GCP) — Google Kubernetes Engine (GKE)
* **Ingress & TLS**: NGINX Ingress Controller with `cert-manager` (Let's Encrypt CA)
* **GitOps Engine**: ArgoCD (automated `selfHeal` and `prune`)
* **CI/CD Orchestration**: Jenkins (Automated multi-app REST API triggers)

---

## 📦 Deployed Applications

| Application                     | Type               | Public URL / Endpoint                                 | Namespace          | GitOps Source Path               |
| :------------------------------ | :----------------- | :---------------------------------------------------- | :----------------- | :------------------------------- |
| **NASA APOD API**         | Node.js App        | `https://nasa.andrei-test.lendo.dev`                | `default`        | `k8s-manifests/apod/`          |
| **WireGuard VPN & UI**    | Security / Network | `https://vpn.andrei-test.lendo.dev` / `UDP 51820` | `default`        | `k8s-manifests/wireguard/`     |
| **Guestbook Demo**        | Sample App         | Internal                                              | `guestbook-demo` | `argoproj/argocd-example-apps` |
| **Kube-Prometheus-Stack** | Monitoring         | Internal                                              | `monitoring`     | Helm Chart (`88.6.2`)          |

---

## 🚀 Automated Multi-App GitOps Pipeline

When code or manifests are pushed to `main`, GitHub triggers a Jenkins pipeline that dynamically discovers and synchronizes all ArgoCD applications across the cluster.

[ Git Push to main ]
│
▼
[ GitHub Webhook ] ────► [ Jenkins Pipeline ]
│
├─► 1. GET /api/v1/applications (Discovers all registered apps)
│
└─► 2. POST /api/v1/applications/{name}/sync (Triggers sync for each app)
│
▼
[ ArgoCD Engine ] ────► [ GKE Cluster Sync ]

---


### Key Pipeline Capabilities

* **Dynamic App Discovery**: Automatically detects new ArgoCD applications without needing updates to the `Jenkinsfile`.
* **Multi-Revision Compatibility**: Omits hardcoded branch overrides, allowing Git repositories (`main`, `HEAD`) and Helm charts to sync cleanly according to their configured `targetRevision`.
* **RBAC Scoped Access**: Authenticates via `argocd-jenkins-token` service account using permissions configured in `argocd-rbac-cm`.

---

## 🔒 Security & RBAC Configuration

ArgoCD RBAC is configured via `argocd-rbac-cm` to allow the Jenkins service account full sync rights across all cluster applications:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.csv: |
    p, role:jenkins-sync, applications, *, */*, allow
    g, jenkins, role:jenkins-sync
```

## 📁 Repository Structure

```text
.
├── k8s-manifests/
│   ├── apod/
│   │   ├── apod-deployment.yaml
│   │   ├── apod-ingress.yaml
│   │   └── apod-service.yaml
│   ├── wireguard/
│   │   └── wireguard.yaml
│   ├── apod-app.yaml
│   └── wireguard-app.yaml
├── Jenkinsfile_for_automatic_trigger_argocd
└── README.md

```

---

## 🛠️ Operational Commands

### Check Application Health & Sync Status

```bash
# Get status of all ArgoCD applications
kubectl get applications -n argocd

# Verify deployed pod resources in default namespace
kubectl get pods -n default
```

### Test Pipeline Trigger Manually

```bash
# Push an empty commit to verify GitHub Webhook and Jenkins multi-app sync
git commit --allow-empty -m "test: verify automated pipeline trigger"
git push origin main
```
