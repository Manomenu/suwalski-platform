# TODO

Rzeczy do przemyślenia, nie do zrobienia od ręki. Każda dostaje własną sesję — tutaj
zapisujemy tylko, o co chodziło i dlaczego, żeby pomysł nie zginął.

---

## Cały Proxmox jako kod, nie tylko jedna maszyna

**Status:** zapisane, nieprzeanalizowane. Nic nie było badane pod tym kątem.

Dziś Terraform zarządza **jedną** maszyną — węzłem k3s (ID 119). Wszystko inne, co stoi na
`aoostar` (ID 112–118: NAS, routing, VPN, DNS, monitoring, dashboard, media), powstało
przez klikanie i nie jest nigdzie opisane. Pomysł: przenieść resztę pod ten sam reżim, tak
żeby cały hypervisor dało się odtworzyć z repo.

### Główna motywacja: sieć

Nie chodzi o porządek dla porządku — chodzi o to, żeby **sieć klastra przestała być tą
samą siecią, co domowa**. Obecnie węzeł siedzi na `vmbr0` w `192.168.0.0/24`, obok
wszystkiego innego: laptopa, telewizora, telefonów. Czyli klaster i prywatne urządzenia
widzą się nawzajem bez żadnej granicy.

Do przemyślenia przy okazji:

- osobny mostek albo VLAN dla maszyn zarządzanych kodem,
- czy da się to opisać Terraformem (provider ma zasoby na mostki i VLAN-y — do sprawdzenia,
  bo część z nich w wersji 0.113 jest oznaczona jako przestarzała),
- co się wtedy dzieje z dostępem z laptopa: przez router, przez Tailscale, a może jedno
  i drugie zależnie od tego, do czego.

### Wątek poboczny, na razie czysta spekulacja

Dziś ścieżki DNS do usług ustawiane są **ręcznie w AdGuardzie** (LXC 115) i stamtąd kierują
na nginxa. To działa, ale jest konfiguracją, która istnieje tylko w interfejsie jednego
kontenera — czyli dokładnie tym, od czego uciekamy.

Pytania otwarte, żadne niezweryfikowane:

- czy dałoby się porzucić ręczne wpisy na rzecz czegoś generowanego z kodu,
- czy przy sensownym ingressie w klastrze **AdGuard w ogóle byłby jeszcze potrzebny** w tej
  roli — może zostałby tylko do blokowania reklam, a nie do kierowania ruchu,
- czy rolę „gdzie jest dana usługa" powinien przejąć ingress plus jeden wpis wieloznaczny
  w DNS, zamiast wpisu na każdą usługę osobno.

To są luźne przypuszczenia spisane na gorąco, a nie plan. Zanim cokolwiek, trzeba obejrzeć,
jak ten DNS i nginx są dziś naprawdę skonfigurowane.

### Czego ta zmiana nie może zepsuć

Na tym hypervisorze stoją rzeczy używane na co dzień. Przejęcie ich przez Terraform oznacza
**import istniejącego stanu**, a nie postawienie od nowa obok — pomyłka tutaj kasuje NAS.
To jest główny powód, dla którego to zadanie wymaga własnej sesji i spokoju.
