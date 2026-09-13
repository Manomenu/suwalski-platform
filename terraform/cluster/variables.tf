# Podział wartości na trzy warstwy:
#
#   default tutaj        — decyzje projektowe: takie same w każdym środowisku
#   proxmox.auto.tfvars  — fakty o tej instalacji: adresy, nazwy, storage (w gicie)
#   secrets.auto.tfvars  — token i klucze (poza gitem)
#
# Zmienna bez `default` jest obowiązkowa: Terraform nie ruszy, póki jej nie podasz.
# Tak są oznaczone wszystkie rzeczy zależne od środowiska — dzięki temu skopiowanie
# tego repo na inny Proxmox kończy się czytelnym błędem, a nie cichą próbą postawienia
# maszyny na nieistniejącym węźle.

# ── Dostęp do Proxmoksa ───────────────────────────────────────────────────────

variable "proxmox_endpoint" {
  description = "Adres API Proxmoksa. → proxmox.auto.tfvars"
  type        = string
}

variable "proxmox_api_token" {
  description = "Token API w formacie USER@REALM!NAZWA=UUID. → secrets.auto.tfvars"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Nie weryfikuj certyfikatu Proxmoksa — jest samopodpisany. → proxmox.auto.tfvars"
  type        = bool
}

variable "node_name" {
  description = "Nazwa węzła Proxmoksa, na którym stanie maszyna. → proxmox.auto.tfvars"
  type        = string
}

# ── Maszyna: co zależy od środowiska ──────────────────────────────────────────

variable "vm_id" {
  description = "ID maszyny w Proxmoksie. Musi być wolne. → proxmox.auto.tfvars"
  type        = number

  validation {
    # Proxmox rezerwuje numery poniżej 100 na potrzeby wewnętrzne.
    condition     = var.vm_id >= 100 && var.vm_id <= 999999999
    error_message = "vm_id musi być >= 100 — niższe numery są zarezerwowane przez Proxmoksa."
  }
}

variable "vm_datastore" {
  description = "Storage na dysk maszyny. → proxmox.auto.tfvars"
  type        = string
}

variable "file_datastore" {
  description = "Storage na obraz systemu i plik cloud-init. Musi mieć włączone 'iso' i 'snippets'. → proxmox.auto.tfvars"
  type        = string
}

# ── Sieć: zależy od środowiska ────────────────────────────────────────────────

variable "network_bridge" {
  description = "Mostek sieciowy Proxmoksa. → proxmox.auto.tfvars"
  type        = string
}

variable "vm_ip" {
  description = "Statyczny adres maszyny. Stały, bo wskazuje na niego kubeconfig — DHCP mogłoby go zmienić i zerwać dostęp do klastra. → proxmox.auto.tfvars"
  type        = string

  validation {
    # Łapie literówkę przed dotknięciem Proxmoksa. Nie sprawdza, czy adres jest wolny —
    # tego z pliku konfiguracyjnego nie da się wiedzieć.
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.vm_ip))
    error_message = "vm_ip musi być adresem IPv4, na przykład 192.168.0.119."
  }
}

variable "vm_cidr_prefix" {
  description = "Maska podsieci. → proxmox.auto.tfvars"
  type        = number

  validation {
    condition     = var.vm_cidr_prefix >= 8 && var.vm_cidr_prefix <= 30
    error_message = "vm_cidr_prefix musi mieścić się w 8–30."
  }
}

variable "gateway" {
  description = "Brama domyślna. → proxmox.auto.tfvars"
  type        = string
}

variable "dns_servers" {
  description = "Serwery DNS dla maszyny. → proxmox.auto.tfvars"
  type        = list(string)
}

variable "ssh_public_keys" {
  description = "Klucze publiczne wpuszczane na maszynę. → secrets.auto.tfvars"
  type        = list(string)

  validation {
    condition     = length(var.ssh_public_keys) > 0
    error_message = "Podaj przynajmniej jeden klucz — inaczej postawisz maszynę, do której się nie zalogujesz."
  }
}

# ── Decyzje projektowe: te same wszędzie ──────────────────────────────────────

variable "vm_name" {
  description = "Nazwa maszyny i hostname w systemie."
  type        = string
  default     = "k3s-1"
}

variable "vm_cores" {
  description = "Rdzenie procesora."
  type        = number
  default     = 2
}

variable "vm_memory_mb" {
  description = "Pamięć w MB. Faza 7 (Prometheus i Grafana) zmieści się dopiero od ~6 GB."
  type        = number
  default     = 6144

  validation {
    condition     = var.vm_memory_mb >= 2048
    error_message = "k3s z Argo CD poniżej 2 GB nie wstanie sensownie."
  }
}

variable "vm_disk_gb" {
  description = "Dysk w GB. Mieści system, obrazy kontenerów i wolumeny tworzone lokalnie przez klaster."
  type        = number
  default     = 40
}

variable "debian_image_url" {
  description = "Obraz chmurowy Debiana. 'genericcloud' to wariant bez sterowników do fizycznego sprzętu — mniejszy, bo maszyna i tak jest wirtualna."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

variable "vm_user" {
  description = "Konto zakładane przez cloud-init."
  type        = string
  default     = "maniumek"
}

variable "k3s_version" {
  description = "Przypięta wersja k3s. Ta sama reguła co przy obrazach kontenerów: nigdy 'najnowsza', zawsze konkretna."
  type        = string
  default     = "v1.36.4+k3s1"
}
