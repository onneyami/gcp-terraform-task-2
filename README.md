Here is the updated, professional **`README.md`** translated into English for your repository.

Save or update the **`README.md`** file in the root directory of your project:

```markdown
# 🌌 NASA APOD Application on Google Kubernetes Engine (GKE)

Comprehensive guide to deploying the **NASA Astronomy Picture of the Day (APOD)** application in Google Cloud Platform (GCP) using **Terraform**, **Kubernetes (GKE)**, **Nginx Ingress**, and **Cert-Manager (Let's Encrypt)** with automated SSL/TLS termination.

---

## 🏛️ System Architecture


```

[ User / Browser ]
│ (HTTPS: nasa.andrei-test.lendo.dev)
▼
[ DNS A-Record -> 35.228.37.177 ]
▼
[ GCP Cloud Load Balancer ]
▼
[ Ingress Nginx Controller ] ──── (TLS Secret: nasa-tls-cert)
▼
[ K8s Service: apod-api-service:80 ]
▼
[ K8s Deployment: apod-api (2 Replicas, Port 8080) ]
▼
[ NASA APOD REST API (api.nasa.gov) ]

```

---

## 📁 Repository Structure

```text
.
├── gke.tf                   # Terraform: VPC, private subnets, and GKE cluster configuration
├── helm_providers.tf        # Terraform: Helm provider setup for Kubernetes integration
├── helm_ingress_nginx.tf    # Terraform: Automated Ingress Nginx Controller deployment
├── helm_cert_manager.tf     # Terraform: Automated cert-manager deployment
├── providers.tf             # Terraform: GCP provider definitions
├── k8s-manifests/
│   ├── cluster-issuer.yaml  # Cert-Manager ClusterIssuer (Let's Encrypt Production)
│   ├── apod-deployment.yaml # Application Deployment (2 replicas, UI + REST API proxy)
│   ├── apod-service.yaml    # ClusterIP Service for internal routing
│   └── apod-ingress.yaml    # Ingress routing rules & TLS certificate request
└── README.md

```

---

## 🛠️ Technology Stack

* **Cloud Provider:** Google Cloud Platform (GCP)
* **Infrastructure as Code (IaC):** Terraform
* **Orchestration:** Google Kubernetes Engine (GKE Private Cluster)
* **Package Management:** Helm 3
* **Ingress Controller:** Nginx Ingress
* **SSL/TLS Automation:** cert-manager + Let's Encrypt (HTTP-01 Challenge)
* **Application Runtime:** Node.js (Microservice Proxy + Web UI)

---

## 🚀 Deployment Guide

### 1. Provision Infrastructure (Terraform)

Ensure you have the `gcloud CLI` authorized and `terraform` installed.

```bash
# 1. Initialize Terraform providers and modules
terraform init

# 2. Preview planned infrastructure changes
terraform plan

# 3. Apply the configuration (provisions GKE, Nginx Ingress, and cert-manager)
terraform apply -auto-approve

```

### 2. Connect to the GKE Cluster

Once `terraform apply` completes successfully, fetch the cluster credentials:

```bash
gcloud container clusters get-credentials gke-private-cluster \
  --region europe-north1 \
  --project andrei-innowise-tests-120826

```

---

### 3. Build & Push Image to GCP Artifact Registry

To host your custom container image in GCP Artifact Registry:

```bash
# 1. Clone the official NASA APOD repository
git clone [https://github.com/nasa/apod-api.git](https://github.com/nasa/apod-api.git)
cd apod-api

# 2. Create a Docker repository in GCP Artifact Registry
gcloud artifacts repositories create gke-repo \
  --repository-format=docker \
  --location=europe-north1 \
  --description="Docker repository for GKE images"

# 3. Authenticate Docker with GCP
gcloud auth configure-docker europe-north1-docker.pkg.dev

# 4. Build and push the Docker image
docker build -t europe-north1-docker.pkg.dev/andrei-innowise-tests-120826/gke-repo/nasa-apod:v1 .
docker push europe-north1-docker.pkg.dev/andrei-innowise-tests-120826/gke-repo/nasa-apod:v1

```

---

### 4. Deploy Kubernetes Manifests

Return to the root project directory and apply the Kubernetes manifests:

```bash
# 1. Apply the ClusterIssuer for Let's Encrypt
kubectl apply -f k8s-manifests/cluster-issuer.yaml

# 2. Deploy the application components (Deployment, Service, Ingress)
kubectl apply -f k8s-manifests/

```

---

### 5. Configure DNS A-Record

Retrieve the external IP address assigned to the Nginx Ingress Load Balancer:

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller

```

Copy the `EXTERNAL-IP` (e.g., `35.228.37.177`) and add an **A-record** in your DNS management panel:

* **Host / Subdomain:** `nasa.andrei-test`
* **Type:** `A`
* **Value:** `35.228.37.177`

---

## 🔍 Verification & Health Checks

### 1. Check Pod & Service Status

```bash
kubectl get pods -l app=apod-api

```

All pods should show status `1/1 Running`.

### 2. Verify TLS Certificate Issuance

```bash
kubectl get certificate

```

The `READY` column must display `True`:

```text
NAME            READY   SECRET          AGE
nasa-tls-cert   True    nasa-tls-cert   5m

```

### 3. Verify HTTPS Endpoint

Run a test request via terminal:

```bash
curl -I [https://nasa.andrei-test.lendo.dev](https://nasa.andrei-test.lendo.dev)

```

Expected output: `HTTP/2 200 OK`.

---

## 🌐 Application Endpoints

* **Web UI:** `https://nasa.andrei-test.lendo.dev/` — Interactive dashboard featuring the Astronomy Picture of the Day with media handling (images/videos) and dark theme.
* **REST API:** `https://nasa.andrei-test.lendo.dev/v1/apod/` — Returns the raw JSON metadata directly from the NASA APOD service.

```

```