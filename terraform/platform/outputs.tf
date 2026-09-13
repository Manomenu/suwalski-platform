output "argocd_url" {
  description = "Adres interfejsu. Działa, gdy w DNS jest wpis wieloznaczny na adres węzła."
  value       = "http://${var.argocd_host}"
}

output "argocd_namespace" {
  description = "Przestrzeń nazw — przyda się do kubectl i k9s."
  value       = var.argocd_namespace
}

output "haslo" {
  description = "Jak odczytać hasło początkowe użytkownika admin."
  value       = "./scripts/argocd/password.sh"
}
