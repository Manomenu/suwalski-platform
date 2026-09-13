terraform {
  required_version = ">= 1.9"

  required_providers {
    # Instaluje Argo CD z gotowego charta Helma — tego samego, którego użyłbyś ręcznie.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    # Do rzeczy, których chart nie obejmuje: przestrzeń nazw i Ingress.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}
