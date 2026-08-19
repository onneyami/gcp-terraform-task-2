output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "nat_static_ip" {
  value = google_compute_address.nat_ip.address
}

# for helm
output "endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "GKE Control Plane IP/Endpoint"
}

output "cluster_ca_certificate" {
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  description = "GKE Control Plane CA Certificate"
}