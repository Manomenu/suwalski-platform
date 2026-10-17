# Cały Proxmox jako kod, nie tylko jedna maszyna

Zapisane, nieprzeanalizowane — nic nie było badane pod tym kątem. Zadanie jest w [`TODO.md`](../TODO.md)
(„Proxmox poza k3s jako kod”); spekulacje bez decyzji — w [`pomysly.md`](pomysly.md).

Dziś Terraform zarządza **jedną** maszyną — węzłem k3s (ID 119). Wszystko inne, co stoi na `aoostar`
(ID 112–118: NAS, routing, VPN, DNS, monitoring, dashboard, media), powstało przez klikanie i nie jest
nigdzie opisane. Pomysł: przenieść resztę pod ten sam reżim, tak żeby cały hypervisor dało się odtworzyć
z repo. (Homarr, LXC 117, został już zastąpiony przez Homepage w klastrze.)

## Główna motywacja: sieć

Nie chodzi o porządek dla porządku — chodzi o to, żeby **sieć klastra przestała być tą samą siecią, co
domowa**. Obecnie węzeł siedzi na `vmbr0` w `192.168.0.0/24`, obok wszystkiego innego: laptopa, telewizora,
telefonów. Czyli klaster i prywatne urządzenia widzą się nawzajem bez żadnej granicy.

Do przemyślenia przy okazji:

- osobny mostek albo VLAN dla maszyn zarządzanych kodem,
- czy da się to opisać Terraformem (provider ma zasoby na mostki i VLAN-y — do sprawdzenia, bo część z nich
  w wersji 0.113 jest oznaczona jako przestarzała),
- co się wtedy dzieje z dostępem z laptopa: przez router, przez Tailscale, a może jedno i drugie zależnie
  od tego, do czego (patrz [`siec-domowa-tailscale.md`](siec-domowa-tailscale.md)).

## Deklaratywny DNS i odejście od AdGuarda

Osobne zadanie, do zrobienia w tym repo jako `terraform/dns/`.

Dziś wpisy DNS klika się w interfejsie AdGuarda (LXC 115). Cel: opisać strefę kodem, tak jak resztę
infrastruktury, i zmigrować z AdGuarda albo zostawić go wyłącznie do blokowania reklam.

Ustalenia, które już zapadły przy Fazie 4:

- **DNS zostaje poza klastrem.** Jeśli mieszka w klastrze, a klaster leży, nie rozwiążesz nazw, żeby go
  zdiagnozować. Cały dom zależy od tego DNS-u. LXC obok klastra to właściwe miejsce.
- **Należy do Terraforma, nie do Argo CD.** DNS to infrastruktura, nie aplikacja. Argo ma pilnować tego,
  co biegnie w klastrze, i tyle.
- **„Dwa DNS-y" już istnieją i to nie problem.** AdGuard obsługuje sieć domową, CoreDNS strefę
  `*.svc.cluster.local` w klastrze. Współistnieją, bo odpowiadają za rozłączne zbiory nazw. Groźne byłyby
  dwa źródła prawdy dla *tych samych* nazw.
- **Wpis wieloznaczny załatwia 90% problemu bez migracji.** `*.k8s.suwalski.internal` na adres węzła sprawia,
  że nowa usługa nie wymaga dotykania DNS-u — resztę rozstrzyga Ingress. Migracja jest ulepszeniem, nie
  warunkiem.
- **Nazewnictwo: zostajemy przy `.internal`.** ICANN zarezerwowało tę końcówkę do użytku prywatnego.
  `.local` jest zajęte przez mDNS i potrafi psuć rozwiązywanie nazw.
- **Haczyk:** `suwalski.internal` to goła domena, więc wpis wieloznaczny `*.k8s.suwalski.internal` jej nie
  obejmuje — strona startowa `k8s.suwalski.internal` ma osobny wpis A w AdGuardzie (→ `192.168.0.119`).

Do rozstrzygnięcia przy realizacji: czy AdGuard ma API nadające się do Terraforma, czy prościej zamienić go
na serwer sterowany plikiem konfiguracyjnym.

## Certyfikaty dla nazw wewnętrznych

Przy końcówce `.internal` **nie da się** dostać certyfikatu z Let's Encrypt — wystawiają tylko dla domen
realnie posiadanych. Dopóki chodzimy po HTTP w sieci domowej, nie ma problemu. Gdyby kiedyś przeszkadzało
ostrzeżenie przeglądarki, są dwie drogi: własne CA dodane do zaufanych na urządzeniach, albo prawdziwa
domena z uwierzytelnianiem DNS-01.

## Czego ta zmiana nie może zepsuć

Na tym hypervisorze stoją rzeczy używane na co dzień. Przejęcie ich przez Terraform oznacza **import
istniejącego stanu**, a nie postawienie od nowa obok — pomyłka tutaj kasuje NAS. To jest główny powód, dla
którego to zadanie wymaga własnej sesji i spokoju. Szczegóły importu maszyny NAS-a:
[`omv-w-kodzie.md`](omv-w-kodzie.md).
