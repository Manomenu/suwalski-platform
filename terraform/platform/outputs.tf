output "argocd_url" {
  description = "UI address. Works when DNS has a wildcard entry pointing at the node address."
  value       = "http://${var.argocd_host}"
}
