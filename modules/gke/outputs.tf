output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "nat_static_ip" {
  value = google_compute_address.nat_ip.address
}