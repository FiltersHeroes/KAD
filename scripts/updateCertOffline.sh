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
wget https://raw.githubusercontent.com/FiltersHeroes/KADhosts/master/KADhosts.txt
pcregrep -o1 '^.*?0.0.0.0 (.*)' ./KADhosts.txt >>./KADhosts_temp.txt
rm -rf ./KADhosts.txt
mv ./KADhosts_temp.txt ./KADhosts.txt
sed -i 's/^www\.//g' ./KADhosts.txt
sed -i 's/^www\.//g' "$CERT"
sort -u -o ./KADhosts.txt ./KADhosts.txt
sort -u -o "$CERT" "$CERT"
comm -13 ./KADhosts.txt "$CERT" >>"$CERT".2
rm -r "$CERT"
rm -r ./KADhosts.txt
mv "$CERT".2 "$TEMP"/CERTHole_temp.txt
sort -u -o "$TEMP"/CERTHole_temp.txt "$TEMP"/CERTHole_temp.txt

OFFLINE="$SCRIPT_PATH"/CERT_offline.txt

if [ -f "$OFFLINE" ] && [ "$SKIP_OFFLINE" == "true" ]; then
    sort -u -o "$OFFLINE" "$OFFLINE"
    comm -23 "$TEMP"/CERTHole_temp.txt "$OFFLINE" >"$CERT".2
    mv "$CERT".2 "$TEMP"/CERTHole_temp.txt
    sort -u -o "$TEMP"/CERTHole_temp.txt "$TEMP"/CERTHole_temp.txt
fi

CERT_SKIP="$SCRIPT_PATH"/CERT_skip.txt

if [ -f "$CERT_SKIP" ]; then
    sort -u -o "$CERT_SKIP" "$CERT_SKIP"
    comm -23 "$TEMP"/CERTHole_temp.txt "$CERT_SKIP" >"$CERT".2
    mv "$CERT".2 "$TEMP"/CERTHole_temp.txt
    sort -u -o "$TEMP"/CERTHole_temp.txt "$TEMP"/CERTHole_temp.txt
fi

EXPIRED="$MAIN_PATH"/temp/CERT_expired.txt

while IFS= read -r domain; do
    hostname=$(host -t ns "${domain}")
    parked=$(echo "${hostname}" | grep -E "parkingcrew.net|parklogic.com|sedoparking.com")
    echo "Checking the status of domains"
    if [[ "${hostname}" =~ "NXDOMAIN" ]] || [ -n "${parked}" ]; then
        echo "$domain" >>"$EXPIRED"
    fi
done <"$TEMP"/CERTHole_temp.txt

if [ -f "$EXPIRED" ]; then
    if [ -f "$OFFLINE" ]; then
        rm -rf "$OFFLINE"
    fi
    cp "$EXPIRED" "$OFFLINE"
fi

if [ -f "$TEMP"/CERTHole_temp.txt ]; then
    rm -rf "$TEMP"/CERTHole_temp.txt
fi

rm -rf "$TEMP"

cd "$MAIN_PATH" || exit


ost_plik=$(git diff --name-only --pretty=format: | sort | uniq)
function search() {
    echo "$ost_plik" | grep "$1"
}

CI_USERNAME="github-actions[bot]"
CI_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"

git config --global user.name "${CI_USERNAME}"
git config --global user.email "${CI_EMAIL}"

if [[ -n $(search "$OFFLINE") ]]; then
    git add "$OFFLINE"
    git commit -m "Aktualizacja CERT_offline.txt"
    GIT_SLUG=$(git ls-remote --get-url | sed "s|https://||g" | sed "s|git@||g" | sed "s|:|/|g")
    git push https://"${CI_USERNAME}":"${GIT_TOKEN}"@"${GIT_SLUG}" >/dev/null 2>&1
fi
