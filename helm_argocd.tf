# Read the static signing key from GCP Secret Manager
data "google_secret_manager_secret_version" "argocd_secretkey" {
  secret  = "argocd-server-secretkey"
  project = "andrei-innowise-tests-120826"
}

# Read stored Jenkins API token from GCP Secret Manager
data "google_secret_manager_secret_version" "jenkins_argocd_token" {
  secret  = "jenkins-argocd-token"
  project = "andrei-innowise-tests-120826"
}

# Dynamically parse JWT payload (jti & iat) from the stored token
locals {
  jwt_payload_raw = split(".", trimspace(data.google_secret_manager_secret_version.jenkins_argocd_token.secret_data))[1]
  jwt_payload_padded = "${local.jwt_payload_raw}${
    length(local.jwt_payload_raw) % 4 == 2 ? "==" : (
      length(local.jwt_payload_raw) % 4 == 3 ? "=" : ""
    )
  }"
  jwt_payload_clean = replace(replace(local.jwt_payload_padded, "-", "+"), "_", "/")
  jwt_json          = jsondecode(base64decode(local.jwt_payload_clean))

  argocd_jenkins_tokens_json = jsonencode([
    {
      id  = local.jwt_json.jti
      iat = local.jwt_json.iat
    }
  ])
}

# 1. Deploy ArgoCD via Helm
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "10.8.2"

  values = [
    <<-EOF
    server:
      extraArgs:
        - --insecure

    configs:
      # Inject persistent JWT signing key AND active token registry
      secret:
        extra:
          server.secretkey: "${data.google_secret_manager_secret_version.argocd_secretkey.secret_data}"
          accounts.jenkins.tokens: '${local.argocd_jenkins_tokens_json}'

      # Enable 'jenkins' account with API key capability
      cm:
        accounts.jenkins: apiKey

      # Assign application sync/get permissions to the jenkins account
      rbac:
        policy.csv: |
          p, role:jenkins-sync, applications, sync, */*, allow
          p, role:jenkins-sync, applications, get, */*, allow
          g, jenkins, role:jenkins-sync
    EOF
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