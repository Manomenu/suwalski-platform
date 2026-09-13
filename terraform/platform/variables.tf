variable "argocd_chart_version" {
  description = "Wersja charta Helma, nie samego Argo CD. Przypięta — ta sama reguła co przy k3s i obrazach."
  type        = string
  default     = "10.9.0" # Argo CD v3.5.2
}

variable "argocd_namespace" {
  description = "Przestrzeń nazw dla Argo CD. Własna, tak jak k3s trzyma swoje części w kube-system."
  type        = string
  default     = "argocd"
}

variable "argocd_host" {
  description = "Nazwa, pod którą otworzysz interfejs. Musi mieścić się we wpisie wieloznacznym w DNS."
  type        = string
  default     = "argocd.k8s.suwalski.internal"
}

variable "enable_dex" {
  description = "Logowanie przez zewnętrznych dostawców (GitHub, Google). Bez SSO to martwy pod."
  type        = bool
  default     = false
}

variable "enable_notifications" {
  description = "Powiadomienia o wynikach wdrożeń. Włączymy, gdy będzie dokąd je wysyłać — patrz Faza 7."
  type        = bool
  default     = false
}
