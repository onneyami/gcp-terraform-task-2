# 1. Read the permanently reserved static IP address from GCP (Read-Only)
data "google_compute_address" "ingress_static_ip" {
  name   = "gke-ingress-static-ip"
  region = var.region
}

# 2. Deploy the ingress-nginx Helm chart using the reserved static IP
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  set = [
    { # Connect the pre-reserved static IP to the GCP Network Load Balancer created by Ingress Nginx
      name  = "controller.service.loadBalancerIP"
      value = data.google_compute_address.ingress_static_ip.address
    },
    { # Register the nginx ingress class in the cluster
      name  = "controller.ingressClassResource.name"
      value = "nginx"
    },
    { # Make nginx the default ingress class for the cluster
      name  = "controller.ingressClassResource.default"
      value = "true"
    }
  ]
}