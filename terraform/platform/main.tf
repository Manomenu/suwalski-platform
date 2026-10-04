# We create the namespace ourselves instead of leaving it to the chart, so its lifecycle is
# explicit: removing this configuration should clean up after itself.
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

  # Argo starts up in several steps and the first run can be slow — without this Terraform
  # may treat it as failed while it is still in progress.
  timeout = 600
  wait    = true

  values = [yamlencode({
    # The server presents its own self-signed certificate. Behind traefik that only means double
    # encryption and browser warnings, so inside the cluster we stay with HTTP.
    configs = {
      params = {
        "server.insecure" = true
      }
    }

    dex = { enabled = var.enable_dex }
    # Deployment results to Discord — notifications.tf.
    notifications = local.notifications
  })]
}

# We write the Ingress ourselves instead of enabling the chart's — so it is visible right here
# what traefik is supposed to do, instead of hunting for it in the chart values.
resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    # This object's own name, unrelated to anything else. Deliberately NOT "argocd-server",
    # because that is the name of the Service in the backend below — two different things with
    # the same name would read like a reference, which they are not. It also will not collide
    # with the chart's Ingress, should that ever be enabled.
    name      = "argocd-ui"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  spec {
    # k3s exposes traefik as the default ingress class; we name it explicitly so we do not
    # depend on whatever happens to be the default.
    ingress_class_name = "traefik"

    rule {
      host = var.argocd_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              # The chart names its resources <release-name>-<component>, so the service
              # name follows from the release name. We derive it instead of hardcoding: otherwise
              # renaming the release would silently disconnect the Ingress from the service.
              name = "${helm_release.argocd.name}-server"
              port { number = 80 }
            }
          }
        }
      }
    }
  }

  # No depends_on needed: the reference to helm_release.argocd.name in the backend sets
  # the order by itself.
}
