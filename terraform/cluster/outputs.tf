output "vm_ip" {
  description = "Address of the k3s node."
  value       = var.vm_ip
}

output "ssh" {
  description = "How to log in."
  # Note: `ssh pve` leads to the Proxmox HOST (192.168.0.111), not here —
  # these are two different machines.
  value = "ssh ${var.vm_user}@${var.vm_ip}"
}

output "vm_user" {
  description = "Account created by cloud-init — the kubeconfig script uses it."
  value       = var.vm_user
}

# Deliberately WITHOUT a "ready-made command for eval" output. Such a string looks handy, but
# it depends on the directory you run it from and can export a relative path
# or — when tofu returns an error — hand eval the message together with color codes.
# Fetching the kubeconfig is what `just cluster kubeconfig` is for.
