
# GKE Private Cluster Infrastructure (Terraform)

This repository contains Production-Ready Terraform code for provisioning an isolated, highly secure, single-zone Private Google Kubernetes Engine (GKE) cluster in Google Cloud Platform (GCP).

---

## 🏛 Architecture Overview

The infrastructure strictly follows the **Zero Direct Public Access** security model.

```text
               INBOUND TRAFFIC                                  OUTBOUND TRAFFIC (Egress)
        (Access to K8s Control Plane)                        (Pods Outgoing Connections)

[ Innowise IP / VPN ]                                         [ GKE Pods / Nodes ]
         │                                                             │
         ▼ (HTTPS:443)                                                 ▼
[ Control Plane Firewall ]                                    [ Private Subnet: 10.10.0.0/24 ]
         │                                                             │
         ▼ (Whitelisted CIDRs)                                         ▼
[ GKE Master (172.16.0.0/28) ]                                [ Cloud Router + Cloud NAT ]
                                                                       │
                                                                       ▼
                                                            [ Static External IP ]
                                                                       │
                                                                       ▼
                                                               [ External Internet ]

```

---

## 📋 Features & Key Specs

* **VPC & Subnetwork:** Custom VPC with secondary IP ranges dedicated for Pods (`/21`) and Services (`/22`).
* **Pods Per Node Sizing (`/25`):** Explicitly configured with `default_max_pods_per_node = 55`.
* **Private Control Plane Access:** Public endpoint restricted exclusively to whitelisted CIDR ranges (**Innowise Office IP** and **VPN subnet**) via `master_authorized_networks_config`.
* **Controlled Outbound Traffic (Egress):** Managed via **Cloud Router** and **Cloud NAT** using a single dedicated static external IP address.
* **Least Privilege IAM:** Uses a custom Service Account attached to GKE nodes with minimal required roles (`logging.logWriter`, `monitoring.metricWriter`, `monitoring.viewer`, `artifactregistry.reader`).
* **Node Pool:** Single-zone (`europe-north1-a`) managed node pool using `n2-standard-4` machine types with cluster autoscaling enabled (1–3 nodes).

---

## 🧠 Sizing Mechanics: Subnet & Max Pods Per Node

Understanding how IP ranges allocate for GKE:

1. **Default GKE Behavior:** Allocates a `/24` subnet (256 IPs) per node for up to 110 pods.
2. **Optimized Density (`55 pods/node`):** Setting `default_max_pods_per_node = 55` forces GKE to allocate a smaller `/25` CIDR block (128 IPs) per node.
3. **Capacity Calculation:**

$$
\text{Max Nodes} = \frac{\text{Pods Range IP Pool (/21)}}{\text{Node IP Block (/25)}} = \frac{2048 \text{ IPs}}{128 \text{ IPs/Node}} = 16 \text{ Nodes}
$$

*The secondary Pods range (`10.20.0.0/21`) safely accommodates cluster scaling up to 16 worker nodes.*

---

## 📂 Project Structure

```text
.
├── modules/
│   └── gke/
│       ├── main.tf        # Core GKE, Subnets, NAT, and IAM resources
│       ├── variables.tf   # Module variables
│       └── outputs.tf     # Cluster outputs
├── .gitignore
├── main.tf            # Root configuration & module caller
├── variables.tf       # Global variable declarations
├── terraform.tfvars   # Variable definitions (gitignored / template)
├── outputs.tf         # Root outputs
└── README.md

```

---

## 🚀 Quick Start

### Prerequisites

* [Terraform](https://www.terraform.io/) >= 1.0
* [Google Cloud SDK (gcloud)](https://cloud.google.com/sdk)
* `kubectl` CLI tool
* `gke-gcloud-auth-plugin`

```bash
gcloud components install gke-gcloud-auth-plugin

```

---

### Deployment Steps

1. **Clone the repository:**

```bash
git clone https://github.com/onneyami/gcp-terraform-task-2.git
cd gcp-terraform-task-2

```

2. **Configure Variables (`terraform.tfvars`):**
   Create a `terraform.tfvars` file:

```hcl
project_id  = "your-gcp-project-id"
region      = "europe-north1"
zone        = "europe-north1-a"
vpn_cidr    = "10.0.0.0/16"
innowise_ip = "YOUR_PUBLIC_IP/32"

```

3. **Initialize & Apply:**

```bash
terraform init
terraform validate
terraform plan
terraform apply

```

---

## 🧪 Verification & Testing

### 1. Authenticate & Connect

Get cluster credentials:

```bash
gcloud container clusters get-credentials gke-private-cluster --zone europe-north1-a --project <YOUR_PROJECT_ID>

```

Verify nodes and pod limits:

```bash
kubectl get nodes
kubectl describe node | grep "pods:"

```

### 2. Verify Master Authorized Networks Security

* **Allowed IP (Innowise Office / Home IP):** Running `kubectl get nodes` succeeds.
* **Non-Whitelisted IP (via external VPN):** Connection times out (`dial tcp <ENDPOINT>:443: i/o timeout`), confirming packet drops at the cloud firewall layer.

### 3. Verify Cloud NAT Static Egress IP

Run a temporary container to inspect the outgoing IP address:

```bash
kubectl run test-egress --image=curlimages/curl -i --tty --rm -- curl https://ifconfig.me

```

*The printed IP matches the `gke_egress_static_ip` output generated by Terraform.*

---

## 🧹 Cleanup

To destroy all provisioned infrastructure:

```bash
terraform destroy

```

*(Note: `deletion_protection = false` is configured within the cluster resource to allow clean destruction via Terraform).*
