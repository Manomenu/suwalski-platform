# Argo CD Notifications: deployment results to Discord. Three events — a deployment failed
# (including a red smoke test: a failed PostSync hook fails the whole sync), an application
# turned Degraded, and a deployment succeeded.
#
# What sends: this file (one Discord channel, the messages, the triggers). WHICH environment
# sends: annotations on its Application in argocd/apps/projects/ —
#   notifications.argoproj.io/subscribe.<trigger>.discord: ""
# An environment without them is silent. The webhook URL is not here: the
# argocd-notifications-secret Secret comes from scripts/setup.sh (DISCORD_WEBHOOK_URL).

locals {
  # A message is one Discord "content" string, built with printf and escaped by toJson — an
  # error message from Kubernetes can carry quotes and newlines that would break plain JSON.
  discord_message = "webhook:\n  discord:\n    method: POST\n    body: |\n      {\"content\": {{ printf %s | toJson }}}\n"

  notifications = {
    enabled = true

    # Links in the messages point here (home network).
    argocdUrl = "http://${var.argocd_host}"

    # The Secret holding the webhook URL is created by scripts/setup.sh, not by the chart:
    # Terraform never sees the value.
    secret = { create = false }

    notifiers = {
      "service.webhook.discord" = <<-EOT
        url: $discord-webhook-url
        headers:
          - name: Content-Type
            value: application/json
      EOT
    }

    templates = {
      "template.app-sync-failed" = format(local.discord_message,
      "\":x: **%s** — wdrożenie nieudane (%s)\\n%s\\n%s/applications/%s\" .app.metadata.name .app.status.operationState.phase .app.status.operationState.message .context.argocdUrl .app.metadata.name")
      "template.app-health-degraded" = format(local.discord_message,
      "\":warning: **%s** — aplikacja w stanie Degraded\\n%s/applications/%s\" .app.metadata.name .context.argocdUrl .app.metadata.name")
      "template.app-deployed" = format(local.discord_message,
      "\":white_check_mark: **%s** — wdrożono %s\" .app.metadata.name (join \", \" .app.status.summary.images)")
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
      # Once per deployed revision: after the sync and its smoke test went through, healthy.
      "trigger.on-deployed" = <<-EOT
        - when: app.status.operationState != nil and app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
          oncePer: app.status.operationState.syncResult.revision
          send: [app-deployed]
      EOT
    }
  }
}
