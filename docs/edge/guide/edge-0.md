# Warstwa edge — przewodnik

Warstwa `edge` to **wejście z internetu do homelabu**. Dzięki niej aplikacja z k3s jest
dostępna pod `https://witkowska-dev.gugnowski.com`, ale tylko dla osób z listy, i bez otwierania
jakiegokolwiek portu w domowym routerze.

Składa się z trzech kawałków, które leżą w różnych miejscach repo:

| Kawałek | Gdzie | Co robi |
| --- | --- | --- |
| Konfiguracja Cloudflare | `terraform/edge/` | tunel, rekordy DNS, logowanie (Access) |
| Łącznik w klastrze | `argocd/apps/platform/cloudflared.yaml` + `argocd/manifests/cloudflared/` | trzyma tunel od strony domu |
| Sekrety | `scripts/setup.sh` (platforma) + `scripts/projects/…/setup.sh` (projekty) | token API, maile w grupach, token tunelu |

## Jak czytać

Po kolei. Każdy rozdział korzysta tylko z tego, co było wcześniej: najpierw **po co**,
potem **słowa**, potem **jak płynie ruch**, a dopiero na końcu **pliki linijka po
linijce**. Jeśli zaczniesz od plików, zobaczysz nazwy zasobów bez wiedzy, czemu istnieją.

| # | Rozdział | Na jakie pytanie odpowiada | Czas |
| --- | --- | --- | --- |
| 1 | [Problem i wybór rozwiązania](edge-1-problem.md) | Czemu tunel Cloudflare, a nie przekierowanie portu, VPS czy GKE? | 10 min |
| 2 | [Pojęcia](edge-2-pojecia.md) | Co to jest strefa, tunel, connector, Access, aplikacja, reguła, aud? | 15 min |
| 3 | [Droga jednego żądania](edge-3-droga-zadania.md) | Co dokładnie dzieje się od wpisania adresu do odpowiedzi z poda — i który plik steruje którym krokiem? | 15 min |
| 4 | [Wartości i sekrety](edge-4-sekrety.md) | Co jest w gicie, co poza nim i czemu; jak token tunelu trafia do klastra | 10 min |
| 5 | [Pliki Terraforma](edge-5-terraform.md) | Co jest w każdym pliku `terraform/edge/` i czemu napisane jest właśnie tak | 25 min |
| 6 | [cloudflared w klastrze](edge-6-cloudflared.md) | Czemu przez Argo, czemu dwie repliki, co znaczy każda linijka manifestu | 15 min |
| 7 | [Pierwsze uruchomienie](edge-7-uruchomienie.md) | Kroki od zera do działającego logowania, z tym, co powinieneś zobaczyć po każdym | 45 min (robota) |
| 8 | [Codzienna praca](edge-8-codzienna-praca.md) | Jak dodać aplikację, osobę, zaktualizować cloudflared | 10 min |
| 9 | [Diagnostyka](edge-9-diagnostyka.md) | Objaw → przyczyna → gdzie sprawdzić | do wglądu |
| 10 | [Decyzje w pigułce](edge-10-decyzje.md) | Wszystkie „czemu tak, a nie inaczej” w jednej tabeli | 5 min |

Rozdziały 1–6 to rozumienie, 7 to robota przy komputerze, 8–10 to ściąga na później.

## Skąd się wzięła ta warstwa

Pierwszy plan zakładał osobny klaster GKE w Google Cloud z IAP (logowanie Google przed
aplikacją). Wyszło ~90 $ miesięcznie. Plan 2.0 robi to samo na istniejącym k3s za 0 $:
Cloudflare zastępuje Load Balancer i IAP, a tunel zastępuje publiczny adres IP.
Rozdział 1 rozkłada tę decyzję na części.

## Czego ta warstwa NIE robi

- Nie stawia aplikacji. Aplikacja to osobny projekt w `argocd/apps/projects/`
  z własnym Ingressem. Edge tylko wpuszcza do niej ruch.
- Nie zarządza domeną jako taką (rejestracja, poczta). Dotyka wyłącznie rekordów, które
  sama tworzy — każdy ma komentarz „terraform/edge”.
- Nie dotyka klastra. Terraform w `edge/` rozmawia tylko z API Cloudflare.
