#!/bin/bash

# SCRIPT_PATH to miejsce, w którym znajduje się skrypt
SCRIPT_PATH=$(dirname "$(realpath -s "$0")")

# MAIN_PATH to miejsce, w którym znajduje się główny katalog repozytorium
MAIN_PATH=$(git -C "$SCRIPT_PATH" rev-parse --show-toplevel)

TEMP="$MAIN_PATH"/temp

cd "$MAIN_PATH" || exit

if [ -f "./sections/LWS/podejrzane_inne_oszustwa.txt" ]; then
    rm -rf ./sections/podejrzane_inne_oszustwa.txt
    mv ./sections/LWS/podejrzane_inne_oszustwa.txt ./sections/
fi

if [ -f "./sections/LWS/sections/podejrzane_inne_oszustwa.txt" ]; then
    rm -rf ./sections/podejrzane_inne_oszustwa.txt
    mv ./sections/LWS/sections/podejrzane_inne_oszustwa.txt ./sections/
fi

if [ -f "./sections/CERT/przekrety.txt" ]; then
    rm -rf ./sections/przekrety.txt
    mv ./sections/CERT/przekrety.txt ./sections/
fi

if [ -f "./sections/CERT/sections/przekrety.txt" ]; then
    rm -rf ./sections/przekrety.txt
    mv ./sections/CERT/sections/przekrety.txt ./sections/
fi

if [ -f "./scripts/CERT/CERT_offline.txt" ]; then
    rm -rf ./scripts/CERT/CERT_offline.txt
    mv ./scripts/CERT/CERT_offline.txt ./scripts
fi

if [ -f "./sections/CERT/scripts/CERT_offline.txt " ]; then
    rm -rf ./scripts/CERT/CERT_offline.txt
    mv ./sections/CERT/scripts/CERT_offline.txt ./scripts
fi

ost_plik=$(git diff --name-only --pretty=format: | sort | uniq)
function search() {
    echo "$ost_plik" | grep "$1"
}

# Lokalizacja pliku konfiguracyjnego
CONFIG=$SCRIPT_PATH/VICHS.config

# Konfiguracja nazwy użytkownika i maila dla CI
if [ "$CI" = "true" ]; then
    CI_USERNAME=$(grep -oP -m 1 '@CIusername \K.*' "$CONFIG")
    CI_EMAIL=$(grep -oP -m 1 '@CIemail \K.*' "$CONFIG")
    git config --global user.name "${CI_USERNAME}"
    git config --global user.email "${CI_EMAIL}"
fi

if [[ -n $(search "sections/podejrzane_inne_oszustwa.txt") ]]; then
    git add "$MAIN_PATH"/sections/podejrzane_inne_oszustwa.txt
    git commit -m "Nowości z LWS"
fi
if [[ -n $(search "sections/przekrety.txt") ]]; then
    if [[ -n $(search "scripts/CERT_offline.txt") ]]; then
        git add "$SCRIPT_PATH"/CERT_offline.txt
    fi
    git add "$MAIN_PATH"/sections/przekrety.txt
    git commit -m "Nowości z listy CERT"
    # Usuwamy domeny usunięte z CERT
    mkdir -p "$TEMP"
    wget -O "$TEMP"/domains.json https://hole.cert.pl/domains/domains.json
    if [ -f "$TEMP"/domains.json ]; then
        jq '.[] | select(.DeleteDate!=null).DomainAddress' -r "$TEMP"/domains.json > "$TEMP"/CERT_removed.txt
        rm -rf "$TEMP"/domains.json
        sed -i 's/^www\.//g' "$TEMP"/CERT_removed.txt
        sort -u -o "$MAIN_PATH"/sections/przekrety.txt "$MAIN_PATH"/sections/przekrety.txt
        sed -i -r "s|^|\|\||" "$TEMP"/CERT_removed.txt
        sed -i -r 's|$|\^\$all|' "$TEMP"/CERT_removed.txt
        sort -u -o "$TEMP"/CERT_removed.txt "$TEMP"/CERT_removed.txt
        comm -23 "$MAIN_PATH"/sections/przekrety.txt "$TEMP"/CERT_removed.txt > "$TEMP"/LIST.temp
        mv "$TEMP"/LIST.temp "$MAIN_PATH"/sections/przekrety.txt
        rm -rf "$TEMP"/CERT_removed.txt
        sort -uV -o "$MAIN_PATH"/sections/przekrety.txt "$MAIN_PATH"/sections/przekrety.txt
        rm -rf "$TEMP"
    fi
    if [[ -n $(search "sections/przekrety.txt") ]]; then
        git add "$MAIN_PATH"/sections/przekrety.txt
    fi
fi

VICHS.sh ./KAD.txt
cd "$MAIN_PATH"/.. || exit

if [[ "$CI" = "true" ]] && [[ -z "$CIRCLECI" ]]; then
    git clone https://github.com/PolishFiltersTeam/KADhosts.git
fi
if [[ "$CI" = "true" ]] && [[ "$CIRCLECI" = "true" ]]; then
    git clone git@github.com:PolishFiltersTeam/KADhosts.git
fi

cd ./KADhosts || exit
VICHS.sh ./KADhosts.txt ./KADhole.txt ./KADomains.txt
