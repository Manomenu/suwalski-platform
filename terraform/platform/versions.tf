terraform {
  required_version = ">= 1.9"

  required_providers {
    # Installs Argo CD from the ready-made Helm chart — the same one you would use by hand.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    # For things the chart does not cover: the namespace and the Ingress.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}
