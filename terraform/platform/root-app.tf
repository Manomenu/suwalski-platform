# Aplikacja korzeniowa — ostatnia rzecz, jaką Terraform robi w tym klastrze.
#
# Wskazuje na katalog argocd/apps/ w tym repo. Od tej chwili nową aplikację dodaje się
# PLIKIEM W GICIE, a nie poleceniem. To wzorzec „app of apps": jeden obiekt postawiony
# ręką, reszta rozmnaża się sama.
#
# Dlaczego manifestem, a nie zasobem providera kubernetes: Application to typ wniesiony
# przez CRD Argo, którego schemat pojawia się dopiero po instalacji charta. Zasób
# `kubernetes_manifest` odczytuje schemat na etapie PLANOWANIA — czyli zanim CRD istnieje.
# To ta sama pułapka co z kubeconfigiem, o jeden poziom głębiej.
resource "terraform_data" "root_app" {
  # Zmiana treści manifestu wymusza ponowne zastosowanie.
  triggers_replace = [local.root_app_manifest]

  provisioner "local-exec" {
    # Manifest i ścieżka wchodzą przez zmienne środowiskowe, nie przez sklejanie napisów.
    # Dzięki temu nic nie trafia do listy procesów i nie ma gdzie pomylić cudzysłowów —
    # wcześniejsza wersja sklejała ścieżkę z apostrofami, które `kubectl` brał za część
    # nazwy pliku i zgłaszał „no such file" przy istniejącym pliku.
    command = <<-EOT
      set -euo pipefail
      test -f "$KUBECONFIG_PATH" || {
        echo "brak kubeconfiga: $KUBECONFIG_PATH" >&2
        echo "  source ../../scripts/cluster/kubectl-setup.sh" >&2
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
