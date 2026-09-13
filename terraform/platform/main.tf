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
    # Własna nazwa tego obiektu, niezwiązana z niczym innym. Celowo NIE „argocd-server",
    # bo tak nazywa się Usługa w backendzie niżej — dwie różne rzeczy o tej samej nazwie
    # czytałoby się jak odwołanie, którym nie są. Przy okazji nie zderzy się z Ingressem
    # z charta, gdyby kiedyś został włączony.
    name      = "argocd-ui"
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
              # Chart nazywa swoje zasoby wzorcem <nazwa-wydania>-<komponent>, więc nazwa
              # usługi wynika z nazwy wydania. Wyliczamy ją zamiast wpisywać: inaczej
              # zmiana nazwy wydania cicho rozspoiłaby Ingress od usługi.
              name = "${helm_release.argocd.name}-server"
              port { number = 80 }
            }
          }
        }
      }
    }
  }

  # depends_on niepotrzebne: odwołanie do helm_release.argocd.name w backendzie samo
  # ustawia kolejność.
}
