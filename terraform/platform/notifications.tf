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

  # Each message is Go template code that leaves its text in $msg; the body then escapes it
  # with toJson — an error message from Kubernetes can carry quotes and newlines that would
  # break plain JSON.
  messages = {
    "app-sync-failed"     = "{{- $msg := printf \":x: **%s** — wdrożenie nieudane (%s)\\n%s\\n%s/applications/%s\" .app.metadata.name .app.status.operationState.phase .app.status.operationState.message .context.argocdUrl .app.metadata.name -}}"
    "app-health-degraded" = "{{- $msg := printf \":warning: **%s** — aplikacja w stanie Degraded\\n%s/applications/%s\" .app.metadata.name .context.argocdUrl .app.metadata.name -}}"

    # The version (every image of a project carries the same sha-<commit> tag; the pinned
    # third-party ones would be noise), the version it replaced — the last different image.tag in
    # the Application's history — the title of the newest commit, and a link to the GitHub
    # comparison listing every commit in between.
    "app-deployed" = <<-EOT
      {{- $cur := regexFind "sha-[0-9a-f]+" (join " " .app.status.summary.images) -}}
      {{- $prev := "" -}}
      {{- range .app.status.history -}}
        {{- with .source -}}{{- with .helm -}}{{- range .parameters -}}
          {{- if and (eq .name "image.tag") (ne .value $cur) -}}{{- $prev = .value -}}{{- end -}}
        {{- end -}}{{- end -}}{{- end -}}
      {{- end -}}
      {{- $repo := .app.spec.source.repoURL | replace "git@github.com:" "https://github.com/" | trimSuffix ".git" -}}
      {{- $msg := printf ":white_check_mark: **%s** — wdrożono %s" .app.metadata.name (default "nową wersję" $cur) -}}
      {{- if $prev -}}{{- $msg = printf "%s (poprzednio %s)" $msg $prev -}}{{- end -}}
      {{- if $cur -}}
        {{- $title := (call .repo.GetCommitMetadata (trimPrefix "sha-" $cur)).Message | splitList "\n" | first -}}
        {{- $msg = printf "%s\nOstatni commit: %s" $msg $title -}}
      {{- end -}}
      {{- if and $prev $cur -}}
        {{- $msg = printf "%s\nZmiany: <%s/compare/%s...%s>" $msg $repo (trimPrefix "sha-" $prev) (trimPrefix "sha-" $cur) -}}
      {{- end -}}
    EOT
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
            body   = "${trimspace(message)}{\"content\": {{ toJson $msg }}}"
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
