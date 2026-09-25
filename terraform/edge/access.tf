# Access: kto może wejść. Trzy klocki, od najbardziej ogólnego:
#
#   metoda logowania   JAK ktoś udowadnia, kim jest     (tu: kod na maila)
#   reguła (policy)    KOGO wpuszczamy                   (tu: lista maili z grupy)
#   aplikacja          CO chronimy                       (tu: host witkowska-dev.gugnowski.com)
#
# Aplikacja wskazuje regułę i dozwoloną metodę logowania. Reguła jest wielokrotnego
# użytku — jedna grupa może chronić kilka aplikacji.

# ── Grupy: z plików, nie ze zmiennej ──────────────────────────────────────────

# Każda grupa to plik access/<nazwa>.json z listą maili, poza gitem. Pisze go ten setup.sh,
# do którego grupa należy: „admin” — platformowy scripts/setup.sh, „witkowska” —
# scripts/projects/witkowska/prod/setup.sh. Każdy skrypt dokłada tylko swój plik, więc
# projekty nie nadpisują sobie nawzajem grup, a kolejność uruchamiania nie ma znaczenia.
# (Jedna zmienna w jednym secrets.auto.tfvars zmusiłaby wszystkie skrypty do pisania
# tego samego pliku.)
locals {
  access_dir = "${path.module}/access"
  access_groups = {
    for f in fileset(local.access_dir, "*.json") :
    trimsuffix(f, ".json") => jsondecode(file("${local.access_dir}/${f}"))
  }
}

# ── Metoda logowania ──────────────────────────────────────────────────────────

# One-time PIN: wpisujesz maila, Cloudflare wysyła na niego kod. Jedyna metoda, która nie
# wymaga zakładania aplikacji u zewnętrznego dostawcy (Google, GitHub…). Kod przychodzi
# tylko na adres, który przepuszcza jakaś reguła — obcy mail po prostu nic nie dostaje.
resource "cloudflare_zero_trust_access_identity_provider" "otp" {
  account_id = var.account_id
  name       = "Kod na maila"
  type       = "onetimepin"
  config     = {}
}

# ── Reguły: po jednej na grupę ────────────────────────────────────────────────

resource "cloudflare_zero_trust_access_policy" "group" {
  for_each = local.access_groups

  account_id = var.account_id
  name       = "Grupa: ${each.key}"
  decision   = "allow"

  # include działa jak LUB: wystarczy pasować do jednego wpisu, czyli mieć jeden z maili.
  include = [for email in each.value : { email = { email = email } }]

  lifecycle {
    precondition {
      condition     = length(each.value) > 0
      error_message = "Grupa ${each.key} (access/${each.key}.json) jest pusta — nikogo by nie wpuściła. Uruchom setup.sh, który ją zapisuje."
    }
  }
}

# ── Aplikacje ─────────────────────────────────────────────────────────────────

resource "cloudflare_zero_trust_access_application" "app" {
  for_each = var.apps

  account_id = var.account_id
  name       = each.key
  type       = "self_hosted"
  domain     = "${each.key}.${var.zone_name}"

  session_duration = var.session_duration

  # Tylko kod na maila, i od razu formularz kodu — bez ekranu wyboru metody, który przy
  # jednej metodzie byłby dla cioci zbędnym kliknięciem.
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.otp.id]
  auto_redirect_to_identity = true

  # Nie pokazuj aplikacji na stronie startowej Access (<team>.cloudflareaccess.com) —
  # ciocia wchodzi prosto na swój adres.
  app_launcher_visible = false

  policies = [{
    id         = cloudflare_zero_trust_access_policy.group[each.value.access].id
    precedence = 1
  }]

  lifecycle {
    precondition {
      condition     = contains(keys(local.access_groups), each.value.access)
      error_message = "Aplikacja ${each.key} wpuszcza grupę \"${each.value.access}\", ale nie ma pliku access/${each.value.access}.json. Uruchom setup.sh, który ją zapisuje: scripts/setup.sh (admin) albo scripts/projects/<projekt>/…/setup.sh."
    }
  }
}
