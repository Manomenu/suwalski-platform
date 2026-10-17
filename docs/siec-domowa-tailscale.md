# Sieć domowa i Tailscale: praca spoza domu

Notatka z incydentu z 10.10.2026 i z analizy, co z nim zrobić. Zadania z niej wynikające są
w [`TODO.md`](../TODO.md) („Dostęp do klastra spoza domu”).

## Co się stało

Poza domem, w obcej sieci, laptop nie dosięgał klastra: `kubectl` (k3s API `192.168.0.119:6443`),
Proxmox (`.111:8006`) i NAS (`.197`) kończyły się timeoutem, a `scripts/projects/pomiary/setup.sh`
stawał na `== cluster ==`. Sam klaster działał — grzyby odpowiadały z internetu przez tunel.

## Diagnoza

1. **Kolizja adresów.** Obca sieć miała tę samą podsieć co dom, `192.168.0.0/24` (laptop dostał
   `192.168.0.77` od tamtejszego `192.168.0.1`). `arping .119` w tej sieci — cisza, więc to nie dom,
   a lokalna trasa do `192.168.0.0/24` prowadzi donikąd.
2. **Router podsieci Tailscale nie przekazuje ruchu.** Węzeł `tailscale` (`100.68.171.53`) jest online,
   rozgłasza `192.168.0.0/24` i sam odpowiada na ping, a laptop kieruje ruch do `192.168.0.x` przez
   niego (`ip route get` → `tailscale0`, tabela 52) — ale nic za nim nie odpowiada. Podejrzani:
   `net.ipv4.ip_forward=0` na tym węźle, brak dostępu węzła do LAN-u (kontener/VM bez mostka), SNAT.

To, że na węźle k3s działa teraz własny `tailscaled` (`argocd/manifests/tailscale/`), tego nie rozwiązuje:
tamten jest **wyjściowy** (klaster do maszyn tylko z tailnetu, np. model sędziego suwageval), z celowo
wyłączonym `--accept-routes`. Router podsieci, który wpuszcza laptop *do* domu, to osobna maszyna.

## Dwie drogi i ich koszt

| Droga | Co robi | Koszt |
| --- | --- | --- |
| **Naprawić router podsieci** | gdzie stoi (LXC/VM na Proxmoksie?), `ip_forward` na stałe w `/etc/sysctl.d/`, `--advertise-routes`, zatwierdzenie trasy w panelu Tailscale | mało pracy; wystarcza, dopóki obca sieć ma inną adresację niż dom |
| **Przenieść dom z `192.168.0.0/24` na nietypową podsieć** (np. `192.168.77.0/24` albo `10.77.0.0/24`) | żadna kawiarnia, hotel ani uczelnia jej nie zdubluje | dużo pracy — adresy są wpisane w wielu miejscach |

Gdzie siedzą adresy `192.168.0.x` (lista do przeglądu przy readresowaniu):

- router domowy: LAN, DHCP, rezerwacje;
- `terraform/cluster/proxmox.auto.tfvars`: `proxmox_endpoint`, `vm_ip`, `gateway`, `dns_servers`,
  `nas_server` → `apply` maszyny (nowe IP k3s), nowy `kubeconfig` (certyfikat API serwera ma IP w SAN —
  sprawdzić `tls-san` w cloud-init);
- sam Proxmox (`/etc/network/interfaces`), OpenMediaVault, eksporty NFS (`nas-storage`) i ich listy
  dozwolonych adresów;
- trasa rozgłaszana przez router podsieci Tailscale;
- wszystko, co ma IP na sztywno: `grep -rn "192\.168\.0\." .` w tym repo i w repo projektów.

## Czy warto przenosić podsieć

Tak, jeśli praca spoza domu ma być normalna: bez tego każda sieć `192.168.0.0/24` odcina klaster, a to
najczęstsza domyślna podsieć routerów. Tańsza połowa (naprawa routera podsieci) wystarczy, dopóki obca
sieć ma inną adresację; readresowanie usuwa przyczynę. Robić w jednej sesji, z planem powrotu (stary
router DHCP, `tofu plan` przed `apply`, kopia `kubeconfig`).
