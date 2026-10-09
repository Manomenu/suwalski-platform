# Zone-wide settings (not per application).

# Always Use HTTPS: Cloudflare answers plain http:// with a redirect to https:// before the
# request reaches the tunnel. Needed by the pomiary course tests (they check the redirect), and
# it is the right default for every host in the zone anyway (grzyby, automat-operat-dev).
# Provider v5: one cloudflare_zone_setting resource per setting, selected by setting_id.
resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = data.cloudflare_zone.main.zone_id
  setting_id = "always_use_https"
  value      = "on"
}
