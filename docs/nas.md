# NAS: dysk na dane dla k3s

Dane, które nie mają zajmować NVMe serwera (PostgreSQL, później pliki spraw), leżą na
macierzy OpenMediaVault. Droga od fizycznych dysków do wolumenu w Kubernetesie:

```
2 × SSD 2 TB (SATA, kontroler przekazany do VM 113)
  └─ RAID1 (mdadm, /dev/md0), btrfs                          ← OpenMediaVault
       └─ folder współdzielony „proxmox” (podwolumen btrfs, bez CoW)
            └─ eksport NFS /export/proxmox, tylko dla 192.168.0.111
                 └─ magazyn Proxmoksa „nas”                    ← terraform/cluster
                      └─ dysk scsi1 maszyny k3s, 100 GB, cienki ← terraform/cluster
                           └─ ext4 „nas” w /mnt/nas            ← just cluster nas-disk
                                └─ klasa storage „nas”         ← argocd/apps/platform/nas-storage.yaml
                                     └─ wolumeny aplikacji (PostgreSQL)
```

## Co jest w kodzie, a co nie

| Element | Gdzie |
| --- | --- |
| magazyn `nas`, dysk `scsi1`, kolejność startu k3s (`order=2`) | `terraform/cluster` |
| system plików i montowanie w maszynie | `just cluster nas-disk` (`.just/lib/nas-disk.sh`), powtarzalne |
| klasa storage `nas` | Argo: `argocd/apps/platform/nas-storage.yaml` |
| folder `proxmox` i eksport NFS w OMV | **ręcznie**, opis niżej — OMV nie jest zarządzany kodem |
| kolejność startu OMV (`order=1,up=60`) | **ręcznie**: `ssh pve 'qm set 113 --startup order=1,up=60'` — VM 113 nie jest w Terraformie |

## Ustawienia OMV (zrobione 2.10.2026 przez `omv-rpc`)

- Folder współdzielony `proxmox` na `/dev/md0`, uprawnienia 700.
- `chattr +C` na katalogu folderu: obrazy dysków na btrfs bez copy-on-write, inaczej każdy
  zapis maszyny fragmentuje plik. Pliki tworzone w środku dziedziczą atrybut.
- NFS włączony (wersje 3, 4, 4.1, 4.2). Udział: klient `192.168.0.111/32`, `rw`,
  dodatkowo `sync,no_subtree_check,no_root_squash` — Proxmox zapisuje obrazy jako root.

## Dlaczego tak, a nie NFS w podzie

Postgres dostaje zwykły dysk blokowy z normalną semantyką zapisu; NFS obsługuje Proxmox.
Montowanie NFS wprost w podzie bazy odradza dokumentacja CloudNativePG. SMB (jedyny protokół
włączony wcześniej) nie spełnia wymagań Postgresa w ogóle.

## Uwaga przy zmianach

- **Dysk `scsi1` żyje razem z maszyną k3s.** Odtworzenie maszyny (`destroy`/`replace`
  w planie) usuwa też ten dysk z danymi. Plan pokazuje to w kolumnie „destroy" — to powód,
  żeby się zatrzymać. Kopie poza domem są obowiązkowe przed prawdziwymi danymi.
- **Nowa maszyna:** po `just cluster apply` uruchom `just cluster nas-disk`. Celowo nie ma
  tego w cloud-init: zmiana szablonu cloud-init wymusza postawienie maszyny od nowa.
- **Restart OMV** = przestój aplikacji na NAS-ie (wolumeny czekają, aż NFS wróci).
- Klasa `nas` ma `reclaimPolicy: Retain`: usunięty wolumen zostaje na dysku jako `Released`;
  dane kasuje się świadomie (`kubectl delete pv …` i katalog w `/mnt/nas`).
