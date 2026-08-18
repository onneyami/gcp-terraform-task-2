# Создаем единую VPC сеть
resource "google_compute_network" "vpc" {
  name                    = "gke-vpc"
  auto_create_subnetworks = false
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