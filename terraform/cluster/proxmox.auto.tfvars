# Facts about this particular Proxmox installation. No secrets, so it goes into git —
# and that is the point: this is a record of the environment, not someone's local settings.
#
# The `.auto.tfvars` suffix makes Terraform load this file on its own, without passing
# `-var-file` on every command. A forgotten flag is the most common way people
# deploy something with default values instead of their own.
#
# Values read from the host, not guessed:
#   pveversion · pvesm status · ip -br link · qm list · pct list · showmount -e <nas>

proxmox_endpoint = "https://192.168.0.111:8006/"
proxmox_insecure = true
node_name        = "aoostar"

# 112-118 are taken by existing VMs and containers; 119 is the first free one.
vm_id = 119

vm_datastore   = "local-lvm" # lvmthin, 341 GB free
file_datastore = "local"     # dir; has iso and snippets enabled

# OpenMediaVault (VM 113 on this host): two SSDs in RAID1, btrfs. The export is the shared
# folder "proxmox", open over NFS to this host only.
nas_server = "192.168.0.197"
nas_export = "/export/proxmox"

network_bridge = "vmbr0"
vm_ip          = "192.168.0.119"
vm_cidr_prefix = 24
gateway        = "192.168.0.1"
dns_servers    = ["192.168.0.1", "1.1.1.1"]
