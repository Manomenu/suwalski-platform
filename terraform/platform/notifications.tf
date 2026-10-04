# Argo CD Notifications: deployment results to Discord. Three events — a deployment failed
# (including a red smoke test: a failed PostSync hook fails the whole sync), an application
# turned Degraded, and a deployment succeeded.
#
# One Argo service per Discord channel, named exactly like the channel. WHICH event goes to
# which channel is decided by annotations on each Application —
#   notifications.argoproj.io/subscribe.<trigger>.<channel>: ""
# (Kubernetes allows 63 characters after the slash — hence no "discord-" prefix on the service;
# repo-rules.sh checks the length.)
# (failures to the environment's own channel, "deployed" to #suw-platf-deployments-notif); an
# Application without them is silent. The webhook URLs are not here: they are keys
# discord-<channel> of the argocd-notifications-secret Secret, each written by the setup.sh that
# owns the channel (scripts/.internal/lib.sh, discord_channel).

locals {
  discord_channels = [
    "suw-platf-notif",
    "suw-platf-deployments-notif",
    "app-automat-operat-notif",
    "app-automat-operat-dev-notif",
    "app-grzyby-notif",
  ]

  # The text of each message, as a Go template. printf builds one Discord "content" string and
  # toJson escapes it — an error message from Kubernetes can carry quotes and newlines that
  # would break plain JSON.
  messages = {
    "app-sync-failed"     = "printf \":x: **%s** — wdrożenie nieudane (%s)\\n%s\\n%s/applications/%s\" .app.metadata.name .app.status.operationState.phase .app.status.operationState.message .context.argocdUrl .app.metadata.name"
    "app-health-degraded" = "printf \":warning: **%s** — aplikacja w stanie Degraded\\n%s/applications/%s\" .app.metadata.name .context.argocdUrl .app.metadata.name"
    # Only the version: every image of a project carries the same sha-<commit> tag, and the
    # pinned third-party ones (curl, Gotenberg) would only be noise.
    "app-deployed" = "printf \":white_check_mark: **%s** — wdrożono %s\" .app.metadata.name (regexFind \"sha-[0-9a-f]+\" (join \" \" .app.status.summary.images) | default \"nową wersję\")"
  }

  notifications = {
    enabled = true

    # Links in the messages point here (home network).
    argocdUrl = "http://${var.argocd_host}"

    # The Secret holding the webhook URLs is written by the setup.sh scripts, not by the chart:
    # Terraform never sees the values.
    secret = { create = false }

    notifiers = {
      for channel in local.discord_channels : "service.webhook.${channel}" => <<-EOT
        url: $discord-${channel}
        headers:
          - name: Content-Type
            value: application/json
      EOT
    }

    # A webhook template names the service it goes through, so every message has a variant for
    # every channel; the annotation picks the channel.
    templates = {
      for name, message in local.messages : "template.${name}" => yamlencode({
        webhook = {
          for channel in local.discord_channels : channel => {
            method = "POST"
            body   = "{\"content\": {{ ${message} | toJson }}}"
          }
        }
      })
    }

    triggers = {
      "trigger.on-sync-failed"     = <<-EOT
        - when: app.status.operationState != nil and app.status.operationState.phase in ['Error', 'Failed']
          send: [app-sync-failed]
      EOT
      "trigger.on-health-degraded" = <<-EOT
        - when: app.status.health.status == 'Degraded'
          send: [app-health-degraded]
      EOT
      # Once per set of images: a deployment here is a new image tag set in the platform repo,
      # while the chart's git revision stays the same — and a code commit that changes nothing
      # in the cluster moves the revision without deploying anything.
      "trigger.on-deployed" = <<-EOT
        - when: app.status.operationState != nil and app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
          oncePer: join(app.status.summary.images, ",")
          send: [app-deployed]
      EOT
    }
  }
}
