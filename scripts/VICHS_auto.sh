#!/bin/bash

# SCRIPT_PATH to miejsce, w którym znajduje się skrypt
SCRIPT_PATH=$(dirname "$(realpath -s "$0")")

# MAIN_PATH to miejsce, w którym znajduje się główny katalog repozytorium
MAIN_PATH="$SCRIPT_PATH"/..

cd $SCRIPT_PATH/..
#$SCRIPT_PATH/ADD_NOVELTIES_FROM_CERT.sh
#$SCRIPT_PATH/ADD_NOVELTIES_FROM_LWS.sh
#$SCRIPT_PATH/ADD_NOVELTIES_FROM_CSMI.sh

if [ -f "./sections/LWS/podejrzane_inne_oszustwa.txt" ]; then
    rm -rf ./sections/podejrzane_inne_oszustwa.txt
    mv ./sections/LWS/podejrzane_inne_oszustwa.txt ./sections/
fi

if [ -f "./sections/CERT/przekrety.txt" ]; then
    rm -rf ./sections/przekrety.txt
    mv ./sections/CERT/przekrety.txt ./sections/
fi

ost_plik=$(git diff --name-only --pretty=format: | sort | uniq)
function search() {
    echo "$ost_plik" | grep "$1"
}

# Lokalizacja pliku konfiguracyjnego
CONFIG=$SCRIPT_PATH/VICHS.config

# Konfiguracja nazwy użytkownika i maila dla CI
if [ "$CI" = "true" ] ; then
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
    git add "$MAIN_PATH"/sections/przekrety.txt
    git commit -m "Nowości z listy CERT"
fi

$SCRIPT_PATH/VICHS.sh ./KAD.txt
cd ..

if [[ "$CI" = "true" ]] && [[ -z "$CIRCLECI" ]] ; then
    git clone https://github.com/PolishFiltersTeam/KADhosts.git
fi
if [[ "$CI" = "true" ]] && [[ "$CIRCLECI" = "true" ]] ; then
    git clone git@github.com:PolishFiltersTeam/KADhosts.git
fi

cd ./KADhosts
./scripts/VICHS.sh ./KADhosts.txt ./KADhole.txt ./KADomains.txt
