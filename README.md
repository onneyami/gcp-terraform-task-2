
# GKE GitOps Infrastructure & Continuous Deployment Platform

A production-grade, GitOps-driven Kubernetes platform deployed on Google Kubernetes Engine (GKE) private cluster. This repository manages core cluster infrastructure, observability stacks, workload deployments, and automated CI/CD synchronization using ArgoCD and Jenkins.

---

## 🏛 Architecture Overview

```
                    +-----------------------------------------------+
                    |                GitHub Repository              |
                    |      (gcp-terraform-task-2 / main branch)    |
                    +-----------------------+-----------------------+
                                            |
                             +--------------+--------------+
                             |                             |
                             v                             v
                   +-------------------+         +-------------------+
                   |  Jenkins Pipeline |         |  ArgoCD Operator  |
                   +---------+---------+         +---------+---------+
                             |                             |
                             | Trigger Sync (REST API)     | Sync Manifests
                             v                             v
               +---------------------------------------------------------+
               |                 GKE Private Cluster                     |
               |                                                         |
               |  [ Namespace: argocd ]                                  |
               |   - ArgoCD Server / Controller                          |
               |                                                         |
               |  [ Namespace: jenkins ]                                 |
               |   - Jenkins Master / Agent Pods                         |
               |                                                         |
               |  [ Namespace: monitoring ]                              |
               |   - Prometheus / Grafana (Persistent PVCs)              |
               |   - Loki & Promtail Stack                               |
               |                                                         |
               |  [ Namespace: default ]                                 |
               |   - WireGuard UI (`wireguard-ui`)                       |
               |   - NASA APOD API (`nasa-apod`)                        |
               |   - NGINX Ingress Controller + cert-manager             |
               +---------------------------------------------------------+
```


---



## 🛠 Tech Stack & Infrastructure

* **Cloud Provider:** Google Cloud Platform (GCP)
* **Kubernetes:** GKE Private Cluster (`nodepool-n2-standard-4` with cost-optimized auto-scaling to 0)
* **Continuous Delivery (GitOps):** ArgoCD (`v2.10.4`)
* **Continuous Integration (CI):** Jenkins (Kubernetes-native agent orchestration)
* **Observability:** Prometheus, Grafana ("Dashboards as Code"), Loki, Promtail
* **Ingress & Security:** NGINX Ingress Controller, `cert-manager` (Let's Encrypt TLS), Jenkins RBAC Service Accounts

---

## 📁 Repository Structure

```directory
.
├── k8s-manifests/
│   ├── argocd/                 # ArgoCD Application CRDs & Root App configurations
│   ├── dashboards/             # ConfigMap "Dashboards as Code" for Grafana
│   ├── monitoring/             # kube-prometheus-stack & Loki Helm release values
│   ├── nasa-apod/              # Workload manifests for NASA APOD API service
│   └── wireguard/              # Workload manifests for WireGuard UI (`wireguard-ui`)
├── Jenkinsfile_for_sync_argocd_trigger  # Declarative Jenkins pipeline triggering ArgoCD sync
└── README.md
```

## 🚀 Workloads Managed via ArgoCD

| Application                 | Namespace      | Path / Helm Chart           | Description                                          |
| --------------------------- | -------------- | --------------------------- | ---------------------------------------------------- |
| **`wireguard-ui`**  | `default`    | `k8s-manifests/wireguard` | WireGuard VPN administration web interface           |
| **`nasa-apod`**     | `default`    | `k8s-manifests/nasa-apod` | Microservice demonstrating external API integration  |
| **`observability`** | `monitoring` | `kube-prometheus-stack`   | Prometheus metrics collector & Grafana visualization |
| **`loki-stack`**    | `monitoring` | `loki-stack`              | Centralized log aggregation & LogQL querying         |

---

## 🔄 CI/CD Pipeline Integration (Jenkins -> ArgoCD)

The repository includes an automated pipeline (`Jenkinsfile_for_sync_argocd_trigger`) that decouples CI build steps from deployment execution by triggering ArgoCD sync operations securely over the internal cluster network.

### Pipeline Workflow

1. **SCM Checkout:** Pulls the latest Kubernetes manifest revision from `main`.
2. **ArgoCD Hard Refresh:** Executes an authenticated REST API call (`/api/v1/applications/{app}?refresh=hard`) to force ArgoCD to fetch new Git commits immediately.
3. **Application Sync:** Dispatches a POST request (`/api/v1/applications/{app}/sync`) targeting the `main` revision to prune deleted resources and apply new manifests seamlessly.

### Security Configuration

* **Authentication:** Dedicated ArgoCD service account token (`jenkins`) scoped via `argocd-rbac-cm` with minimal privileges (`get` and `sync` on target applications).
* **Network Binding:** Communicates directly via cluster-internal DNS (`argocd-server.argocd.svc.cluster.local:80`).
* **Secret Injection:** Injected safely using Jenkins Credentials binding (`argocd-jenkins-token`).

---

## ⚡ Manual Commands & Quickstart

### Manually Refresh & Sync an Application via Curl

```bash
# Obtain your ArgoCD JWT token
ARGOCD_TOKEN=$(kubectl get secret -n argocd argocd-jenkins-token -o jsonpath='{.data.token}' | base64 --decode)

# Hard refresh application state
curl -s -X GET \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  "[http://argocd-server.argocd.svc.cluster.local:80/api/v1/applications/wireguard-ui?refresh=hard](http://argocd-server.argocd.svc.cluster.local:80/api/v1/applications/wireguard-ui?refresh=hard)"

# Trigger Sync
curl -s -X POST \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -H "Content-Type: application/json" \
  "[http://argocd-server.argocd.svc.cluster.local:80/api/v1/applications/wireguard-ui/sync](http://argocd-server.argocd.svc.cluster.local:80/api/v1/applications/wireguard-ui/sync)" \
  -d '{"revision": "main", "prune": true}'
```

### Inspect Managed Applications

```bash
kubectl get applications -n argocd
kubectl get pods -n default
```
