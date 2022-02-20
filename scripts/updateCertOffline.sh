#!/bin/bash
# SCRIPT_PATH to miejsce, w którym znajduje się skrypt
SCRIPT_PATH=$(dirname "$(realpath -s "$0")")

# MAIN_PATH to miejsce, w którym znajduje się główny katalog repozytorium
MAIN_PATH="$SCRIPT_PATH"/..

TEMP="$MAIN_PATH"/temp

mkdir -p "$TEMP"

cd "$TEMP" || exit
CERT="$TEMP"/CERTHole.temp
wget -O "$CERT" https://hole.cert.pl/domains/domains.txt
expired=$1
sed -i 's/^www\.//g' "$CERT"
sort -u -o "$CERT" "$CERT"
comm -12 "$expired" "$CERT" >> "$SCRIPT_PATH"/CERT_offline.txt
rm -r "$CERT"
sort -u -o "$SCRIPT_PATH"/CERT_offline.txt "$SCRIPT_PATH"/CERT_offline.txt
