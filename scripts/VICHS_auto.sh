#!/bin/bash

# Sciezka to miejsce, w którym znajduje się skrypt
sciezka=$(dirname "$0")

cd $sciezka/..
$sciezka/VICHS.sh ./KAD.txt ./KADfake.txt
cd ..
if [ "$CI" = "true" ] ; then
    git clone git@github.com:PolishFiltersTeam/KADhosts.git
fi
cd ./KADhosts
./scripts/VICHS.sh ./KADhosts.txt ./KADhosts_without_controversies.txt ./KADhole.txt ./KADfakeHosts.txt
