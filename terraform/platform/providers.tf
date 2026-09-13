# Ta konfiguracja jest osobna od terraform/cluster/ z jednego konkretnego powodu:
# provider nie może być skonfigurowany plikiem, który powstaje w tym samym przebiegu.
# Maszyna i kubeconfig muszą już istnieć, zanim cokolwiek tutaj ruszy.
#
# Kolejność: cluster -> ./scripts/kubeconfig.sh -> platform

locals {
  kubeconfig = abspath("${path.module}/../../kubeconfig")
}

provider "helm" {
  kubernetes = {
    config_path = local.kubeconfig
  }
}

provider "kubernetes" {
  config_path = local.kubeconfig
}
