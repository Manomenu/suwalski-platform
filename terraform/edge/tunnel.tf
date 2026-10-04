# Tunnel: a persistent, outbound connection from the cluster to Cloudflare. Internet traffic
# comes in through it "upstream", so we open no port on the router, and the home IP can
# change as it pleases.
#
# Here the tunnel is only CREATED on the Cloudflare side. It is connected to by cloudflared,
# which runs in the cluster (kubernetes/cloudflared/, installed by Argo) and identifies itself
# with the token from the `tunnel_token` output.

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id = var.account_id
  name       = var.tunnel_name

  # Route configuration kept in Cloudflare, not in a file next to cloudflared. That way
  # this Terraform describes it, and cloudflared needs only the token — no ConfigMap
  # with routes that would have to be kept in sync with DNS.
  config_src = "cloudflare"
}

# Routes: which host goes where. Read top to bottom, the first matching rule wins.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id

  config = {
    ingress = concat(
      # One rule per application instead of a single wildcard *.gugnowski.com —
      # so each can require the token of its OWN Access application (below).
      [for name, app in var.apps : {
        hostname = "${name}.${var.zone_name}"
        service  = var.origin_service

        # Second line of defense. Access lets only logged-in users through, but if a DNS
        # record without an Access application were ever created, traffic would reach the
        # cluster without login. With this setting cloudflared itself checks the signed
        # Access token and rejects requests that lack it. A public app (public = true) has no
        # Access application, so nothing to check here — it guards itself with a key.
        origin_request = app.public ? null : {
          access = {
            required  = true
            team_name = var.team_name
            aud_tag   = [cloudflare_zero_trust_access_application.app[name].aud]
          }
        }
      }],
      # Catch-all rule, required by Cloudflare: anything that does not match above gets a 404
      # from cloudflared and never touches the cluster.
      [{ service = "http_status:404" }],
    )
  }
}

# The token cloudflared uses to identify itself to this tunnel. Whoever has it can attach to
# the tunnel and take over the traffic — that is why the output is `sensitive` and it reaches
# the cluster as a Secret via scripts/setup.sh, not via git.
data "cloudflare_zero_trust_tunnel_cloudflared_token" "homelab" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}
