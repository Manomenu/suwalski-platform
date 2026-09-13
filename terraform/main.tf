# Obraz systemu. Pobiera go sam Proxmox, więc nie ma kroku „ściągnij ręcznie i wgraj".
#
# content_type = "import", nie "iso". Proxmox 9 rozdziela te dwie rzeczy: „iso" to nośnik
# do włożenia do napędu, „import" to dysk do zaimportowania. Próba użycia obrazu z „iso"
# jako dysku kończy się odmową: „has wrong type 'iso' - needs to be 'images' or 'import'".
# Dzięki temu plik może zostać przy prawdziwym rozszerzeniu .qcow2 — storage typu iso
# przyjmował tylko .img/.iso i trzeba go było oszukiwać.
resource "proxmox_download_file" "debian" {
  content_type = "import"
  datastore_id = var.file_datastore
  node_name    = var.node_name
  url          = var.debian_image_url
  file_name    = "debian-13-genericcloud-amd64.qcow2"

  # Obraz „latest" pod tym adresem podmienia się co kilka tygodni. Bez tego Terraform
  # przy każdym uruchomieniu widziałby inny plik i chciał odtwarzać maszynę.
  overwrite = false
}

# Konfiguracja pierwszego startu, wgrywana na Proxmoksa jako snippet.
resource "proxmox_virtual_environment_file" "user_data" {
  content_type = "snippets"
  datastore_id = var.file_datastore
  node_name    = var.node_name

  source_raw {
    file_name = "${var.vm_name}-user-data.yaml"
    data = templatefile("${path.module}/templates/user-data.yaml.tftpl", {
      hostname = var.vm_name
      username = var.vm_user
      # jsonencode daje listę w zapisie ['a','b'] — JSON jest poprawnym YAML-em,
      # więc szablon nie potrzebuje pętli i sam pozostaje poprawnym YAML-em.
      ssh_keys    = jsonencode(var.ssh_public_keys)
      node_ip     = var.vm_ip
      k3s_version = var.k3s_version
    })
  }
}

resource "proxmox_virtual_environment_vm" "k3s" {
  name      = var.vm_name
  node_name = var.node_name
  vm_id     = var.vm_id

  description = "Węzeł k3s. Zarządzany Terraformem — zmiany klikane w interfejsie zostaną nadpisane."
  tags        = ["terraform", "k3s"]

  # Bez tego maszyna nie wstaje po restarcie hosta.
  on_boot = true

  agent {
    # Terraform czeka dzięki temu na realny adres IP zamiast zgadywać, że maszyna wstała.
    enabled = true
  }

  cpu {
    cores = var.vm_cores
    # „host" przekazuje maszynie zestaw instrukcji prawdziwego procesora zamiast
    # emulowanego minimum. Bezpieczne, bo maszyna nigdzie się nie migruje.
    type = "host"
  }

  memory {
    dedicated = var.vm_memory_mb
  }

  disk {
    datastore_id = var.vm_datastore
    import_from  = proxmox_download_file.debian.id
    interface    = "scsi0"
    size         = var.vm_disk_gb
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge = var.network_bridge
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.vm_datastore

    ip_config {
      ipv4 {
        address = "${var.vm_ip}/${var.vm_cidr_prefix}"
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_data_file_id = proxmox_virtual_environment_file.user_data.id
  }

  # Konsola szeregowa — obraz chmurowy Debiana wypisuje na nią logi startu, więc bez
  # niej podgląd w Proxmoksie zostaje czarny.
  serial_device {}
}
