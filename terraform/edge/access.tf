# Access: who may get in. Three building blocks, from the most general:
#
#   login method       HOW someone proves who they are  (here: a code sent by email)
#   policy             WHOM we let in                    (here: the list of emails in a group)
#   application        WHAT we protect                   (here: host automat-operat-dev.gugnowski.com)
#
# The application points to a policy and the allowed login method. A policy is
# reusable — one group can protect several applications.

# ── Groups: from files, not from a variable ──────────────────────────────────

# Each group is a file access/<name>.json with a list of emails, outside git. It is written by
# the setup.sh that owns the group: "admin" — the platform scripts/setup.sh, "automat-operat-dev" —
# scripts/projects/automat-operat/dev/setup.sh, "automat-operat" —
# scripts/projects/automat-operat/prod/setup.sh. Each script adds only its own file, so
# projects do not overwrite each other's groups and the run order does not matter.
# (A single variable in a single secrets.auto.tfvars would force all scripts to write
# the same file.)
locals {
  access_dir = "${path.module}/access"
  access_groups = {
    for f in fileset(local.access_dir, "*.json") :
    trimsuffix(f, ".json") => jsondecode(file("${local.access_dir}/${f}"))
  }
}

# ── Login method ──────────────────────────────────────────────────────────────

# One-time PIN: you enter your email, Cloudflare sends a code to it. The only method that does
# not require registering an application with an external provider (Google, GitHub…). The code
# only goes to an address some policy lets through — a stranger's email simply gets nothing.
resource "cloudflare_zero_trust_access_identity_provider" "otp" {
  account_id = var.account_id
  name       = "Kod na maila"
  type       = "onetimepin"
  config     = {}
}

# ── Policies: one per group ───────────────────────────────────────────────────

resource "cloudflare_zero_trust_access_policy" "group" {
  for_each = local.access_groups

  account_id = var.account_id
  name       = "Grupa: ${each.key}"
  decision   = "allow"

  # include works as OR: matching one entry is enough, i.e. having one of the emails.
  include = [for email in each.value : { email = { email = email } }]

  lifecycle {
    precondition {
      condition     = length(each.value) > 0
      error_message = "Group ${each.key} (access/${each.key}.json) is empty — it would let nobody in. Run the setup.sh that writes it."
    }
  }
}

# ── Applications ──────────────────────────────────────────────────────────────

resource "cloudflare_zero_trust_access_application" "app" {
  for_each = var.apps

  account_id = var.account_id
  name       = each.key
  type       = "self_hosted"
  domain     = "${each.key}.${var.zone_name}"

  session_duration = var.session_duration

  # Only the email code, straight to the code form — without the method picker, which with
  # a single method would be a pointless click for auntie.
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.otp.id]
  auto_redirect_to_identity = true

  # Do not show the application on the Access start page (<team>.cloudflareaccess.com) —
  # auntie goes straight to her address.
  app_launcher_visible = false

  policies = [{
    id         = cloudflare_zero_trust_access_policy.group[each.value.access].id
    precedence = 1
  }]

  lifecycle {
    precondition {
      condition     = contains(keys(local.access_groups), each.value.access)
      error_message = "Application ${each.key} admits group \"${each.value.access}\", but there is no file access/${each.value.access}.json. Run the setup.sh that writes it: scripts/setup.sh (admin) or scripts/projects/<project>/…/setup.sh."
    }
  }
}
