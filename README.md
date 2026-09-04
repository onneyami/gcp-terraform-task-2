
# GCP GKE Infrastructure & GitOps Pipeline

This repository manages Google Kubernetes Engine (GKE) applications and infrastructure using **Terraform**, **ArgoCD**, and **Jenkins**.

---

## 🏗️ Architecture Overview

* **Cloud Provider**: Google Cloud Platform (GCP) — Google Kubernetes Engine (GKE)
* **Ingress & TLS**: NGINX Ingress Controller with `cert-manager` (Let's Encrypt CA)
* **GitOps Engine**: ArgoCD (automated `selfHeal` and `prune`)
* **CI/CD Pipeline**: Jenkins (REST API trigger for ArgoCD application syncs)

---

## 📦 Deployed Applications

| Application                  | Public URL / Endpoint                                 | Namespace   | GitOps Manifest Path         |
| :--------------------------- | :---------------------------------------------------- | :---------- | :--------------------------- |
| **WireGuard VPN & UI** | `https://vpn.andrei-test.lendo.dev` / `UDP 51820` | `default` | `k8s-manifests/wireguard/` |
| **NASA APOD API**      | `https://nasa.andrei-test.lendo.dev`                | `default` | `k8s-manifests/apod/`      |

---

## 🔒 WireGuard VPN Configuration

The WireGuard server runs in GKE and provides a secure egress tunnel for client traffic.

### Features & Security Settings

* **IP Forwarding**: Privileged `initContainer` enables `net.ipv4.ip_forward=1` inside the pod network namespace (bypassing GKE `SysctlForbidden` restrictions).
* **NAT Masquerading**: `iptables` rules automatically route client traffic (`wg0` $\rightarrow$ `eth0`).
* **Selective Routing**: Mac WireGuard client configurations exclude the GKE Control Plane IP to prevent `kubectl` connectivity timeouts.

---

## 🚀 GitOps & CI/CD Automation

### ArgoCD Synchronization

Applications are defined as ArgoCD custom resources in `k8s-manifests/`:

* `wireguard-app.yaml` $\rightarrow$ tracks `k8s-manifests/wireguard/`
* `apod-app.yaml` $\rightarrow$ tracks `k8s-manifests/apod/`

### Jenkins Sync Pipeline

When changes are pushed to `main`, Jenkins invokes the ArgoCD REST API to force an immediate application refresh and sync.

[ Git Push to main ]
│
▼
[ Jenkins Pipeline ] ──── HTTP POST (Bearer Token) ────► [ ArgoCD REST API ]
│
▼
[ GKE Cluster Sync ]


#### Pipeline Configuration Highlights

* **Authentication**: Uses `argocd-jenkins-token` service account in Jenkins credentials manager.
* **RBAC Policy**: Configured in `argocd-rbac-cm` ConfigMap:
  ```yaml
  p, role:jenkins-sync, applications, get, default/apod-api, allow
  p, role:jenkins-sync, applications, sync, default/apod-api, allow
  ```

---

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
├── Jenkinsfile_for_nasa_app_sync_trigger_from_argocd
└── README.md
```

---

## 🛠️ Operational Commands

### Check Application Health

```bash
# Check ArgoCD Applications
kubectl get applications -n argocd

# Check Pod Status
kubectl get pods -n default
```

### Verify WireGuard Status Inside Container

```bash
POD_NAME=$(kubectl get pods -n default -l app=wireguard-ui -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n default $POD_NAME -c wireguard-server -- wg show
```
