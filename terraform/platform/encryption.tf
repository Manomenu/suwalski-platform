# The state (terraform.tfstate) is encrypted before it is written: it holds tokens and every
# detail of the environment, and encrypted it can live in git like the rest of the repo —
# so losing this laptop does not lose the record of what Terraform built. Without the
# passphrase the file is noise; with it, any machine can take over.
#
# The passphrase is STATE_PASSPHRASE in .secrets/platform.env, written into
# secrets.auto.tfvars by scripts/setup.sh. Keep a copy outside this laptop (a password
# manager): the state in git is only as recoverable as the passphrase.
terraform {
  encryption {
    key_provider "pbkdf2" "state" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state
    }

    # enforced: a plain state is refused instead of being read or written.
    state {
      method   = method.aes_gcm.state
      enforced = true
    }

    plan {
      method = method.aes_gcm.state
    }
  }
}
