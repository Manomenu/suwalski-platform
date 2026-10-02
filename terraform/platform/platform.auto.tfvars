# Facts about this installation. No secrets, so it is in git — just like proxmox.auto.tfvars.
#
# The name must be covered by the wildcard DNS entry:
#   *.k8s.suwalski.internal  ->  192.168.0.119

argocd_host = "argocd.k8s.suwalski.internal"
