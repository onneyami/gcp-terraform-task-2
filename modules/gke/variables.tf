variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "vpc_id" {
  type        = string
  description = "ID базовой VPC сети"
}

variable "region" {
  type        = string
  description = "Регион"
}

variable "zone" {
  type        = string
  description = "Зона кластера"
}

variable "authorized_cidrs" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  description = "Список разрешенных CIDR для доступа к Control Plane"
}