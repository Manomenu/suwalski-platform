output "vm_ip" {
  description = "Adres węzła k3s."
  value       = var.vm_ip
}

output "ssh" {
  description = "Jak się zalogować."
  # Uwaga: `ssh pve` prowadzi do HOSTA Proxmoksa (192.168.0.111), a nie tutaj —
  # to dwie różne maszyny.
  value = "ssh ${var.vm_user}@${var.vm_ip}"
}

output "vm_user" {
  description = "Konto założone przez cloud-init — używa go skrypt po kubeconfig."
  value       = var.vm_user
}

# Świadomie BEZ wyjścia typu „gotowa komenda do eval". Taki ciąg wygląda wygodnie, ale
# zależy od katalogu, z którego go uruchomisz, i potrafi wyeksportować ścieżkę względną
# albo — gdy tofu zwróci błąd — oddać do eval komunikat razem z kodami kolorów.
# Od pobrania kubeconfiga jest ./scripts/kubeconfig.sh.
