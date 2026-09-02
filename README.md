

# Secure GitOps Pipeline on GKE: Jenkins, ArgoCD & Workload Identity

![GCP](https://img.shields.io/badge/Google_Cloud-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Jenkins](https://img.shields.io/badge/Jenkins-D24939?style=for-the-badge&logo=jenkins&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)

A production-grade, keyless CI/CD GitOps workflow running on Google Kubernetes Engine (GKE). This project demonstrates automated infrastructure provisioning via Terraform, dynamic in-cluster Jenkins build agents using **GCP Workload Identity**, and continuous delivery with **ArgoCD**.

---

## 🏗️ Architecture Overview

```text
                                  +-------------------------------------------------+
                                  |                 GKE Cluster                     |
                                  |             (europe-north1-a)                   |
                                  |                                                 |
[Developer] --- 1. Push Code ---> | [Jenkins Master Pod]                            |
                                  |        │                                        |
                                  |   2. Spawns Ephemeral Agent                     |
                                  |        ▼                                        |
                                  | [Jenkins Agent Pod] ──3. Workload Identity────► [GCP APIs / GCS]
                                  |  (jenkins-sa KSA)      (jenkins-gsa IAM)        |
                                  |        │                                        |
                                  |   4. Update Git Manifests                       |
                                  |        ▼                                        |
                                  | [ArgoCD Controller] ──5. Auto-Sync Manifests──► [App Deployment]
                                  +-------------------------------------------------+
```

### Key Highlights

* **Zero Static Keys:** Keyless GCP authentication using GKE Workload Identity (KSA `jenkins-sa` bound to GCP IAM `jenkins-gsa`).
* **Pipeline as Code:** Declarative `Jenkinsfile` executed via dynamic Kubernetes pod templates.
* **Cost Optimized:** Node pool autoscaling (`nodepool-n2-standard-4`) supporting 0-node scale-down for cost management.
* **GitOps Deployment:** ArgoCD declarative application management with automated drift detection and reconciliation.

---

## 📁 Repository Structure

```text
gcp-terraform-task-2/
├── Jenkinsfile                  # Production CI/CD declarative pipeline
├── main.tf                      # Terraform infrastructure entrypoint
├── gke.tf                       # GKE cluster & node pool definition
├── iam.tf                       # GCP IAM bindings & Workload Identity setup
├── k8s-manifests/               # Kubernetes manifests managed by ArgoCD
│   ├── apod-deployment.yaml     # Application deployment specs
│   └── service.yaml             # K8s Service definitions
└── README.md                    # Project documentation
```

---

## 🚀 Live Environment Specs

| Component                 | Target / URL                              |
| ------------------------- | ----------------------------------------- |
| **GCP Project ID**  | `andrei-innowise-tests-120826`          |
| **GKE Region/Zone** | `europe-north1` / `europe-north1-a`   |
| **Cluster Name**    | `gke-private-cluster`                   |
| **Node Pool**       | `nodepool-n2-standard-4`                |
| **Jenkins URL**     | `https://jenkins.andrei-test.lendo.dev` |
| **NASA APOD App**   | `https://nasa.andrei-test.lendo.dev`    |
| **Wireguard VPN**   | `https://vpn.andrei-test.lendo.dev`     |

---

## 🔒 Security: Workload Identity Setup

The pipeline operates completely keyless. Authentication between Kubernetes agents and Google Cloud APIs is established using Workload Identity Federation:

1. **Kubernetes Service Account (KSA):** `jenkins-sa` in `jenkins` namespace.
2. **GCP IAM Service Account (GSA):** `jenkins-gsa@andrei-innowise-tests-120826.iam.gserviceaccount.com`.
3. **IAM Binding:**

```bash
gcloud iam service-accounts add-iam-policy-binding \
  jenkins-gsa@andrei-innowise-tests-120826.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:andrei-innowise-tests-120826.svc.id.goog[jenkins/jenkins-sa]"
```

---

## 🛠️ Operational Playbook

### Pausing Cluster (Nightly Cost Control)

To pause the worker nodes without destroying Terraform state or control plane configurations:

```bash
gcloud container node-pools update nodepool-n2-standard-4 \
  --cluster=gke-private-cluster \
  --zone=europe-north1-a \
  --min-nodes=0 \
  --max-nodes=0
```

*Or force immediate scale down:*

```bash
gcloud container clusters resize gke-private-cluster \
  --node-pool=nodepool-n2-standard-4 \
  --zone=europe-north1-a \
  --num-nodes=0
```

### Waking Up Infrastructure

To bring the cluster back online:

```bash
gcloud container node-pools update nodepool-n2-standard-4 \
  --cluster=gke-private-cluster \
  --zone=europe-north1-a \
  --min-nodes=1 \
  --max-nodes=3
```

### Verification Commands

```bash
# Check worker node status
kubectl get nodes

# Check Jenkins & ArgoCD workloads
kubectl get pods -n jenkins
kubectl get pods -n argocd
```

```markdown
# Secure GitOps Pipeline on GKE: Jenkins, ArgoCD & Workload Identity

![GCP](https://img.shields.io/badge/Google_Cloud-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Jenkins](https://img.shields.io/badge/Jenkins-D24939?style=for-the-badge&logo=jenkins&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)

A production-grade, keyless CI/CD GitOps workflow running on Google Kubernetes Engine (GKE). This project demonstrates automated infrastructure provisioning via Terraform, dynamic in-cluster Jenkins build agents using **GCP Workload Identity**, and continuous delivery with **ArgoCD**.

---

## 🏗️ Architecture Overview

```text
                                  +-------------------------------------------------+
                                  |                 GKE Cluster                     |
                                  |             (europe-north1-a)                   |
                                  |                                                 |
[Developer] --- 1. Push Code ---> | [Jenkins Master Pod]                            |
                                  |        │                                        |
                                  |   2. Spawns Ephemeral Agent                     |
                                  |        ▼                                        |
                                  | [Jenkins Agent Pod] ──3. Workload Identity────► [GCP APIs / GCS]
                                  |  (jenkins-sa KSA)      (jenkins-gsa IAM)        |
                                  |        │                                        |
                                  |   4. Update Git Manifests                       |
                                  |        ▼                                        |
                                  | [ArgoCD Controller] ──5. Auto-Sync Manifests──► [App Deployment]
                                  +-------------------------------------------------+
```
