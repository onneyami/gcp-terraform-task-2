variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  default     = "europe-north1"
  description = "Регион размещения"
}

variable "zone" {
  type        = string
  default     = "europe-north1-a"
  description = "Зона размещения GKE"
}

variable "vpn_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR подсеть твоей VPN"
}

variable "innowise_ip" {
  type        = string
  description = "Публичный IP офиса Innowise"
}