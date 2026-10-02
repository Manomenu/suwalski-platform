output "argocd_url" {
  description = "UI address. Works when DNS has a wildcard entry pointing at the node address."
  value       = "http://${var.argocd_host}"
}

output "argocd_namespace" {
  description = "Namespace — useful for kubectl and k9s."
  value       = var.argocd_namespace
}

output "haslo" {
  description = "How to read the initial password of the admin user."
  value       = "just argo password"
}
