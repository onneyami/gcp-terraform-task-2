resource "google_compute_firewall" "allow_wireguard_udp" {
  name        = "allow-wireguard-udp"
  network     = "gke-vpc"
  description = "Allow WireGuard UDP traffic"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  source_ranges = ["0.0.0.0/0"]
}