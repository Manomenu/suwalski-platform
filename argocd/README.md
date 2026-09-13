# argocd/

Co ma biec w klastrze. Argo CD obserwuje `apps/` i wprowadza zmiany samo — **tu nie
uruchamia się żadnych poleceń**.

```
apps/
└── suwalski-investing-tools.yaml    aplikacja + przypięta wersja obrazu
```

## Jak dodać aplikację

Nowy plik w `apps/`, commit, push. Argo zauważy go w ciągu kilku minut. Nie ma kroku
`apply` i nie powinno być.

## Jak wdrożyć nową wersję

Zmień `image.tag` w pliku aplikacji i wypchnij. To **jedyna** zmiana potrzebna do
wdrożenia — i dlatego `git log` na tym pliku jest historią wdrożeń, a `git revert`
wycofaniem.

Od Fazy 6 robi to CI: buduje obraz, po czym commituje podbicie tej linijki.

## Czemu to repo, a nie repo z kodem

Chart mieszka przy kodzie, bo kształt wdrożenia zmienia się razem z nim. Ale **wersja
jest stanem środowiska**, nie kodu. Gdyby numer leżał w repo z kodem, każdy commit
z kodem byłby wdrożeniem — i znikłaby różnica między „przetestowane" a „uruchomione".
