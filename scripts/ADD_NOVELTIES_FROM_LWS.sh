#!/bin/bash
# SCRIPT_PATH to miejsce, w którym znajduje się skrypt
SCRIPT_PATH=$(dirname "$(realpath -s "$0")")

# MAIN_PATH to miejsce, w którym znajduje się główny katalog repozytorium
MAIN_PATH="$SCRIPT_PATH"/..

TEMP="$MAIN_PATH"/temp


# Lokalizacja pliku konfiguracyjnego
CONFIG=$SCRIPT_PATH/VICHS.config

# Konfiguracja nazwy użytkownika i maila dla CI
if [ "$CI" = "true" ] ; then
    CI_USERNAME=$(grep -oP -m 1 '@CIusername \K.*' "$CONFIG")
    CI_EMAIL=$(grep -oP -m 1 '@CIemail \K.*' "$CONFIG")
    git config --global user.name "${CI_USERNAME}"
    git config --global user.email "${CI_EMAIL}"
fi


mkdir -p "$TEMP"

cd "$TEMP" || exit
LWS="$TEMP"/LWSHole.temp
python3 "$SCRIPT_PATH"/findSuspiciousDomains_LWS.py >> "$LWS"
wget https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt
pcregrep -o1 '^.*?0.0.0.0 (.*)' ./KADhosts.txt >> ./KADhosts_temp.txt
rm -rf ./KADhosts.txt
mv ./KADhosts_temp.txt ./KADhosts.txt
sed -i 's/^www\.//g' ./KADhosts.txt
sed -i 's/^www\.//g' "$LWS"
sort -u -o ./KADhosts.txt ./KADhosts.txt
sort -u -o "$LWS" "$LWS"
comm -13 ./KADhosts.txt "$LWS" >> "$TEMP"/LWS_temp.txt
rm -r "$LWS"
rm -r ./KADhosts.txt
sort -u -o "$TEMP"/LWS_temp.txt "$TEMP"/LWS_temp.txt

EXPIRED="$MAIN_PATH"/temp/LWS_expired.txt

while IFS= read -r domain; do
    hostname=$(host -t ns "${domain}")
    parked=$(echo "${hostname}" | grep -E "parkingcrew.net|parklogic.com|sedoparking.com")
    echo "Checking the status of domains"
    if [[ "${hostname}" =~ "NXDOMAIN" ]] || [ ! -z "${parked}" ]; then
        echo "$domain" >> "$EXPIRED"
    fi
done <"$TEMP"/LWS_temp.txt

if [ -f "$EXPIRED" ]; then
    comm -23 "$TEMP"/LWS_temp.txt "$TEMP"/LWS_expired.txt >> "$TEMP"/LIST.temp
    rm -r "$TEMP"/LWS_temp.txt
    mv "$TEMP"/LIST.temp "$TEMP"/LWS_temp.txt
    rm -r "$TEMP"/LWS_expired.txt
    sort -u -o "$TEMP"/LWS_temp.txt "$TEMP"/LWS_temp.txt
fi

if [ -f "$SCRIPT_PATH"/LWS_whitelist.txt ]; then
    sort -u -o "$SCRIPT_PATH"/LWS_whitelist.txt "$SCRIPT_PATH"/LWS_whitelist.txt
    comm -23 "$TEMP"/LWS_temp.txt "$SCRIPT_PATH"/LWS_whitelist.txt > "$TEMP"/LIST.temp
    mv "$TEMP"/LIST.temp "$TEMP"/LWS_temp.txt
fi

if [ ! -f "$TEMP"/LIST.temp ]; then
    mv "$TEMP"/LWS_temp.txt "$TEMP"/LIST.temp
fi

if [ -f "$TEMP"/LWS_temp.txt ]; then
    rm -rf "$TEMP"/LWS_temp.txt
fi

sed -i '/^$/d' "$TEMP"/LIST.temp
sed -i -r "s|^|\|\||" "$TEMP"/LIST.temp
sed -i -r 's|$|\^\$all|' "$TEMP"/LIST.temp

cat "$TEMP"/LIST.temp >> "$MAIN_PATH"/sections/podejrzane_inne_oszustwa.txt

rm -rf "$TEMP"

cd "$MAIN_PATH" || exit

if [[ $(git diff --stat) != '' ]]; then
    git add "$MAIN_PATH"/sections/podejrzane_inne_oszustwa.txt
    git commit -m "Nowości z LWS"
fi
