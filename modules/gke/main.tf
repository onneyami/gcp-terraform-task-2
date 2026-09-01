# 1. Подсеть для GKE с Secondary Ranges (Pods + Services)
resource "google_compute_subnetwork" "gke_subnet" {
  name                     = "gke-subnet"
  ip_cidr_range            = "10.10.0.0/24" # Для самих нод ВМ
  region                   = var.region
  network                  = var.vpc_id
  private_ip_google_access = true

  # Вторичный диапазон для ПОДОВ (/21 вмещает до 16 нод при 55 подов/ноду)
  secondary_ip_range {
    range_name    = "pods-range"
    ip_cidr_range = "10.20.0.0/21"
  }

  # Вторичный диапазон для СЕРВИСОВ
  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "10.30.0.0/22"
  }
}

# 2. Static IP + Cloud NAT для исходящего трафика (Egress)
resource "google_compute_address" "nat_ip" {
  name   = "gke-nat-static-ip"
  region = var.region
}

resource "google_compute_router" "router" {
  name    = "gke-router"
  region  = var.region
  network = var.vpc_id
}

resource "google_compute_router_nat" "nat" {
  name                               = "gke-nat-gateway"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_ip.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# 3. Dedicated Service Account для GKE (for_each по минимальным ролям)
resource "google_service_account" "gke_sa" {
  account_id   = "gke-dedicated-sa"
  display_name = "Dedicated Service Account for GKE Nodes"
}

resource "google_project_iam_member" "gke_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

# 4. GKE Private Cluster (55 pods-per-node default, single zone)
resource "google_container_cluster" "primary" {
  name     = "gke-private-cluster"
  location = var.zone # europe-north1-a

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Отключаем защиту от удаления
  deletion_protection = false

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.vpc_id
  subnetwork = google_compute_subnetwork.gke_subnet.id

  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.gke_subnet.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.gke_subnet.secondary_ip_range[1].range_name
  }

  # Устанавливаем лимит 55 подов на ноду
  default_max_pods_per_node = 55

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Динамический блок разрешенных диапазонов для подключения к API Мастера
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_cidrs
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}

# 5. Dedicated Node Pool (1-3 ноды n2-standard-4 с автомасштабированием)
resource "google_container_node_pool" "primary_nodes" {
  name       = "nodepool-n2-standard-4"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    machine_type = "n2-standard-4"
    disk_size_gb = 50
    disk_type    = "pd-balanced"

    service_account = google_service_account.gke_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    tags = ["gke-node"]
  }
}