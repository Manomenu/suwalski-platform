# Facts about the Cloudflare account and the list of exposed applications. No secrets and no
# emails, so it is in git — just like proxmox.auto.tfvars.
#
# People's emails live in access/*.json (outside git). Here there is only the NAME of the group
# a given application admits.

account_id = "55af3255ed85296ce7f73835ca30755e"
zone_name  = "gugnowski.com"
team_name  = "gugnowski" # <team>.cloudflareaccess.com

apps = {
  # automat-operat-dev.gugnowski.com — the dev version (namespace automat-operat-dev). Admits
  # its own group, "automat-operat-dev" (you and the testers), not the production group.
  # Production will be added as `automat-operat = { access = "automat-operat" }`.
  automat-operat-dev = { access = "automat-operat-dev" }

  # grzyby.gugnowski.com — the MCP server for chatbots (namespace grzyby). Public: Claude and
  # ChatGPT call /mcp from their own servers and cannot log in to Access. The app checks its
  # own key (MCP_KEY, scripts/projects/grzyby/setup.sh) — or lets anyone in when the chart's
  # server.allowPublic is on; ratelimit.tf puts a generous per-IP fuse in front of it.
  grzyby = { public = true }
}
