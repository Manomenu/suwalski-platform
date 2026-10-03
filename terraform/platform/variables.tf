variable "argocd_chart_version" {
  description = "Helm chart version, not Argo CD itself. Pinned — the same rule as for k3s and images."
  type        = string
  default     = "10.9.0" # Argo CD v3.5.2
}

variable "argocd_namespace" {
  description = "Namespace for Argo CD. Its own, just as k3s keeps its parts in kube-system."
  type        = string
  default     = "argocd"
}

variable "argocd_host" {
  description = "The name you open the UI at. Must be covered by the wildcard DNS entry."
  type        = string
  default     = "argocd.k8s.suwalski.internal"
}

variable "enable_dex" {
  description = "Login via external providers (GitHub, Google). Without SSO it is a dead pod."
  type        = bool
  default     = false
}

variable "enable_notifications" {
  description = "Notifications about deployment results. We will enable them once there is somewhere to send them."
  type        = bool
  default     = false
}

# ── Root application ──────────────────────────────────────────────────────────

variable "platform_repo_url" {
  description = "This repo. Argo must read it over the network, so a public address, not a local path."
  type        = string
  default     = "https://github.com/Manomenu/suwalski-platform.git"
}

variable "platform_repo_revision" {
  description = "Branch Argo takes the list of applications from."
  type        = string
  default     = "master"
}

variable "state_passphrase" {
  description = "Encrypts the state (encryption.tf). → secrets.auto.tfvars, from STATE_PASSPHRASE in .secrets/platform.env"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "state_passphrase must be at least 16 characters (pbkdf2 requirement)."
  }
}
