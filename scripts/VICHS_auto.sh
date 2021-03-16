#!/bin/bash

# SCRIPT_PATH to miejsce, w którym znajduje się skrypt
SCRIPT_PATH=$(dirname "$(realpath -s "$0")")

# MAIN_PATH to miejsce, w którym znajduje się główny katalog repozytorium
MAIN_PATH="$SCRIPT_PATH"/..

cd $SCRIPT_PATH/..
#$SCRIPT_PATH/ADD_NOVELTIES_FROM_CERT.sh
#$SCRIPT_PATH/ADD_NOVELTIES_FROM_LWS.sh
#$SCRIPT_PATH/ADD_NOVELTIES_FROM_CSMI.sh

rm -rf ./sections/podejrzane_inne_oszustwa.txt
mv ./sections/LWS/podejrzane_inne_oszustwa.txt ./sections/

rm -rf ./sections/przekrety.txt
mv ./sections/CERT/przekrety.txt ./sections/

ost_plik=$(git diff --name-only --pretty=format: | sort | uniq)
function search() {
    echo "$ost_plik" | grep "$1"
}
if [[ -n $(search "sections/podejrzane_inne_oszustwa.txt") ]]; then
    git add "$MAIN_PATH"/sections/podejrzane_inne_oszustwa.txt
    git commit -m "Nowości z LWS"
fi
if [[ -n $(search "sections/przekrety.txt") ]]; then
    git add "$MAIN_PATH"/sections/przekrety.txt
    git commit -m "Nowości z listy CERT"
fi
NO_PUSH="true" $SCRIPT_PATH/VICHS.sh ./KAD.txt
cd ..
if [ "$CI" = "true" ] ; then
    git clone https://github.com/PolishFiltersTeam/KADhosts.git
fi
cd ./KADhosts
NO_PUSH="true" ./scripts/VICHS.sh ./KADhosts.txt /KADhole.txt ./KADomains.txt
