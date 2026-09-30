# Wspólne funkcje skryptów setup.sh — platformy i projektów. Sourcowane, nie uruchamiane:
#
#   source "$ROOT/scripts/.internal/lib.sh"
#
# Każdy setup.sh ma ten sam kształt: wczytaj swoje źródło sekretów → zapytaj → zapisz źródło
# → rozprowadź (tfvars, pliki dla edge, Secrety w klastrze). Tu są kroki, które się powtarzają.
#
# Źródła leżą w .secrets/ w korzeniu repo, po pliku na zakres (platform.env,
# automat-operat-prod.env…), poza gitem. Każdy skrypt czyta i pisze WYŁĄCZNIE swój plik.

SECRETS_DIR="$ROOT/.secrets"
declare -gA OBECNE=()

# ── migracja ze starego układu ────────────────────────────────────────────────
# Do niedawna wszystko leżało w jednym .secrets.env. Rozkładamy go raz, przy pierwszym
# uruchomieniu któregokolwiek skryptu: wartości projektu investing-tools do jego pliku,
# reszta do platform.env. Po migracji stary plik znika, więc to się nie powtórzy.
migruj_stary_env() {
    local stary="$ROOT/.secrets.env"
    [ -f "$stary" ] || return 0
    mkdir -p "$SECRETS_DIR" && chmod 700 "$SECRETS_DIR"
    (
        umask 077
        grep -v '^SEC_USER_AGENT=' "$stary" > "$SECRETS_DIR/platform.env"
        {
            echo "# Przeniesione z .secrets.env przez scripts/.internal/lib.sh."
            grep '^SEC_USER_AGENT=' "$stary" || true
        } > "$SECRETS_DIR/suwalski-investing-tools.env"
    )
    rm -f "$stary"
    echo "  migracja: .secrets.env rozłożony na .secrets/platform.env i .secrets/suwalski-investing-tools.env"
}

# ── źródło sekretów ───────────────────────────────────────────────────────────

# wczytaj_zrodlo NAZWA — .secrets/NAZWA.env do tablicy OBECNE
wczytaj_zrodlo() {
    ZRODLO="$SECRETS_DIR/$1.env"
    OBECNE=()
    [ -f "$ZRODLO" ] || return 0
    local k v
    while IFS='=' read -r k v; do
        [[ "$k" =~ ^[A-Z_]+$ ]] || continue
        v="${v%\"}"; OBECNE["$k"]="${v#\"}"
    done < "$ZRODLO"
}

# zapisz_zrodlo KLUCZ… — z tablicy OBECNE do pliku wczytanego przez wczytaj_zrodlo
zapisz_zrodlo() {
    mkdir -p "$SECRETS_DIR" && chmod 700 "$SECRETS_DIR"
    (
        umask 077
        {
            echo "# Generowane przez setup.sh. Poza gitem — jedyne miejsce, w którym te wartości"
            echo "# są wpisane ręcznie. Edytuj przez ponowne uruchomienie skryptu."
            local k
            for k in "$@"; do printf '%s="%s"\n' "$k" "${OBECNE[$k]}"; done
        } > "$ZRODLO"
    )
    echo "  zapisane: ${ZRODLO#"$ROOT"/} (600)"
}

