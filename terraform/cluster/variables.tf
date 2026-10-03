# Values are split into three layers:
#
#   default here         — design decisions: the same in every environment
#   proxmox.auto.tfvars  — facts about this installation: addresses, names, storage (in git)
#   secrets.auto.tfvars  — token and keys (outside git)
#
# A variable without `default` is mandatory: Terraform will not start until you provide it.
# Everything environment-specific is marked this way — so copying this repo to another
# Proxmox ends in a readable error rather than a silent attempt to create the machine
# on a node that does not exist.

# ── Proxmox access ────────────────────────────────────────────────────────────

variable "proxmox_endpoint" {
  description = "Proxmox API address. → proxmox.auto.tfvars"
  type        = string
}

variable "proxmox_api_token" {
  description = "API token in the format USER@REALM!NAME=UUID. → secrets.auto.tfvars"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Do not verify the Proxmox certificate — it is self-signed. → proxmox.auto.tfvars"
  type        = bool
}

variable "node_name" {
  description = "Name of the Proxmox node the machine runs on. → proxmox.auto.tfvars"
  type        = string
}

# ── Machine: what depends on the environment ─────────────────────────────────

variable "vm_id" {
  description = "Machine ID in Proxmox. Must be free. → proxmox.auto.tfvars"
  type        = number

  validation {
    # Proxmox reserves IDs below 100 for internal use.
    condition     = var.vm_id >= 100 && var.vm_id <= 999999999
    error_message = "vm_id must be >= 100 — lower IDs are reserved by Proxmox."
  }
}

variable "vm_datastore" {
  description = "Storage for the machine disk. → proxmox.auto.tfvars"
  type        = string
}

variable "file_datastore" {
  description = "Storage for the OS image and the cloud-init file. Must have 'iso' and 'snippets' enabled. → proxmox.auto.tfvars"
  type        = string
}

# ── NAS: depends on the environment ──────────────────────────────────────────

variable "nas_server" {
  description = "Address of the NAS (OpenMediaVault) that exports the NFS share for VM disks. → proxmox.auto.tfvars"
  type        = string
}

variable "nas_export" {
  description = "NFS export on the NAS that Proxmox mounts as the 'nas' storage. → proxmox.auto.tfvars"
  type        = string
}

# ── Network: depends on the environment ──────────────────────────────────────

variable "network_bridge" {
  description = "Proxmox network bridge. → proxmox.auto.tfvars"
  type        = string
}

variable "vm_ip" {
  description = "Static machine address. Fixed, because the kubeconfig points at it — DHCP could change it and cut off access to the cluster. → proxmox.auto.tfvars"
  type        = string

  validation {
    # Catches a typo before touching Proxmox. Does not check whether the address is free —
    # a configuration file cannot know that.
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.vm_ip))
    error_message = "vm_ip must be an IPv4 address, for example 192.168.0.119."
  }
}

variable "vm_cidr_prefix" {
  description = "Subnet mask. → proxmox.auto.tfvars"
  type        = number

  validation {
    condition     = var.vm_cidr_prefix >= 8 && var.vm_cidr_prefix <= 30
    error_message = "vm_cidr_prefix must be within 8–30."
  }
}

variable "gateway" {
  description = "Default gateway. → proxmox.auto.tfvars"
  type        = string
}

variable "dns_servers" {
  description = "DNS servers for the machine. → proxmox.auto.tfvars"
  type        = list(string)
}

variable "ssh_public_keys" {
  description = "Public keys allowed onto the machine. → secrets.auto.tfvars"
  type        = list(string)

  validation {
    condition     = length(var.ssh_public_keys) > 0
    error_message = "Provide at least one key — otherwise you create a machine you cannot log in to."
  }
}

# ── Design decisions: the same everywhere ────────────────────────────────────

variable "vm_name" {
  description = "Machine name and hostname in the OS."
  type        = string
  default     = "k3s-1"
}

variable "vm_cores" {
  description = "CPU cores."
  type        = number
  default     = 2
}

variable "vm_memory_mb" {
  description = "Memory in MB. Monitoring (Prometheus and Grafana) only fits from ~6 GB."
  type        = number
  default     = 6144

  validation {
    condition     = var.vm_memory_mb >= 2048
    error_message = "k3s with Argo CD will not run sensibly below 2 GB."
  }
}

variable "vm_disk_gb" {
  description = "Disk in GB. Holds the OS, container images and volumes created locally by the cluster."
  type        = number
  default     = 40
}

variable "nas_disk_gb" {
  description = "Second disk of the machine, on the NAS: data that must not live on the host's NVMe (PostgreSQL, case files). Thin: takes only what is written. Growing it is changing this number."
  type        = number
  default     = 100
}

variable "debian_image_url" {
  description = "Debian cloud image. 'genericcloud' is the variant without drivers for physical hardware — smaller, since the machine is virtual anyway."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

variable "vm_user" {
  description = "Account created by cloud-init."
  type        = string
  default     = "maniumek"
}

variable "k3s_version" {
  description = "Pinned k3s version. Same rule as for container images: never 'latest', always a specific one."
  type        = string
  default     = "v1.36.4+k3s1"
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
