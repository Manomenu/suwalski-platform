# Rate limiting for public applications (public = true in edge.auto.tfvars): a fuse against someone
# hammering an endpoint directly, not a per-user limit. Generous on purpose: every Claude user's
# requests come from Anthropic's servers (ChatGPT's from OpenAI's), so a tight per-IP limit would
# cut all of them off at once. The real limits live in the apps (grzyby: a daily limit of new
# forest areas, a queue to Nominatim, a cache of answers).
#
# The free plan allows one such rule, counted per IP and Cloudflare data centre over 10 s, with a
# 10 s block — hence the fixed numbers below. 50 requests in 10 s is about 300 a minute.

locals {
  public_hosts = [for name, app in var.apps : "${name}.${var.zone_name}" if app.public]
}

resource "cloudflare_ruleset" "rate_limit" {
  count = length(local.public_hosts) > 0 ? 1 : 0

  zone_id     = data.cloudflare_zone.main.zone_id
  name        = "public apps rate limit"
  description = "terraform/edge (suwalski-platform) — nie edytuj w panelu"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [{
    description = "public apps: at most 50 requests per 10 s from one IP"
    expression  = "(http.host in {${join(" ", [for host in local.public_hosts : "\"${host}\""])}})"
    action      = "block"
    enabled     = true
    ratelimit = {
      characteristics     = ["ip.src", "cf.colo.id"]
      period              = 10
      requests_per_period = 50
      mitigation_timeout  = 10
    }
  }]
}
