# Deploy cert-manager Helm chart using Terraform Helm Provider
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  set = [ 
    {  #allow cert-manager to create its own CRDs (Custom Resource Definitions) in the cluster
    name  = "installCRDs"
    value = "true"
    }
  ]
}