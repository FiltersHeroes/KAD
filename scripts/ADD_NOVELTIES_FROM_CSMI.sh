#!/bin/bash
# SCRIPT_PATH to miejsce, w którym znajduje się skrypt
SCRIPT_PATH=$(dirname "$(realpath -s "$0")")

# MAIN_PATH to miejsce, w którym znajduje się główny katalog repozytorium
MAIN_PATH="$SCRIPT_PATH"/..

TEMP="$MAIN_PATH"/temp

mkdir -p "$TEMP"

cd "$TEMP" || exit
CSMI="$TEMP"/CSMIHole.temp
wget -O "$CSMI" https://gist.githubusercontent.com/krystian3w/ade69eb7b4c15c5afe2aae02301da43c/raw/cs-info-domains.txt
wget https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt
pcregrep -o1 '^.*?0.0.0.0 (.*)' ./KADhosts.txt >> ./KADhosts_temp.txt
rm -rf ./KADhosts.txt
mv ./KADhosts_temp.txt ./KADhosts.txt
sed -i 's/^www\.//g' ./KADhosts.txt
sed -i 's/^www\.//g' "$CSMI"
sort -u -o ./KADhosts.txt ./KADhosts.txt
sort -u -o "$CSMI" "$CSMI"
comm -13 ./KADhosts.txt "$CSMI" >> "$CSMI".2
rm -r "$CSMI"
rm -r ./KADhosts.txt
mv "$CSMI".2 "$TEMP"/CSMIHole_temp.txt
sort -u -o "$TEMP"/CSMIHole_temp.txt "$TEMP"/CSMIHole_temp.txt

EXPIRED="$MAIN_PATH"/temp/CSMI_expired.txt

while IFS= read -r domain; do
    hostname=$(host -t ns "${domain}")
    parked=$(echo "${hostname}" | grep -E "parkingcrew.net|parklogic.com|sedoparking.com")
    echo "Checking the status of domains"
    if [[ "${hostname}" =~ "NXDOMAIN" ]] || [ ! -z "${parked}" ]; then
        echo "$domain" >> "$EXPIRED"
    fi
done <"$TEMP"/CSMIHole_temp.txt

if [ -f "$EXPIRED" ]; then
    comm -23 "$TEMP"/CSMIHole_temp.txt "$TEMP"/CSMI_expired.txt >> "$TEMP"/LIST.temp
    rm -r "$TEMP"/CSMIHole_temp.txt
    mv "$TEMP"/LIST.temp "$TEMP"/CSMIHole_temp.txt
    rm -r "$TEMP"/CSMI_expired.txt
    sort -u -o "$TEMP"/CSMIHole_temp.txt "$TEMP"/CSMIHole_temp.txt
fi

if [ -f "$SCRIPT_PATH"/CSMI_whitelist.txt ]; then
    sort -u -o "$SCRIPT_PATH"/CSMI_whitelist.txt "$SCRIPT_PATH"/CSMI_whitelist.txt
    comm -23 "$TEMP"/CSMIHole_temp.txt "$SCRIPT_PATH"/CSMI_whitelist.txt > "$TEMP"/LIST.temp
    mv "$TEMP"/LIST.temp "$TEMP"/CSMIHole_temp.txt
fi

if [ ! -f "$TEMP"/LIST.temp ]; then
    mv "$TEMP"/CSMIHole_temp.txt "$TEMP"/LIST.temp
fi

if [ -f "$TEMP"/CSMIHole_temp.txt ]; then
    rm -rf "$TEMP"/CSMIHole_temp.txt
fi

sed -i '/^$/d' "$TEMP"/LIST.temp
sed -i 's/[[:space:]]*$//' "$TEMP"/LIST.temp
sed -i -r "s|^|\|\||" "$TEMP"/LIST.temp
sed -i -r 's|$|\^\$all|' "$TEMP"/LIST.temp

cat "$TEMP"/LIST.temp >> "$MAIN_PATH"/sections/przekrety.txt

rm -rf "$TEMP"

cd "$MAIN_PATH" || exit
