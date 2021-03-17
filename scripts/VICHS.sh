#!/bin/bash

# VICHS - Version Include Checksum Hosts Sort
# v2.21

# MIT License

# Copyright (c) 2021 Polish Filters Team

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

SCRIPT_PATH=$(dirname "$(realpath -s "$0")")

# MAIN_PATH to miejsce, w którym znajduje się główny katalog repozytorium (zakładamy, że skrypt znajduje się w katalogu o 1 niżej od głównego katalogu repozytorium)
MAIN_PATH="$SCRIPT_PATH"/..

# Tłumaczenie
. gettext.sh
export TEXTDOMAIN="VICHS"
export TEXTDOMAINDIR=$SCRIPT_PATH/locales

# Przejście do katalogu, w którym znajduje się lokalne repozytorium git
cd "$MAIN_PATH" || exit

# Lokalizacja pliku konfiguracyjnego
CONFIG=$SCRIPT_PATH/VICHS.config

# Konfiguracja nazwy użytkownika i maila dla CI
if [ "$CI" = "true" ] ; then
    CI_USERNAME=$(grep -oP -m 1 '@CIusername \K.*' "$CONFIG")
    CI_EMAIL=$(grep -oP -m 1 '@CIemail \K.*' "$CONFIG")
    git config --global user.name "${CI_USERNAME}"
    git config --global user.email "${CI_EMAIL}"
fi

LOCALE=$(grep -oP -m 1 '@lang \K.*' "$CONFIG")

if [ -n "$LOCALE" ]; then
    export LANGUAGE="$LOCALE"
fi