zamaskuj() {
    local v="$1"
    [ ${#v} -le 8 ] && { printf '********'; return; }
    printf '%s…%s' "${v:0:4}" "${v: -4}"
}

# zapytaj NAZWA "opis" [domyślna-jeśli-brak] [cicho]
zapytaj() {
    local nazwa="$1" opis="$2" gdy_brak="${3:-}" cichy="${4:-}" stara="${OBECNE[$1]:-}" nowa=""
    echo
    echo "  $opis"
    if [ -n "$stara" ]; then
        echo "  obecna: $(zamaskuj "$stara")   [Enter = bez zmian]"
    elif [ -n "$gdy_brak" ]; then
        echo "  proponowana: $(zamaskuj "$gdy_brak")   [Enter = przyjmij]"
        stara="$gdy_brak"
    else
        echo "  wymagana — nie była jeszcze podana"
    fi
    if [ -n "$cichy" ]; then
        read -rsp "  > " nowa; echo
    else
        read -rp "  > " nowa
    fi
    if [ -z "$nowa" ]; then
        [ -n "$stara" ] || { echo "  ta wartość jest wymagana" >&2; return 1; }
        nowa="$stara"
    fi
    OBECNE["$nazwa"]="$nowa"
}

# ── grupy dostępu dla terraform/edge ──────────────────────────────────────────

# zapisz_grupe NAZWA "a@x, b@y" — terraform/edge/access/NAZWA.json z listą maili.
# terraform/edge składa grupy ze wszystkich plików w tym katalogu, więc każdy skrypt
# dokłada tylko swoją — kolejność uruchamiania nie ma znaczenia.
zapisz_grupe() {
    local nazwa="$1" plik="$ROOT/terraform/edge/access/$1.json" IFS=',' e json=""
    for e in $2; do
        e="${e//[[:space:]]/}"
        [ -n "$e" ] && json+="${json:+, }\"$e\""
    done
    mkdir -p "$(dirname "$plik")"
    (umask 077 && printf '[%s]\n' "$json" > "$plik")
    echo "  zapisane: ${plik#"$ROOT"/}  (grupa „$nazwa”)"
}

# ── klaster ───────────────────────────────────────────────────────────────────

# klaster_dostepny — ustawia KUBECONFIG na plik tego repo i sprawdza, czy klaster odpowiada.
# Zawsze własny plik, nie KUBECONFIG z powłoki: ten złożony z wielu klastrów celuje w ten,
# który akurat jest wybrany.
klaster_dostepny() {
    export KUBECONFIG="$ROOT/kubeconfig"
    if ! command -v kubectl >/dev/null; then
        echo "  pominięte: brak kubectl"; return 1
    elif [ ! -f "$KUBECONFIG" ]; then
        echo "  pominięte: brak kubeconfiga (just cluster kubeconfig)"; return 1
    elif ! kubectl cluster-info >/dev/null 2>&1; then
        echo "  pominięte: klaster nieosiągalny (jeszcze go nie ma? najpierw: just cluster apply)"; return 1
    fi
}

# secret NAMESPACE NAZWA KLUCZ=WARTOŚĆ… — idempotentnie: tworzy namespace i Secret albo je
# aktualizuje. --dry-run + apply zamiast create, bo samo `create` wywala się, gdy obiekt
# już istnieje. Namespace'y projektów zakłada też Argo (CreateNamespace), ale Secret musi
# mieć gdzie leżeć przed pierwszą synchronizacją.
secret() {
    local ns="$1" nazwa="$2"; shift 2
    local args=() kv
    for kv in "$@"; do args+=(--from-literal="$kv"); done
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    kubectl create secret generic "$nazwa" --namespace "$ns" "${args[@]}" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    echo "  Secret $nazwa w przestrzeni $ns: aktualny"
}

# secret_rejestru NAMESPACE NAZWA SERWER UŻYTKOWNIK TOKEN — Secret typu docker-registry, po
# który sięga imagePullSecrets, gdy obrazy leżą w prywatnym rejestrze (np. GHCR prywatnego
# repo). Idempotentnie, jak `secret`.
secret_rejestru() {
    local ns="$1" nazwa="$2" serwer="$3" uzytkownik="$4" token="$5"
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    kubectl create secret docker-registry "$nazwa" --namespace "$ns" \
        --docker-server="$serwer" --docker-username="$uzytkownik" --docker-password="$token" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    echo "  Secret $nazwa (rejestr $serwer) w przestrzeni $ns: aktualny"
}

# repo_argo NAZWA URL PLIK_KLUCZA — dostęp Argo CD do prywatnego repo po SSH. Argo rozpoznaje
# takie Secrety po etykiecie secret-type=repository i dopasowuje je do Application po `url`,
# więc URL musi być co do znaku taki jak repoURL w argocd/apps/. Klucz to deploy key repo:
# tylko do odczytu i tylko do tego jednego repo.
repo_argo() {
    local nazwa="$1" url="$2" klucz="$3"
    kubectl create secret generic "$nazwa" --namespace argocd \
        --from-literal=type=git --from-literal=url="$url" --from-file=sshPrivateKey="$klucz" \
        --dry-run=client -o yaml \
        | kubectl label --local -f - argocd.argoproj.io/secret-type=repository -o yaml \
        | kubectl apply -f - >/dev/null
    echo "  Secret $nazwa w przestrzeni argocd (repo $url): aktualny"
}
