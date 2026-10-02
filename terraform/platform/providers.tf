# This configuration is separate from terraform/cluster/ for one specific reason:
# a provider cannot be configured with a file that is created in the same run.
# The machine and the kubeconfig must already exist before anything here starts.
#
# Order: just cluster apply -> just cluster kubeconfig -> just platform apply

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
