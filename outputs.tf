output "gke_cluster_name" {
  value       = module.gke.cluster_name
  description = "Имя кластера GKE"
}

output "gke_egress_static_ip" {
  value       = module.gke.nat_static_ip
  description = "Статический IP для исходящего трафика кластера"
}