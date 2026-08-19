# Get authorization token of current gcloud session to access GKE cluster
data "google_client_config" "default" {}

provider "helm" {
  kubernetes = {
    host                   = "https://${module.gke.endpoint}"  # Take from outputs.tf from modules/gke 
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)  # also from outputs.tf from modules/gke
  }
}