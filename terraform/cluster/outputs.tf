output "vm_ip" {
  description = "Address of the k3s node."
  value       = var.vm_ip
}

output "vm_user" {
  description = "Account created by cloud-init — the kubeconfig script uses it."
  value       = var.vm_user
}

# Deliberately WITHOUT a "ready-made command for eval" output. Such a string looks handy, but
# it depends on the directory you run it from and can export a relative path
# or — when tofu returns an error — hand eval the message together with color codes.
# Fetching the kubeconfig is what `just cluster kubeconfig` is for.
