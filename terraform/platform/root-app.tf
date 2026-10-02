# Root application — the last thing Terraform does in this cluster.
#
# It points to the argocd/apps/ directory in this repo (with subdirectories platform/ and
# projects/ — hence `recurse`). From then on a new application is added as a FILE IN GIT, not
# with a command. This is the "app of apps" pattern: one object created by hand, the rest
# multiplies on its own.
#
# Why a manifest and not a kubernetes provider resource: Application is a type introduced
# by Argo's CRD, whose schema only appears after the chart is installed. The
# `kubernetes_manifest` resource reads the schema at PLAN time — that is, before the CRD exists.
# It is the same trap as with the kubeconfig, one level deeper.
resource "terraform_data" "root_app" {
  # A change in the manifest content forces it to be applied again.
  triggers_replace = [local.root_app_manifest]

  provisioner "local-exec" {
    # The manifest and the path come in through environment variables, not string concatenation.
    # That way nothing ends up in the process list and there is no way to mess up the quotes —
    # an earlier version concatenated the path with apostrophes, which `kubectl` took as part
    # of the file name and reported "no such file" for an existing file.
    command = <<-EOT
      set -euo pipefail
      test -f "$KUBECONFIG_PATH" || {
        echo "missing kubeconfig: $KUBECONFIG_PATH" >&2
        echo "  just cluster kubeconfig" >&2
        exit 1
      }
      printf '%s' "$MANIFEST" | kubectl --kubeconfig "$KUBECONFIG_PATH" apply -f -
    EOT

    environment = {
      MANIFEST        = local.root_app_manifest
      KUBECONFIG_PATH = local.kubeconfig
    }
  }

  depends_on = [helm_release.argocd]
}

locals {
  root_app_manifest = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "root"
      namespace = var.argocd_namespace
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.platform_repo_url
        targetRevision = var.platform_repo_revision
        path           = "argocd/apps"
        directory      = { recurse = true }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.argocd_namespace
      }
      syncPolicy = {
        automated = { selfHeal = true, prune = true }
      }
    }
  })
}
