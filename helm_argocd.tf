# 1. Deploy ArgoCD via Helm
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "10.8.2"

  set = [
    {
      name  = "server.extraArgs"
      value = "{--insecure}"
    }
  ]

  depends_on = [
    module.gke
  ]
}

# 2. Bootstrap Root Application natively via Helm Raw Chart
resource "helm_release" "argocd_root_app" {
  name             = "argocd-root-app"
  repository       = "https://bedag.github.io/helm-charts"
  chart            = "raw"
  namespace        = "argocd"
  create_namespace = false
  force_update     = true
  cleanup_on_fail  = true

  timeout = 120

  values = [
    <<-EOF
    resources:
      - apiVersion: argoproj.io/v1alpha1
        kind: Application
        metadata:
          name: root-app
          namespace: argocd
          finalizers:
            - resources-finalizer.argocd.argoproj.io
        spec:
          project: default
          source:
            repoURL: "https://github.com/onneyami/gcp-terraform-task-2.git"
            targetRevision: "main"
            path: "k8s-manifests/apps"
            directory:
              recurse: true
          destination:
            server: "https://kubernetes.default.svc"
            namespace: "argocd"
          syncPolicy:
            automated:
              prune: true
              selfHeal: true
            syncOptions:
              - CreateNamespace=true
              - SkipDryRunOnMissingResource=true
              - ServerSideApply=true
    EOF
  ]

  depends_on = [
    helm_release.argocd
  ]
}