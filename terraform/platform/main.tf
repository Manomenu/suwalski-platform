# Przestrzeń nazw tworzymy sami, a nie zostawiamy chartowi, żeby jej cykl życia był
# jawny: usunięcie tej konfiguracji ma po sobie posprzątać.
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # Argo wstaje w kilku krokach i pierwsze uruchomienie bywa wolne — bez tego Terraform
  # potrafi uznać je za nieudane, choć jeszcze trwa.
  timeout = 600
  wait    = true

  values = [yamlencode({
    # Serwer podaje własny certyfikat samopodpisany. Za traefikiem to tylko podwójne
    # szyfrowanie i ostrzeżenia w przeglądarce, więc wewnątrz klastra zostajemy przy HTTP.
    configs = {
      params = {
        "server.insecure" = true
      }
    }

    dex           = { enabled = var.enable_dex }
    notifications = { enabled = var.enable_notifications }
  })]
}

# Ingress piszemy sami zamiast włączać ten z charta — dzięki temu widać tu wprost, co
# traefik ma robić, zamiast szukać tego w wartościach charta.
resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  spec {
    # k3s wystawia traefika jako domyślną klasę ingressu; nazywamy ją wprost, żeby nie
    # zależeć od tego, co akurat jest domyślne.
    ingress_class_name = "traefik"

    rule {
      host = var.argocd_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "argocd-server"
              port { number = 80 }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}
