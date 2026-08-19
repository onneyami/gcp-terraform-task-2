output "gke_cluster_name" {
  value       = module.gke.cluster_name
  description = "Имя кластера GKE"
}

output "gke_egress_static_ip" {
  value       = module.gke.nat_static_ip
  description = "Статический IP для исходящего трафика кластера"
}

output "ingress_static_ip" {
  value       = google_compute_address.ingress_static_ip.address
  description = "Привяжи этот статический IP к A-записи домена *.andrei-test.lendo.dev"
}