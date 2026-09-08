# Создаем единую VPC сеть
resource "google_compute_network" "vpc" {
  name                    = "gke-vpc"
  auto_create_subnetworks = false
}

# 1. Create the GCP Service Account for External Secrets Operator
resource "google_service_account" "eso_sa" {
  account_id   = "eso-service-account"
  display_name = "External Secrets Operator SA"
}

# 2. Grant Secret Manager Accessor Role to the SA
resource "google_project_iam_member" "eso_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eso_sa.email}"
}

# 3. Allow K8s SA in 'external-secrets' namespace to impersonate GCP SA
resource "google_service_account_iam_member" "eso_workload_identity" {
  service_account_id = google_service_account.eso_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets]"
}

# Вызов модуля GKE
module "gke" {
  source     = "./modules/gke"
  project_id = var.project_id
  vpc_id     = google_compute_network.vpc.id
  region     = var.region
  zone       = var.zone

  authorized_cidrs = [
    {
      cidr_block   = var.vpn_cidr
      display_name = "VPN-Range"
    },
    {
      cidr_block   = var.innowise_ip
      display_name = "Innowise-Office-IP"
    }
  ]
}