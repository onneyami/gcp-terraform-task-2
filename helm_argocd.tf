# Deploy ArgoCD Helm Chart
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  set_list = [
    {
    name  = "server.extraArgs"
    value = ["--insecure"]
    }
  ]
}