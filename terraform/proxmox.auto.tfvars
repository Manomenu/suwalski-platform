# Fakty o tej konkretnej instalacji Proxmoksa. Bez sekretów, więc idzie do gita —
# i o to chodzi: to jest zapis środowiska, a nie czyjeś lokalne ustawienia.
#
# Końcówka `.auto.tfvars` sprawia, że Terraform wczytuje ten plik sam, bez podawania
# `-var-file` przy każdym poleceniu. Zapomniana flaga to najczęstszy sposób, w jaki
# ludzie stawiają coś z domyślnymi wartościami zamiast z własnymi.
#
# Wartości odczytane z hosta, nie zgadnięte:
#   pveversion · pvesm status · ip -br link · qm list · pct list

proxmox_endpoint = "https://192.168.0.111:8006/"
proxmox_insecure = true
node_name        = "aoostar"

# 112-118 są zajęte przez istniejące maszyny i kontenery; 119 jest pierwszym wolnym.
vm_id = 119

vm_datastore   = "local-lvm" # lvmthin, 341 GB wolnego
file_datastore = "local"     # dir; ma włączone iso i snippets

network_bridge = "vmbr0"
vm_ip          = "192.168.0.119"
vm_cidr_prefix = 24
gateway        = "192.168.0.1"
dns_servers    = ["192.168.0.1", "1.1.1.1"]
