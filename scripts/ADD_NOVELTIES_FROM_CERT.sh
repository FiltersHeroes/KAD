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
wget https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt
pcregrep -o1 '^.*?0.0.0.0 (.*)' ./KADhosts.txt >> ./KADhosts_temp.txt
rm -rf ./KADhosts.txt
mv ./KADhosts_temp.txt ./KADhosts.txt
sed -i 's/^www\.//g' ./KADhosts.txt
sed -i 's/^www\.//g' "$CERT"
sort -u -o ./KADhosts.txt ./KADhosts.txt
sort -u -o "$CERT" "$CERT"
comm -13 ./KADhosts.txt "$CERT" >> "$CERT".2
rm -r "$CERT"
rm -r ./KADhosts.txt
mv "$CERT".2 "$TEMP"/CERTHole_temp.txt
sort -u -o "$TEMP"/CERTHole_temp.txt "$TEMP"/CERTHole_temp.txt

EXPIRED="$MAIN_PATH"/temp/CERT_expired.txt

while IFS= read -r domain; do
    hostname=$(host -t ns "${domain}")
    parked=$(echo "${hostname}" | grep -E "parkingcrew.net|parklogic.com|sedoparking.com")
    echo "Checking the status of domains"
    if [[ "${hostname}" =~ "NXDOMAIN" ]] || [ -n "${parked}" ]; then
        echo "$domain" >> "$EXPIRED"
    fi
done <"$TEMP"/CERTHole_temp.txt

if [ -f "$EXPIRED" ]; then
    comm -23 "$TEMP"/CERTHole_temp.txt "$TEMP"/CERT_expired.txt >> "$TEMP"/LIST.temp
    rm -r "$TEMP"/CERTHole_temp.txt
    mv "$TEMP"/LIST.temp "$TEMP"/CERTHole_temp.txt
    rm -r "$TEMP"/CERT_expired.txt
    sort -u -o "$TEMP"/CERTHole_temp.txt "$TEMP"/CERTHole_temp.txt
fi

if [ -f "$SCRIPT_PATH"/CERT_skip.txt ]; then
    sort -u -o "$SCRIPT_PATH"/CERT_skip.txt "$SCRIPT_PATH"/CERT_skip.txt
    comm -23 "$TEMP"/CERTHole_temp.txt "$SCRIPT_PATH"/CERT_skip.txt > "$TEMP"/LIST.temp
    mv "$TEMP"/LIST.temp "$TEMP"/CERTHole_temp.txt
fi

if [ ! -f "$TEMP"/LIST.temp ]; then
    mv "$TEMP"/CERTHole_temp.txt "$TEMP"/LIST.temp
fi

if [ -f "$TEMP"/CERTHole_temp.txt ]; then
    rm -rf "$TEMP"/CERTHole_temp.txt
fi

sed -i '/^$/d' "$TEMP"/LIST.temp
sed -i 's/[[:space:]]*$//' "$TEMP"/LIST.temp
sed -i -r "s|^|\|\||" "$TEMP"/LIST.temp
sed -i -r 's|$|\^\$all|' "$TEMP"/LIST.temp

cat "$TEMP"/LIST.temp >> "$MAIN_PATH"/sections/przekrety.txt

rm -rf "$TEMP"

cd "$MAIN_PATH" || exit

# if [[ $(git diff --stat) != '' ]]; then
#     git add "$MAIN_PATH"/sections/przekrety.txt
#     git commit -m "Nowości z listy CERT"
# fi
