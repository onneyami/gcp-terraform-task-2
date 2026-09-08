resource "google_compute_firewall" "allow_wireguard_udp" {
  name        = "allow-wireguard-udp"
  network     = google_compute_network.vpc.name
  description = "Allow WireGuard UDP traffic"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_gke_master_webhooks" {
  name        = "allow-gke-master-webhooks"
  network     = google_compute_network.vpc.name
  description = "Allow GKE Master control plane to reach worker nodes for cert-manager and ingress-nginx webhooks"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["8443", "9443"]
  }

  source_ranges = ["172.16.0.0/28"] # Master IPv4 CIDR Block
  target_tags   = ["gke-node"]
}