for i in "$@"; do

    function externalCleanup {
        sed -i '/! Checksum/d' "$EXTERNAL_TEMP"
        sed -i '/!#include /d' "$EXTERNAL_TEMP"
        sed -i '/Adblock Plus 2.0/d' "$EXTERNAL_TEMP"
        sed -i '/! Dołączenie listy/d' "$EXTERNAL_TEMP"
        sed -i "s|^!$|!@|g" "$EXTERNAL_TEMP"
        sed -i "s|^! |!@ |g" "$EXTERNAL_TEMP"
    }

    function revertWhenDownloadError {
        if ! wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"; then
            printf "%s\n" "$(gettext "Error during file download")"
            git checkout "$FINAL"
            rm -r "$EXTERNAL_TEMP"
            exit 0
        fi
    }

    function getOrDownloadExternal {
    # Zakładamy, że katalog zawierający inne sklonowane repozytorium znajduje się wyżej niż katalog naszej własnej listy
        if [ -n "$CLONED_EXTERNAL" ]; then
            if [ -f "$MAIN_PATH/../$CLONED_EXTERNAL".txt ]; then
                EXTERNAL_TEMP="$MAIN_PATH/../$CLONED_EXTERNAL".txt
            else
                wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"
                revertWhenDownloadError
            fi
        else
            wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"
            revertWhenDownloadError
        fi
    }

    function convertToHosts() {
        sed -i "s|\$all$||" "$1"
        sed -i "s|[|][|]|0.0.0.0 |" "$1"
        sed -i 's/[\^]//g' "$1"
        sed -i '/[/\*]/d' "$1"
        sed -i -r "/0\.0\.0\.0 [0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]/d" "$1"
        sed -r "/^0\.0\.0\.0 (www\.|www[0-9]\.|www\-|pl\.|pl[0-9]\.)/! s/^0\.0\.0\.0 /0.0.0.0 www./" "$1" > "$1.2"
    }

    function convertToDomains() {
        sed -i "s|\$all$||" "$1"
        sed -i "s|[|][|]||" "$1"
        sed -i 's/[\^]//g' "$1"
        sed -i '/[/\*]/d' "$1"
        sed -r "/^(www\.|www[0-9]\.|www\-|pl\.|pl[0-9]\.|[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9])/! s/^/www./" "$1" > "$1.2"
    }

    function convertToPihole() {
        sed -i "s|\$all$||" "$1"
        sed -i "s|[|][|]|0.0.0.0 |" "$1"
        sed -i 's/[\^]//g' "$1"
        sed -i -r "/0\.0\.0\.0 [0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]/d" "$1"
        sed -r "/^0\.0\.0\.0 (www\.|www[0-9]\.|www\-|pl\.|pl[0-9]\.)/! s/^0\.0\.0\.0 //" "$1" >> "$1.2"
        sed -i '/^0\.0\.0\.0\b/d' "$1.2"
        sed -i 's|\.|\\.|g' "$1.2"
        sed -i 's|^|(^\|\\.)|' "$1.2"
        sed -i "s|$|$|" "$1.2"
        sed -i "s|\*|.*|" "$1.2"
        rm -rf "$1"
        mv "$1.2" "$1"
    }

    # FILTERLIST to nazwa pliku, który chcemy zbudować
    FILTERLIST=$(basename "$i" .txt)

    TEMPLATE=$MAIN_PATH/templates/${FILTERLIST}.template
    FINAL=$i
    FINAL_B=$MAIN_PATH/${FILTERLIST}.backup
    TEMPORARY=$MAIN_PATH/${FILTERLIST}.temp

    # Tworzenie kopii pliku początkowego
    cp -R "$FINAL" "$FINAL_B"

    # Podmienianie zawartości pliku końcowego na zawartość template'u
    cp -R "$TEMPLATE" "$FINAL"

    # Usuwanie DEV z nazwy filtrów
    if [ "$RTM" = "true" ] ; then
        sed -i "s| DEV||g" "$FINAL"
    fi

    # Ustalanie ścieżki do sekcji
    if grep -q "@path" "$FINAL"; then
        SECTIONS_DIR=$MAIN_PATH/$(grep -oP -m 1 '@path \K.*' "$FINAL")
    elif grep -q "@path" "$CONFIG"; then
        SECTIONS_DIR=$MAIN_PATH/$(grep -oP -m 1 '@path \K.*' "$CONFIG")
    else
        SECTIONS_DIR=$MAIN_PATH/sections/$FILTERLIST
    fi

    if [ -d "${SECTIONS_DIR}" ]; then
        # Usuwanie pustych linii z sekcji
        find "${SECTIONS_DIR}" -type f -exec sed -i '/^$/d' {} \;

        # Usuwanie białych znaków z końca linii
        find "${SECTIONS_DIR}" -type f -exec sed -i 's/[[:space:]]*$//' {} \;

        # Sortowanie sekcji
        FOP="${SCRIPT_PATH}"/FOP.py
        if [ -f "$FOP" ]; then
            python3 "${FOP}" --d "${SECTIONS_DIR}"
        fi
        find "${SECTIONS_DIR}" -type f -exec sort -uV -o {} {} \;
    fi

    # Obliczanie ilości sekcji (wystąpień słowa @include w template'cie)
    END=$(grep -o -i '@include' "${TEMPLATE}" | wc -l)

    # Doklejanie sekcji w odpowiednie miejsca
    for (( n=1; n<=END; n++ ))
    do
        SECTION=${SECTIONS_DIR}/$(awk '$1 == "@include" { print $2; exit }' "$FINAL").txt
        EXTERNAL=$(awk '$1 == "@include" { print $2; exit }' "$FINAL")
        EXTERNAL_TEMP="$SECTIONS_DIR"/external.temp
        CLONED_EXTERNAL=$(awk '$1 == "@include" { print $3; exit }' "$FINAL")
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [ -n "$CLONED_EXTERNAL" ]; then
                touch "$SECTIONS_DIR"/external.temp
                cp "$EXTERNAL_TEMP" "$SECTIONS_DIR"/external.temp
                EXTERNAL_TEMP="$SECTIONS_DIR"/external.temp
            fi
            externalCleanup
            sed -i "1s|^|!@ >>>>>>>> $EXTERNAL\n|" "$EXTERNAL_TEMP"
            echo "!@ <<<<<<<< $EXTERNAL" >> "$EXTERNAL_TEMP"
            SECTION="$EXTERNAL_TEMP"
        fi

        sed -e '0,/^@include/!b; /@include/{ r '"${SECTION}"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        if [ -f "$EXTERNAL_TEMP" ]; then
            rm -r "$EXTERNAL_TEMP"
        fi
    done

    # Obliczanie ilości sekcji, w których zostaną zwhitelistowane reguły sieciowe (wystąpień słowa @NWLinclude w template'cie)
    END_NWL=$(grep -o -i '@NWLinclude' "${TEMPLATE}" | wc -l)

    # Doklejanie sekcji w odpowiednie miejsca i zamiana na wyjątki
    for (( n=1; n<=END_NWL; n++ ))
    do
        SECTION=${SECTIONS_DIR}/$(grep -oP -m 1 '@NWLinclude \K.*' "$FINAL").txt
        EXTERNAL=$(awk '$1 == "@NWLinclude" { print $2; exit }' "$FINAL")
        EXTERNAL_TEMP="$SECTIONS_DIR"/external.temp
        CLONED_EXTERNAL=$(awk '$1 == "@NWLinclude" { print $3; exit }' "$FINAL")
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            SECTION="$EXTERNAL_TEMP"
        fi
        grep -o '^||.*^$' "$SECTION" > "$SECTION.temp"
        sed -e '0,/^@NWLinclude/!b; /@NWLinclude/{ r '"${SECTION}.temp"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        sed -i "s|[|][|]|@@|" "$TEMPORARY"
        sed -i 's/[\^]//g' "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        if [[ -f "$EXTERNAL_TEMP" ]] && [[ -z "$CLONED_EXTERNAL" ]]; then
            rm -r "$EXTERNAL_TEMP"
        fi
        rm -r "$SECTION.temp"
    done

    # Obliczanie ilości sekcji, w których zostaną zwhitelistowane reguły sieciowe z wykorzystaniem modyfikatora badfilter (wystąpień słowa @BNWLinclude w template'cie)
    END_BNWL=$(grep -o -i '@BNWLinclude' "${TEMPLATE}" | wc -l)

    # Doklejanie sekcji w odpowiednie miejsca i zamiana na wyjątki
    for (( n=1; n<=END_BNWL; n++ ))
    do
        SECTION=${SECTIONS_DIR}/$(grep -oP -m 1 '@BNWLinclude \K.*' "$FINAL").txt
        EXTERNAL=$(awk '$1 == "@BNWLinclude" { print $2; exit }' "$FINAL")
        EXTERNAL_TEMP="$SECTIONS_DIR"/external.temp
        CLONED_EXTERNAL=$(awk '$1 == "@BNWLinclude" { print $3; exit }' "$FINAL")
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            SECTION="$EXTERNAL_TEMP"
        fi
        grep -o '^||.*^$' "$SECTION" > "$SECTION.temp"
        grep -o '^||.*^$all$' "$SECTION" >> "$SECTION.temp"
        sed -e '0,/^@BNWLinclude/!b; /@BNWLinclude/{ r '"${SECTION}.temp"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        sed -i "s|\$all$|\$all,badfilter|" "$TEMPORARY"
        sed -i "s|\^$|\^\$badfilter|" "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        if [[ -f "$EXTERNAL_TEMP" ]] && [[ -z "$CLONED_EXTERNAL" ]]; then
            rm -r "$EXTERNAL_TEMP"
        fi
        rm -r "$SECTION.temp"
    done

    # Obliczanie ilości sekcji, które zostaną pobrane ze źródeł zewnętrznych i dodane z nich zostaną tylko unikalne elementy
    END_URLU=$(grep -o -i '@URLUinclude' "${TEMPLATE}" | wc -l)

    # Dodawanie unikalnych reguł z zewnętrznych list
    for (( n=1; n<=END_URLU; n++ ))
    do
        EXTERNAL=$(awk '$1 == "@URLUinclude" { print $2; exit }' "$FINAL")
        EXTERNAL_TEMP=$SECTIONS_DIR/external.temp
        CLONED_EXTERNAL=$(awk '$1 == "@URLUinclude" { print $3; exit }' "$FINAL")
        getOrDownloadExternal
        if [ -n "$CLONED_EXTERNAL" ]; then
            touch "$SECTIONS_DIR"/external.temp
            cp "$EXTERNAL_TEMP" "$SECTIONS_DIR"/external.temp
            EXTERNAL_TEMP="$SECTIONS_DIR"/external.temp
        fi
        externalCleanup
        cp -R "$FINAL_B" "$TEMPORARY"
        sed -i "/!@>>>>>>>> ${EXTERNAL//\//\\/}/,/!@<<<<<<<< ${EXTERNAL//\//\\/}/d" "$TEMPORARY"
        sed -i "/!#if/d" "$TEMPORARY"
        sed -i "/!#endif/d" "$TEMPORARY"
        UNIQUE_TEMP=$SECTIONS_DIR/unique_external.temp
        diff "$EXTERNAL_TEMP" "$TEMPORARY" --new-line-format="" --old-line-format="%L" --unchanged-line-format="" > "$UNIQUE_TEMP"
        rm -rf "$EXTERNAL_TEMP"
        cp -R "$UNIQUE_TEMP" "$EXTERNAL_TEMP"
        rm -rf "$UNIQUE_TEMP"
        sed -i "1s|^|!@>>>>>>>> $EXTERNAL\n|" "$EXTERNAL_TEMP"
        echo "!@<<<<<<<< $EXTERNAL" >> "$EXTERNAL_TEMP"
        sed -e '0,/^@URLUinclude/!b; /@URLUinclude/{ r '"$EXTERNAL_TEMP"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        if [ -f "$EXTERNAL_TEMP" ]; then
            rm -r "$EXTERNAL_TEMP"
        fi
    done

    # Obliczanie ilości sekcji, które zostaną pobrane ze źródeł zewnętrznych i połączone z lokalnymi sekcjami
    END_COMBINE=$(grep -o -i '@COMBINEinclude' "${TEMPLATE}" | wc -l)

    # Łączenie lokalnych i zewnętrznych sekcji w jedno oraz doklejanie ich w odpowiednie miejsca
    for (( n=1; n<=END_COMBINE; n++ ))
    do
        LOCAL=${SECTIONS_DIR}/$(awk '$1 == "@COMBINEinclude" { print $2; exit }' "$FINAL").txt
        EXTERNAL=$(awk '$1 == "@COMBINEinclude" { print $3; exit }' "$FINAL")
        SECTIONS_TEMP=${SECTIONS_DIR}/temp/
        mkdir "$SECTIONS_TEMP"
        EXTERNAL_TEMP=${SECTIONS_DIR}/external.temp
        MERGED_TEMP=${SECTIONS_TEMP}/merged-temp.txt
        CLONED_EXTERNAL=$(awk '$1 == "@COMBINEinclude" { print $4; exit }' "$FINAL")
        getOrDownloadExternal
        if [ -n "$CLONED_EXTERNAL" ]; then
            touch "$SECTIONS_DIR"/external.temp
            cp "$EXTERNAL_TEMP" "$SECTIONS_DIR"/external.temp
            EXTERNAL_TEMP=${SECTIONS_DIR}/external.temp
        fi
        externalCleanup
        sort -u -o "$EXTERNAL_TEMP" "$EXTERNAL_TEMP"
        cat "$LOCAL" "$EXTERNAL_TEMP" >> "$MERGED_TEMP"
        if [ -f "$EXTERNAL_TEMP" ]; then
            rm -r "$EXTERNAL_TEMP"
        fi
        if [ -f "$FOP" ]; then
            python3 "${FOP}" --d "${SECTIONS_DIR}"/temp/
        fi
        sort -uV -o "$MERGED_TEMP" "$MERGED_TEMP"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL + $(basename "$LOCAL")\n|" "$MERGED_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL + $(basename "$LOCAL")" >> "$MERGED_TEMP"
        fi
        sed -e '0,/^@COMBINEinclude/!b; /@COMBINEinclude/{ r '"$MERGED_TEMP"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        rm -r "$MERGED_TEMP"
        rm -r "$SECTIONS_TEMP"
    done

    # Obliczanie ilości sekcji/list filtrów, które zostaną przekonwertowane na hosts
    END_HOSTS=$(grep -o -i '@HOSTSinclude' "${TEMPLATE}" | wc -l)

    # Konwertowanie na hosts i doklejanie zawartości sekcji/list filtrów w odpowiednie miejsca
    for (( n=1; n<=END_HOSTS; n++ ))
    do
        HOSTS_FILE=${SECTIONS_DIR}/$(grep -oP -m 1 '@HOSTSinclude \K.*' "$FINAL").txt
        HOSTS_TEMP=$SECTIONS_DIR/hosts.temp
        EXTERNAL=$(awk '$1 == "@HOSTSinclude" { print $2; exit }' "$FINAL")
        EXTERNAL_TEMP="$SECTIONS_DIR"/external.temp
        CLONED_EXTERNAL=$(awk '$1 == "@HOSTSinclude" { print $3; exit }' "$FINAL")
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            HOSTS_FILE="$EXTERNAL_TEMP"
        fi
        grep -o '^||.*^$' "$HOSTS_FILE" > "$HOSTS_TEMP"
        grep -o '^0.0.0.0.*' "$HOSTS_FILE" >> "$HOSTS_TEMP"
        grep -o '^||.*^$all$' "$HOSTS_FILE" >> "$HOSTS_TEMP"
        convertToHosts "$HOSTS_TEMP"
        if [ -f "$HOSTS_TEMP.2" ]
        then
            cat "$HOSTS_TEMP" "$HOSTS_TEMP.2"  > "$HOSTS_TEMP.3"
            mv "$HOSTS_TEMP.3" "$HOSTS_TEMP"
        fi
        sort -uV -o "$HOSTS_TEMP" "$HOSTS_TEMP"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL => hosts\n|" "$HOSTS_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL => hosts" >> "$HOSTS_TEMP"
        fi
        sed -e '0,/^@HOSTSinclude/!b; /@HOSTSinclude/{ r '"$HOSTS_TEMP"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        rm -r "$HOSTS_TEMP"
        mv "$TEMPORARY" "$FINAL"
        if [ -f "$HOSTS_TEMP.2" ]
        then
            rm -r "$HOSTS_TEMP.2"
        fi
        if [[ -f "$EXTERNAL_TEMP" ]] && [[ -z "$CLONED_EXTERNAL" ]]; then
            rm -r "$EXTERNAL_TEMP"
        fi
    done

    # Obliczanie ilości sekcji, które zostaną pobrane ze źródeł zewnętrznych i połączone z lokalnymi sekcjami
    END_HOSTSCOMBINE=$(grep -o -i '@COMBINEHOSTSinclude' "${TEMPLATE}" | wc -l)

    # Łączenie lokalnych i zewnętrznych sekcji w jedno oraz doklejanie ich w odpowiednie miejsca
    for (( n=1; n<=END_HOSTSCOMBINE; n++ ))
    do
        LOCAL=${SECTIONS_DIR}/$(awk '$1 == "@COMBINEHOSTSinclude" { print $2; exit }' "$FINAL").txt
        EXTERNAL=$(awk '$1 == "@COMBINEHOSTSinclude" { print $3; exit }' "$FINAL")
        SECTIONS_TEMP=${SECTIONS_DIR}/temp/
        mkdir "$SECTIONS_TEMP"
        EXTERNAL_TEMP=${SECTIONS_DIR}/external.temp
        EXTERNALHOSTS_TEMP=$SECTIONS_DIR/external_hosts.temp
        MERGED_TEMP=${SECTIONS_TEMP}/merged-temp.txt
        CLONED_EXTERNAL=$(awk '$1 == "@COMBINEHOSTSinclude" { print $4; exit }' "$FINAL")
        getOrDownloadExternal
        if [ -n "$CLONED_EXTERNAL" ]; then
            touch "${SECTIONS_DIR}"/external.temp
            cp "$EXTERNAL_TEMP" "${SECTIONS_DIR}"/external.temp
            EXTERNAL_TEMP=${SECTIONS_DIR}/external.temp
        fi
        externalCleanup
        sort -u -o "$EXTERNAL_TEMP" "$EXTERNAL_TEMP"
        grep -o '^||.*^$' "$EXTERNAL_TEMP" > "$EXTERNALHOSTS_TEMP"
        grep -o '^||.*^$all$' "$EXTERNAL_TEMP" >> "$EXTERNALHOSTS_TEMP"
        convertToHosts "$EXTERNALHOSTS_TEMP"
        if [ -f "$EXTERNALHOSTS_TEMP.2" ]
        then
            cat "$EXTERNALHOSTS_TEMP" "$EXTERNALHOSTS_TEMP.2"  > "$EXTERNALHOSTS_TEMP.3"
            mv "$EXTERNALHOSTS_TEMP.3" "$EXTERNALHOSTS_TEMP"
        fi
        HOSTS_TEMP=$SECTIONS_DIR/hosts.temp
        grep -o '^||.*^$' "$LOCAL" > "$HOSTS_TEMP"
        grep -o '^0.0.0.0.*' "$LOCAL" >> "$HOSTS_TEMP"
        grep -o '^||.*^$all$' "$LOCAL" >> "$HOSTS_TEMP"
        convertToHosts "$HOSTS_TEMP"
        if [ -f "$HOSTS_TEMP.2" ]
        then
            cat "$HOSTS_TEMP" "$HOSTS_TEMP.2"  > "$HOSTS_TEMP.3"
            mv "$HOSTS_TEMP.3" "$HOSTS_TEMP"
        fi
        cat "$HOSTS_TEMP" "$EXTERNALHOSTS_TEMP" >> "$MERGED_TEMP"
        if [ -f "$EXTERNAL_TEMP" ]; then
            rm -r "$EXTERNAL_TEMP"
        fi
        rm -r "$EXTERNALHOSTS_TEMP"
        if [ -f "$FOP" ]; then
            python3 "${FOP}" --d "${SECTIONS_DIR}"/temp/
        fi
        sort -uV -o "$MERGED_TEMP" "$MERGED_TEMP"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL + $(basename "$LOCAL") => hosts\n|" "$MERGED_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL + $(basename "$LOCAL") => hosts" >> "$MERGED_TEMP"
        fi
        sed -e '0,/^@COMBINEHOSTSinclude/!b; /@COMBINEHOSTSinclude/{ r '"$MERGED_TEMP"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        rm -r "$MERGED_TEMP"
        rm -r "$SECTIONS_TEMP"
        if [ -f "$EXTERNALHOSTS_TEMP.2" ]
        then
            rm -r "$EXTERNALHOSTS_TEMP.2"
        fi
        rm -r "$HOSTS_TEMP"
        if [ -f "$HOSTS_TEMP.2" ]
        then
            rm -r "$HOSTS_TEMP.2"
        fi
    done

    # Obliczanie ilości sekcji/list filtrów, które zostaną przekonwertowane na format domenowy
    END_DOMAINS=$(grep -o -i '@DOMAINSinclude' "${TEMPLATE}" | wc -l)

    # Konwertowanie na domeny i doklejanie zawartości sekcji/list filtrów w odpowiednie miejsca
    for (( n=1; n<=END_DOMAINS; n++ ))
    do
        DOMAINS_FILE=${SECTIONS_DIR}/$(grep -oP -m 1 '@DOMAINSinclude \K.*' "$FINAL").txt
        DOMAINS_TEMP=$SECTIONS_DIR/domains.temp
        EXTERNAL=$(awk '$1 == "@DOMAINSinclude" { print $2; exit }' "$FINAL")
        EXTERNAL_TEMP=$SECTIONS_DIR/external.temp
        EXTERNALDOMAINS_TEMP=$SECTIONS_DIR/external_DOMAINS.temp
        CLONED_EXTERNAL=$(awk '$1 == "@DOMAINSinclude" { print $3; exit }' "$FINAL")
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            DOMAINS_FILE="$EXTERNAL_TEMP"
        fi
        grep -o '^||.*^$' "$DOMAINS_FILE" > "$DOMAINS_TEMP"
        grep -o '^0.0.0.0.*' "$DOMAINS_FILE" >> "$DOMAINS_TEMP"
        grep -o '^||.*^$all$' "$DOMAINS_FILE" >> "$DOMAINS_TEMP"
        convertToDomains "$DOMAINS_TEMP"
        if [ -f "$DOMAINS_TEMP.2" ]
        then
            cat "$DOMAINS_TEMP" "$DOMAINS_TEMP.2"  > "$DOMAINS_TEMP.3"
            mv "$DOMAINS_TEMP.3" "$DOMAINS_TEMP"
        fi
        sort -uV -o "$DOMAINS_TEMP" "$DOMAINS_TEMP"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL => domains\n|" "$DOMAINS_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL => domains" >> "$DOMAINS_TEMP"
        fi
        sed -e '0,/^@DOMAINSinclude/!b; /@DOMAINSinclude/{ r '"$DOMAINS_TEMP"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        rm -r "$DOMAINS_TEMP"
        mv "$TEMPORARY" "$FINAL"
        if [ -f "$DOMAINS_TEMP.2" ]
        then
            rm -r "$DOMAINS_TEMP.2"
        fi
        if [[ -f "$EXTERNAL_TEMP" ]] && [[ -z "$CLONED_EXTERNAL" ]]; then
            rm -r "$EXTERNAL_TEMP"
        fi
    done

    # Obliczanie ilości sekcji, które zostaną pobrane ze źródeł zewnętrznych i połączone z lokalnymi sekcjami
    END_DOMAINSCOMBINE=$(grep -o -i '@COMBINEDOMAINSinclude' "${TEMPLATE}" | wc -l)

    # Łączenie lokalnych i zewnętrznych sekcji w jedno oraz doklejanie ich w odpowiednie miejsca
    for (( n=1; n<=END_DOMAINSCOMBINE; n++ ))
    do
        LOCAL=${SECTIONS_DIR}/$(awk '$1 == "@COMBINEDOMAINSinclude" { print $2; exit }' "$FINAL").txt
        EXTERNAL=$(awk '$1 == "@COMBINEDOMAINSinclude" { print $3; exit }' "$FINAL")
        SECTIONS_TEMP=${SECTIONS_DIR}/temp/
        mkdir "$SECTIONS_TEMP"
        EXTERNAL_TEMP=${SECTIONS_DIR}/external.temp
        EXTERNALDOMAINS_TEMP=$SECTIONS_DIR/external_DOMAINS.temp
        MERGED_TEMP=${SECTIONS_TEMP}/merged-temp.txt
        CLONED_EXTERNAL=$(awk '$1 == "@COMBINEDOMAINSinclude" { print $4; exit }' "$FINAL")
        getOrDownloadExternal
        if [ -n "$CLONED_EXTERNAL" ]; then
            touch "${SECTIONS_DIR}"/external.temp
            cp "$EXTERNAL_TEMP" "${SECTIONS_DIR}"/external.temp
            EXTERNAL_TEMP=${SECTIONS_DIR}/external.temp
        fi
        externalCleanup
        sort -u -o "$EXTERNAL_TEMP" "$EXTERNAL_TEMP"
        grep -o '^||.*^$' "$EXTERNAL_TEMP" > "$EXTERNALDOMAINS_TEMP"
        grep -o '^||.*^$all$' "$EXTERNAL_TEMP" >> "$EXTERNALDOMAINS_TEMP"
        convertToDomains "$EXTERNALDOMAINS_TEMP"
        if [ -f "$EXTERNALDOMAINS_TEMP.2" ]
        then
            cat "$EXTERNALDOMAINS_TEMP" "$EXTERNALDOMAINS_TEMP.2"  > "$EXTERNALDOMAINS_TEMP.3"
            mv "$EXTERNALDOMAINS_TEMP.3" "$EXTERNALDOMAINS_TEMP"
        fi
        DOMAINS_TEMP=$SECTIONS_DIR/DOMAINS.temp
        grep -o '^||.*^$' "$LOCAL" > "$DOMAINS_TEMP"
        grep -o '^||.*^$all$' "$LOCAL" >> "$DOMAINS_TEMP"
        convertToDomains "$DOMAINS_TEMP"
        if [ -f "$DOMAINS_TEMP.2" ]
        then
            cat "$DOMAINS_TEMP" "$DOMAINS_TEMP.2"  > "$DOMAINS_TEMP.3"
            mv "$DOMAINS_TEMP.3" "$DOMAINS_TEMP"
        fi
        cat "$DOMAINS_TEMP" "$EXTERNALDOMAINS_TEMP" >> "$MERGED_TEMP"
        rm -r "$EXTERNALDOMAINS_TEMP"
        if [ -f "$EXTERNAL_TEMP" ]; then
            rm -r "$EXTERNAL_TEMP"
        fi
        if [ -f "$FOP" ]; then
            python3 "${FOP}" --d "${SECTIONS_DIR}"/temp/
        fi
        sort -uV -o "$MERGED_TEMP" "$MERGED_TEMP"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL + $(basename "$LOCAL") => domains\n|" "$MERGED_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL + $(basename "$LOCAL") => domains" >> "$MERGED_TEMP"
        fi
        sed -e '0,/^@COMBINEDOMAINSinclude/!b; /@COMBINEDOMAINSinclude/{ r '"$MERGED_TEMP"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        rm -r "$MERGED_TEMP"
        rm -r "$SECTIONS_TEMP"
        if [ -f "$EXTERNALDOMAINS_TEMP.2" ]
        then
            rm -r "$EXTERNALDOMAINS_TEMP.2"
        fi
        rm -r "$DOMAINS_TEMP"
        if [ -f "$DOMAINS_TEMP.2" ]
        then
            rm -r "$DOMAINS_TEMP.2"
        fi
    done

    # Obliczanie ilości sekcji/list filtrów, z których zostanie wyodrębnionych część reguł (jedynie reguły zawierajace gwiazdki) w celu konwersji na format regex zgodny z PiHole
    END_PH=$(grep -E -o -i '@PHinclude' "${TEMPLATE}" | wc -l)

    # Konwertowanie na format regex zgodny z PiHole i doklejanie zawartości sekcji/list filtrów w odpowiednie miejsca
    for (( n=1; n<=END_PH; n++ ))
    do
        PH_FILE=${SECTIONS_DIR}/$(grep -oP -m 1 '@PHinclude \K.*' "$FINAL").txt
        PH_TEMP=$SECTIONS_DIR/ph.temp
        EXTERNAL=$(awk '$1 == "@PHinclude" { print $2; exit }' "$FINAL")
        EXTERNAL_TEMP=$SECTIONS_DIR/external.temp
        CLONED_EXTERNAL=$(awk '$1 == "@PHinclude" { print $3; exit }' "$FINAL")
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            PH_FILE="$EXTERNAL_TEMP"
        fi
        grep -o '^||.*\*.*^$' "$PH_FILE" > "$PH_TEMP"
        grep -o '^||.*\*.*^$all$' "$PH_FILE" > "$PH_TEMP"
        convertToPihole "$PH_TEMP"
        sort -uV -o "$PH_TEMP" "$PH_TEMP"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL => Pi-hole RegEx\n|"  "$PH_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL => Pi-hole RegEx" >>  "$PH_TEMP"
        fi
        sed -e '0,/^@PHinclude/!b; /@PHinclude/{ r '"$PH_TEMP"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        rm -r "$PH_TEMP"
        mv "$TEMPORARY" "$FINAL"
        if [[ -f "$EXTERNAL_TEMP" ]] && [[ -z "$CLONED_EXTERNAL" ]]; then
            rm -r "$EXTERNAL_TEMP"
        fi
    done

    # Obliczanie ilości sekcji, które zostaną pobrane ze źródeł zewnętrznych, skonwerterowane na format regex zgodny z Pi-hole (jedynie reguły zawierajace gwiazdki) i połączone z lokalnymi sekcjami
    END_PHCOMBINE=$(grep -o -i '@PHCOMBINEinclude' "${TEMPLATE}" | wc -l)

    # Konwertowanie na format regex zgodny z PiHole oraz łączenie lokalnych i zewnętrznych sekcji w jedno oraz doklejanie ich w odpowiednie miejsca
    for (( n=1; n<=END_PHCOMBINE; n++ ))
    do
        LOCAL=${SECTIONS_DIR}/$(awk '$1 == "@PHCOMBINEinclude" { print $2; exit }' "$FINAL").txt
        EXTERNAL=$(awk '$1 == "@PHCOMBINEinclude" { print $3; exit }' "$FINAL")
        SECTIONS_TEMP=${SECTIONS_DIR}/temp/
        mkdir "$SECTIONS_TEMP"
        EXTERNAL_TEMP=${SECTIONS_DIR}/external.temp
        EXTERNALPH_TEMP=$SECTIONS_DIR/external_ph.temp
        MERGED_TEMP=${SECTIONS_TEMP}/merged-temp.txt
        CLONED_EXTERNAL=$(awk '$1 == "@PHCOMBINEinclude" { print $4; exit }' "$FINAL")
        getOrDownloadExternal
        if [ -n "$CLONED_EXTERNAL" ]; then
            touch "${SECTIONS_DIR}"/external.temp
            cp "$EXTERNAL_TEMP" "${SECTIONS_DIR}"/external.temp
            EXTERNAL_TEMP=${SECTIONS_DIR}/external.temp
        fi
        externalCleanup
        sort -u -o "$EXTERNAL_TEMP" "$EXTERNAL_TEMP"
        grep -o '\||.*\*.*^$' "$EXTERNAL_TEMP" > "$EXTERNALPH_TEMP"
        grep -o '\||.*\*.*^$all$' "$EXTERNAL_TEMP" >> "$EXTERNALPH_TEMP"
        convertToPihole "$EXTERNALPH_TEMP"
        cat "$LOCAL" "$EXTERNALPH_TEMP" >> "$MERGED_TEMP"
        if [ -f "$EXTERNAL_TEMP" ]; then
            rm -r "$EXTERNAL_TEMP"
        fi
        rm -r "$EXTERNALPH_TEMP"
        if [ -f "$FOP" ]; then
            python3 "${FOP}" --d "${SECTIONS_DIR}"/temp/
        fi
        sort -uV -o "$MERGED_TEMP" "$MERGED_TEMP"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL + $(basename "$LOCAL") => Pi-hole RegEx\n|" "$MERGED_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL + $(basename "$LOCAL") => Pi-hole RegEx" >> "$MERGED_TEMP"
        fi
        sed -e '0,/^@PHCOMBINEinclude/!b; /@PHCOMBINEinclude/{ r '"$MERGED_TEMP"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        rm -r "$MERGED_TEMP"
        rm -r "$SECTIONS_TEMP"
    done

    # Usuwanie instrukcji informującej o ścieżce do sekcji
    sed -i '/@path /d' "$FINAL"

    # Przejście do katalogu, w którym znajduje się lokalne repozytorium git
    cd "$MAIN_PATH" || exit

    # Ustawianie nazwy kodowej (krótszej nazwy listy filtrów) do opisu commita w zależności od tego, co jest wpisane w polu „Codename:". Jeśli nie ma takiego pola, to codename=nazwa_pliku.
    if grep -q "! Codename" "$i"; then
        filter=$(grep -oP -m 1 '! Codename: \K.*' "$i");
    else
        filter=$(basename "$i" .txt);
    fi

    # Dodawanie zmienionych sekcji do repozytorium git
    if [ ! "$RTM" ] ; then
        git add "$SECTIONS_DIR"/*
        git commit -m "$(gettext "Update sections")" -m "[ci skip]"
    fi

    # Ustawienie strefy czasowej
    TIMEZONE=$(grep -oP -m 1 '@tz \K.*' "$CONFIG")
    if  [ -n "$TIMEZONE" ]; then
        export TZ="$TIMEZONE"
    fi

    # Obliczanie starej i nowej sumy kontrolnej md5 bez komentarzy
    sed -i '/^! /d' "$FINAL_B"
    sed -i '/^# /d' "$FINAL_B"
    cp "$FINAL" "$FINAL_B.new"
    sed -i '/^! /d' "$FINAL_B.new"
    sed -i '/^# /d' "$FINAL_B.new"
    old_md5=$(md5sum "$FINAL_B" | cut -d ' ' -f 1)
    new_md5=$(md5sum "$FINAL_B.new" | cut -d ' ' -f 1)

    # Usuwanie kopii pliku początkowego
    if [ -f "$FINAL_B" ]; then
         rm -r "$FINAL_B"
    fi

    if [ -f "$FINAL_B.new" ]; then
         rm -r "$FINAL_B.new"
    fi

    # Sprawdzanie czy aktualizacja naprawdę jest konieczna
    if [ "$old_md5" != "$new_md5" ] || [ "$FORCED" ]; then
        # Aktualizacja daty i godziny w polu „Last modified"
        if grep -q '@modified' "$i"; then
            export LC_TIME="en_US.UTF-8"
            modified=$(date +"$(grep -oP -m 1 '@dateFormat \K.*' "$CONFIG")")
            sed -i "s|@modified|$modified|g" "$i"
        fi

        # Aktualizacja wersji
        VERSION_FORMAT=$(grep -oP -m 1 '@versionFormat \K.*' "$CONFIG")
        if [[ "$VERSION_FORMAT" = "Year.Month.NumberOfCommitsInMonth" ]] ; then
            version=$(date +"%Y").$(date +"%-m").$(git rev-list --count HEAD --after="$(date -d "-$(date +%d) days " "+%Y-%m-%dT23:59")" "$FINAL")
        elif [[ "$VERSION_FORMAT" = "Year.Month.Day.TodayNumberOfCommits" ]] ; then
            version=$(date +"%Y").$(date +"%-m").$(date +"%-d").$(( $(git rev-list --count HEAD --before="$(date '+%F' --date="tomorrow")"T24:00 --after="$(date '+%F' -d "1 day ago")"T23:59 "$FINAL")))
        elif grep -q -oP -m 1 '@versionDateFormat \K.*' "$CONFIG"; then
            version=$(date +"$(grep -oP -m 1 '@versionDateFormat \K.*' "$CONFIG")")
        else
            version=$(date +"%Y%m%d%H%M")
        fi

        if grep -q '@version' "$i"; then
            sed -i "s|@version|$version|g" "$i"
        fi

        # Aktualizacja pola „aktualizacja"
        if grep -q '@aktualizacja' "$i"; then
            export LC_TIME="pl_PL.UTF-8"
            aktualizacja=$(date +"$(grep -oP -m 1 '@dateFormat \K.*' "$CONFIG")")
            sed -i "s|@aktualizacja|$aktualizacja|g" "$i"
        fi

        # Aktualizacja sumy kontrolnej
        # Założenie: kodowanie UTF-8 i styl końca linii Unix
        # Usuwanie starej sumy kontrolnej i pustych linii
        grep -v '! Checksum: ' "$i" | grep -v '^$' > "$i".chk
        # Pobieranie sumy kontrolnej... Binarny MD5 zakodowany w Base64
        checksum=$(openssl dgst -md5 -binary "$i".chk | openssl enc -base64 | cut -d "=" -f 1)
        # Zamiana atrapy sumy kontrolnej na prawdziwą
        sed -i "/! Checksum: /c\! Checksum: $checksum" "$i"
        rm -r "$i".chk

        # Dodawanie zmienionych plików do repozytorium git
        git add "$i"

        # Commitowanie zmienionych plików
        if [ "$CI" = "true" ] ; then
            commit_desc=$(grep -oP -m 1 '@commitDesc \K.*' "$CONFIG")
            git commit -m "$(eval_gettext "Update \$filter to version \$version")" -m "[ci skip]" -m "${commit_desc}"
        else
            printf "%s" "$(eval_gettext "Enter extended commit description to \$filter list, e.g 'Fix #1, fix #2' (without quotation marks; if you do not want an extended description, you can simply enter nothing): ")"
            read -r extended_desc
            git commit -m "$(eval_gettext "Update \$filter to version \$version")" -m "[ci skip]" -m "${extended_desc}"
        fi
    else
        printf "%s\n" "$(eval_gettext "Nothing new has been added to \$filter list. If you still want to update it, then set the variable FORCED and run script again.")"
        git checkout "$FINAL"
    fi
done

# Wysyłanie zmienionych plików do repozytorium git
commited=$(git cherry -v)
if [[ "$commited" ]] && [[ "$NO_PUSH" != "true" ]]; then
    if [ "$CI" = "true" ] ; then
        GIT_SLUG=$(git ls-remote --get-url | sed "s|https://||g" | sed "s|git@||g" | sed "s|:|/|g")
        git push https://"${CI_USERNAME}":"${GIT_TOKEN}"@"${GIT_SLUG}" > /dev/null 2>&1
    else
        printf "%s\n" "$(gettext "Do you want to send changed files to git now?")"
        select yn in $(gettext "Yes") $(gettext "No"); do
            case $yn in
                        "$(gettext "Yes")" )
                        git push
                        break;;
                        "$(gettext "No")" ) break;;
            esac
        done
    fi
fi
