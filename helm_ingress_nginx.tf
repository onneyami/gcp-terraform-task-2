# 1. Create a static ip address in the GCP region for the ingress-nginx controller
resource "google_compute_address" "ingress_static_ip" {
  name   = "gke-ingress-static-ip"
  region = var.region  # get this from the variables.tf 
}

# 2. Deploy the ingress-nginx Helm chart using the reserved static IP
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  set = [
    {  #connect static ip created in GCP to network load balancer, that ingress -nginx will create
    name  = "controller.service.loadBalancerIP"
    value = google_compute_address.ingress_static_ip.address
    },
    {  # register nginx class in the cluster, so that we can use it in ingress manifests
    name  = "controller.ingressClassResource.name"
    value = "nginx"
    },
    {  #do nginx the default ingress class, so that we don't have to specify it in every ingress manifest
    name  = "controller.ingressClassResource.default"
    value = "true"
    }
  ]
}