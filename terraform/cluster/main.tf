# OS image. Proxmox downloads it itself, so there is no "download by hand and upload" step.
#
# content_type = "import", not "iso". Proxmox 9 separates the two: "iso" is media to put
# in a drive, "import" is a disk to import. Trying to use an image from "iso" as a disk
# is refused: "has wrong type 'iso' - needs to be 'images' or 'import'".
# Thanks to that the file can keep its real .qcow2 extension — iso-type storage only
# accepted .img/.iso and had to be tricked.
resource "proxmox_download_file" "debian" {
  content_type = "import"
  datastore_id = var.file_datastore
  node_name    = var.node_name
  url          = var.debian_image_url
  file_name    = "debian-13-genericcloud-amd64.qcow2"

  # The "latest" image at this URL is replaced every few weeks. Without this Terraform
  # would see a different file on every run and want to recreate the machine.
  overwrite = false
}

# First-boot configuration, uploaded to Proxmox as a snippet.
resource "proxmox_virtual_environment_file" "user_data" {
  content_type = "snippets"
  datastore_id = var.file_datastore
  node_name    = var.node_name

  source_raw {
    file_name = "${var.vm_name}-user-data.yaml"
    data = templatefile("${path.module}/templates/user-data.yaml.tftpl", {
      hostname = var.vm_name
      username = var.vm_user
      # jsonencode produces a list written as ['a','b'] — JSON is valid YAML,
      # so the template needs no loop and stays valid YAML itself.
      ssh_keys    = jsonencode(var.ssh_public_keys)
      node_ip     = var.vm_ip
      k3s_version = var.k3s_version
    })
  }
}

# The NAS as Proxmox storage for VM disks. Proxmox mounts it over NFS and the machine sees a
# plain disk, so the database on it gets ordinary disk semantics instead of NFS in a pod.
resource "proxmox_storage_nfs" "nas" {
  id      = "nas"
  nodes   = [var.node_name]
  server  = var.nas_server
  export  = var.nas_export
  content = ["images"]
}

resource "proxmox_virtual_environment_vm" "k3s" {
  name      = var.vm_name
  node_name = var.node_name
  vm_id     = var.vm_id

  description = "Węzeł k3s. Zarządzany Terraformem — zmiany klikane w interfejsie zostaną nadpisane."
  tags        = ["terraform", "k3s"]

  # Without this the machine does not come back after a host restart.
  on_boot = true

  agent {
    # Thanks to this Terraform waits for a real IP address instead of guessing the machine is up.
    enabled = true
  }

  cpu {
    cores = var.vm_cores
    # "host" passes the real CPU's instruction set to the machine instead of an
    # emulated minimum. Safe, because the machine never migrates anywhere.
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

  # Data disk on the NAS, mounted in the machine at /mnt/nas (k3s storage class "nas").
  # Left out of Proxmox backups: they would copy the NAS onto itself; off-site backups of
  # what lives here are the job of the applications (PostgreSQL archiving).
  disk {
    datastore_id = proxmox_storage_nfs.nas.id
    interface    = "scsi1"
    size         = var.nas_disk_gb
    file_format  = "raw"
    discard      = "on"
    ssd          = true
    backup       = false
  }

  # The NAS is a VM on this host (OpenMediaVault, started with order 1). This machine
  # starts after it and stops before it, so its NAS disk is never left without the NAS.
  startup {
    order = 2
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

  # Serial console — the Debian cloud image writes its boot logs there, so without
  # it the Proxmox console stays black.
  serial_device {}
}
