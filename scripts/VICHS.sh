#!/bin/bash

# VICHS - Version Include Checksum Hosts Sort
# v2.26.1

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

#
#

SCRIPT_PATH=$(dirname "$(realpath -s "$0")")

# MAIN_PATH to miejsce, w którym znajduje się główny katalog repozytorium
# Zakładamy, że skrypt znajduje się gdzieś w repozytorium git,
# w którym są pliki listy filtrów, którą chcemy zaktualizować.
# Jednakże jeżeli skrypt znajduje się gdzieś indziej, to
# zezwalamy na nadpisanie zmiennej MAIN_PATH.
if [ -z "$MAIN_PATH" ]; then
    MAIN_PATH=$(git -C "$SCRIPT_PATH" rev-parse --show-toplevel)
fi

# Tłumaczenie
# shellcheck disable=SC1091
. gettext.sh
export TEXTDOMAIN="VICHS"
export TEXTDOMAINDIR=$SCRIPT_PATH/locales

# Przejście do katalogu, w którym znajduje się lokalne repozytorium git
cd "$MAIN_PATH" || exit

# Lokalizacja pliku konfiguracyjnego
CONFIG=$SCRIPT_PATH/VICHS.config

# Konfiguracja nazwy użytkownika i maila dla CI
if [ "$CI" = "true" ]; then
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

    function getOrDownloadExternal {
        # Zakładamy, że katalog zawierający inne sklonowane repozytorium znajduje się wyżej niż katalog naszej własnej listy
        if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
            CLONED_EXTERNAL_FILE="$MAIN_PATH/../$CLONED_EXTERNAL"
        else
            if ! wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"; then
                printf "%s\n" "$(gettext "Error during file download")"
                git checkout "$FINAL"
                rm -r "$EXTERNAL_TEMP"
                exit 0
            fi
        fi
    }

    function getConvertableRulesForHosts() {
        HOSTS_TEMP="$SECTIONS_DIR/TEMP_CONVERT.temp-hosts"
        {
            grep -o '^||.*^$' "$1"
            grep -o '^0.0.0.0.*' "$1"
            # shellcheck disable=SC2016
            grep -o '^||.*^$all$' "$1"
        } >>"$HOSTS_TEMP"
    }

    function convertToHosts() {
        sed -i "s|\$all$||" "$HOSTS_TEMP"
        sed -i "s|[|][|]|0.0.0.0 |" "$HOSTS_TEMP"
        sed -i 's/[\^]//g' "$HOSTS_TEMP"
        sed -i '/[/\*]/d' "$HOSTS_TEMP"
        sed -i -r "/0\.0\.0\.0 [0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]/d" "$HOSTS_TEMP"
        sed -r "/^0\.0\.0\.0 (www\.|www[0-9]\.|www\-|pl\.|pl[0-9]\.)/! s/^0\.0\.0\.0 /0.0.0.0 www./" "$HOSTS_TEMP" >"$HOSTS_TEMP.2"
        if [ -f "$HOSTS_TEMP.2" ]; then
            cat "$HOSTS_TEMP" "$HOSTS_TEMP.2" >"$HOSTS_TEMP.3"
            mv "$HOSTS_TEMP.3" "$HOSTS_TEMP"
            rm -r "$HOSTS_TEMP.2"
        fi
        sort -uV -o "$HOSTS_TEMP" "$HOSTS_TEMP"
        SECTION="$HOSTS_TEMP"
    }

    function convertToDomains() {
        sed -i "s|\$all$||" "$HOSTS_TEMP"
        sed -i "s|[|][|]||" "$HOSTS_TEMP"
        sed -i 's/[\^]//g' "$HOSTS_TEMP"
        sed -i '/[/\*]/d' "$HOSTS_TEMP"
        sed -r "/^(www\.|www[0-9]\.|www\-|pl\.|pl[0-9]\.|[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9])/! s/^/www./" "$HOSTS_TEMP" >"$HOSTS_TEMP.2"
        if [ -f "$HOSTS_TEMP.2" ]; then
            cat "$HOSTS_TEMP" "$HOSTS_TEMP.2" >"$HOSTS_TEMP.3"
            mv "$HOSTS_TEMP.3" "$HOSTS_TEMP"
            rm -r "$HOSTS_TEMP.2"
        fi
        sort -uV -o "$HOSTS_TEMP" "$HOSTS_TEMP"
        SECTION="$HOSTS_TEMP"
    }

    function getConvertableRulesForPH() {
        PH_TEMP="$SECTIONS_DIR/TEMP_CONVERT.temp-ph"
        {
            grep -o '^||.*\*.*^$' "$1"
            # shellcheck disable=SC2016
            grep -o '^||.*\*.*^$all$' "$1"
        } >>"$PH_TEMP"
    }

    function convertToPihole() {
        sed -i "s|\$all$||" "$PH_TEMP"
        sed -i "s|[|][|]|0.0.0.0 |" "$PH_TEMP"
        sed -i 's/[\^]//g' "$PH_TEMP"
        sed -i -r "/0\.0\.0\.0 [0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]/d" "$PH_TEMP"
        sed -r "/^0\.0\.0\.0 (www\.|www[0-9]\.|www\-|pl\.|pl[0-9]\.)/! s/^0\.0\.0\.0 //" "$PH_TEMP" >>"$PH_TEMP.2"
        sed -i '/^0\.0\.0\.0\b/d' "$PH_TEMP.2"
        sed -i 's|\.|\\.|g' "$PH_TEMP.2"
        sed -i 's|^|(^\|\\.)|' "$PH_TEMP.2"
        sed -i "s|$|$|" "$PH_TEMP.2"
        sed -i "s|\*|.*|" "$PH_TEMP.2"
        rm -rf "$PH_TEMP"
        mv "$PH_TEMP.2" "$PH_TEMP"
        sort -uV -o "$PH_TEMP" "$PH_TEMP"
        SECTION="$PH_TEMP"
    }

    function initVars() {
        EXTERNAL=$(awk -v instruction="@$1" '$1 == instruction { print $2; exit }' "$FINAL")
        CLONED_EXTERNAL=$(awk -v instruction="@$1" '$1 == instruction { print $3; exit }' "$FINAL")
        SECTION=${SECTIONS_DIR}/${EXTERNAL}.${SECTIONS_EXT}
    }

    function initCVars() {
        LOCAL=${SECTIONS_DIR}/$(awk -v instruction="@$1" '$1 == instruction { print $2; exit }' "$FINAL").${SECTIONS_EXT}
        EXTERNAL=$(awk -v instruction="@$1" '$1 == instruction { print $3; exit }' "$FINAL")
        CLONED_EXTERNAL=$(awk -v instruction="@$1" '$1 == instruction { print $4; exit }' "$FINAL")
    }

    function includeSection() {
        sed -e '0,/^@'"$1"'/!b; /@'"$1"'/{ r '"$SECTION"'' -e 'd }' "$FINAL" >"$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        if [[ "$1" != "include" ]]; then
            rm -rf "$SECTION"
        fi
        if [ -f "$EXTERNAL_TEMP" ]; then
            rm -r "$EXTERNAL_TEMP"
        fi
    }

    # FILTERLIST to nazwa pliku (bez rozszerzenia), który chcemy zbudować
    FILTERLIST_FILE=$(basename "$i")
    FILTERLIST="${FILTERLIST_FILE%.*}"

    # Ustalanie ścieżki do szablonów
    if grep -q "@templatesPath" "$CONFIG"; then
        TEMPLATE=$MAIN_PATH/$(grep -oP -m 1 '@templatesPath \K.*' "$CONFIG")/${FILTERLIST}.template
    else
        TEMPLATE=$MAIN_PATH/templates/${FILTERLIST}.template
    fi

    FINAL=$i
    FINAL_B=$MAIN_PATH/${FILTERLIST}.backup
    TEMPORARY=$MAIN_PATH/${FILTERLIST}.temp

    # Tworzenie kopii pliku początkowego
    cp -R "$FINAL" "$FINAL_B"

    # Podmienianie zawartości pliku końcowego na zawartość template'u
    cp -R "$TEMPLATE" "$FINAL"

    # Usuwanie DEV z nazwy filtrów
    if [ "$RTM" = "true" ]; then
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

    # Ustalanie rozszerzenia plików sekcji
    if grep -q "@sectionsExt" "$FINAL"; then
        SECTIONS_EXT="$(grep -oP -m 1 '@sectionsExt \K.*' "$FINAL")"
    elif grep -q "@sectionsExt" "$CONFIG"; then
        SECTIONS_EXT="$(grep -oP -m 1 '@sectionsExt \K.*' "$CONFIG")"
    else
        SECTIONS_EXT="txt"
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

    # Plik tymczasowy do zapisu zewnętrznych sekcji
    EXTERNAL_TEMP="$SECTIONS_DIR"/external.temp

    # Obliczanie ilości sekcji (wystąpień słowa @include w template'cie)
    END=$(grep -oic '@include' "${TEMPLATE}")

    # Doklejanie sekcji w odpowiednie miejsca
    for ((n = 1; n <= END; n++)); do
        initVars "include"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                touch "$EXTERNAL_TEMP"
                cp "$CLONED_EXTERNAL_FILE" "$EXTERNAL_TEMP"
            fi
            externalCleanup
            sed -i "1s|^|!@ >>>>>>>> $EXTERNAL\n|" "$EXTERNAL_TEMP"
            echo "!@ <<<<<<<< $EXTERNAL" >>"$EXTERNAL_TEMP"
            SECTION="$EXTERNAL_TEMP"
        fi
        includeSection "include"
    done

    # Obliczanie ilości sekcji, w których zostaną zwhitelistowane reguły sieciowe (wystąpień słowa @NWLinclude w template'cie)
    END_NWL=$(grep -oic '@NWLinclude' "${TEMPLATE}")

    # Doklejanie sekcji w odpowiednie miejsca i zamiana na wyjątki
    for ((n = 1; n <= END_NWL; n++)); do
        initVars "NWLinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
            fi
        fi
        WL_TEMP="$SECTIONS_DIR/$1.temp-wl"
        grep -o '^||.*^$' "$SECTION" >>"$WL_TEMP"
        sed -i "s|[|][|]|@@|" "$WL_TEMP"
        sed -i 's/[\^]//g' "$WL_TEMP"
        SECTION="$WL_TEMP"
        includeSection "NWLinclude"
    done

    # Obliczanie ilości sekcji, w których zostaną zwhitelistowane reguły sieciowe z wykorzystaniem modyfikatora badfilter (wystąpień słowa @BNWLinclude w template'cie)
    END_BNWL=$(grep -oic '@BNWLinclude' "${TEMPLATE}")

    # Doklejanie sekcji w odpowiednie miejsca i zamiana na wyjątki
    for ((n = 1; n <= END_BNWL; n++)); do
        initVars "BNWLinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
            fi
        fi
        WL_TEMP="$SECTIONS_DIR/$1.temp-wl"
        grep -o '^||.*^$' "$SECTION" >>"$WL_TEMP"
        # shellcheck disable=SC2016
        grep -o '^||.*^$all$' "$SECTION" >>"$WL_TEMP"
        sed -i "s|\$all$|\$all,badfilter|" "$WL_TEMP"
        sed -i "s|\^$|\^\$badfilter|" "$WL_TEMP"
        SECTION="$WL_TEMP"
        includeSection "NWLinclude"
    done

    # Obliczanie ilości sekcji, które zostaną pobrane ze źródeł zewnętrznych i dodane z nich zostaną tylko unikalne elementy
    END_URLU=$(grep -oic '@URLUinclude' "${TEMPLATE}")

    # Dodawanie unikalnych reguł z zewnętrznych list
    for ((n = 1; n <= END_URLU; n++)); do
        EXTERNAL=$(awk '$1 == "@URLUinclude" { print $2; exit }' "$FINAL")
        CLONED_EXTERNAL=$(awk '$1 == "@URLUinclude" { print $3; exit }' "$FINAL")
        getOrDownloadExternal
        if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
            touch "$EXTERNAL_TEMP"
            cp "$CLONED_EXTERNAL_FILE" "$EXTERNAL_TEMP"
        fi
        externalCleanup
        cp -R "$FINAL_B" "$TEMPORARY"
        sed -i "/!@>>>>>>>> ${EXTERNAL//\//\\/}/,/!@<<<<<<<< ${EXTERNAL//\//\\/}/d" "$TEMPORARY"
        sed -i "/!#if/d" "$TEMPORARY"
        sed -i "/!#endif/d" "$TEMPORARY"
        UNIQUE_TEMP=$SECTIONS_DIR/unique_external.temp
        diff "$EXTERNAL_TEMP" "$TEMPORARY" --new-line-format="" --old-line-format="%L" --unchanged-line-format="" >"$UNIQUE_TEMP"
        rm -rf "$EXTERNAL_TEMP"
        cp -R "$UNIQUE_TEMP" "$EXTERNAL_TEMP"
        rm -rf "$UNIQUE_TEMP"
        sed -i "1s|^|!@>>>>>>>> $EXTERNAL\n|" "$EXTERNAL_TEMP"
        echo "!@<<<<<<<< $EXTERNAL" >>"$EXTERNAL_TEMP"
        SECTION="$EXTERNAL_TEMP"
        includeSection "URLUinclude"
    done

    # Obliczanie ilości sekcji, które zostaną pobrane ze źródeł zewnętrznych i połączone z lokalnymi sekcjami
    END_COMBINE=$(grep -oic '@COMBINEinclude' "${TEMPLATE}")

    # Łączenie lokalnych i zewnętrznych sekcji w jedno oraz doklejanie ich w odpowiednie miejsca
    for ((n = 1; n <= END_COMBINE; n++)); do
        initCVars "COMBINEinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                touch "$EXTERNAL_TEMP"
                cp "$CLONED_EXTERNAL_FILE" "$EXTERNAL_TEMP"
                externalCleanup
                sort -u -o "$EXTERNAL_TEMP" "$EXTERNAL_TEMP"
                EXTERNAL_MTEMP="$EXTERNAL_TEMP"
            fi
        else
            EXTERNAL_MTEMP=${SECTIONS_DIR}/$(awk '$1 == "@COMBINEinclude" { print $3; exit }' "$FINAL").${SECTIONS_EXT}
        fi
        SECTIONS_TEMP=${SECTIONS_DIR}/temp/
        mkdir -p "$SECTIONS_TEMP"
        MERGED_TEMP=${SECTIONS_TEMP}/merged-temp.txt
        cat "$LOCAL" "$EXTERNAL_MTEMP" >>"$MERGED_TEMP"
        if [ -f "$FOP" ]; then
            python3 "${FOP}" --d "${SECTIONS_TEMP}"
        fi
        sort -uV -o "$MERGED_TEMP" "$MERGED_TEMP"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|!@ >>>>>>>> $EXTERNAL + $(basename "$LOCAL")\n|" "$MERGED_TEMP"
            echo "!@ <<<<<<<< $EXTERNAL + $(basename "$LOCAL")" >>"$MERGED_TEMP"
        fi
        SECTION="$MERGED_TEMP"
        includeSection "COMBINEinclude"
        rm -rf "$SECTIONS_TEMP"
    done

    # Obliczanie ilości sekcji/list filtrów, które zostaną przekonwertowane na hosts
    END_HOSTS=$(grep -oic '@HOSTSinclude' "${TEMPLATE}")

    # Konwertowanie na hosts i doklejanie zawartości sekcji/list filtrów w odpowiednie miejsca
    for ((n = 1; n <= END_HOSTS; n++)); do
        initVars "HOSTSinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
            fi
        fi
        getConvertableRulesForHosts "$SECTION"
        convertToHosts
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL => hosts\n|" "$HOSTS_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL => hosts" >>"$HOSTS_TEMP"
        fi
        includeSection "HOSTSinclude"
    done

    # Obliczanie ilości sekcji, które zostaną pobrane ze źródeł zewnętrznych i połączone z lokalnymi sekcjami
    END_HOSTSCOMBINE=$(grep -oic '@COMBINEHOSTSinclude' "${TEMPLATE}")

    # Łączenie lokalnych i zewnętrznych sekcji w jedno oraz doklejanie ich w odpowiednie miejsca
    for ((n = 1; n <= END_HOSTSCOMBINE; n++)); do
        initCVars "COMBINEHOSTSinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
            fi
        else
            SECTION=${SECTIONS_DIR}/$(awk '$1 == "@COMBINEHOSTSinclude" { print $3; exit }' "$FINAL").${SECTIONS_EXT}
        fi
        getConvertableRulesForHosts "$LOCAL"
        getConvertableRulesForHosts "$SECTION"
        convertToHosts
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL + $(basename "$LOCAL") => hosts\n|" "$HOSTS_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL + $(basename "$LOCAL") => hosts" >>"$HOSTS_TEMP"
        fi
        includeSection "COMBINEHOSTSinclude"
    done

    # Obliczanie ilości sekcji/list filtrów, które zostaną przekonwertowane na format domenowy
    END_DOMAINS=$(grep -oic '@DOMAINSinclude' "${TEMPLATE}")

    # Konwertowanie na domeny i doklejanie zawartości sekcji/list filtrów w odpowiednie miejsca
    for ((n = 1; n <= END_DOMAINS; n++)); do
        initVars "DOMAINSinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
            fi
        fi
        getConvertableRulesForHosts "$SECTION"
        convertToDomains
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL => domains\n|" "$HOSTS_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL => domains" >>"$HOSTS_TEMP"
        fi
        includeSection "DOMAINSinclude"
    done

    # Obliczanie ilości sekcji, które zostaną pobrane ze źródeł zewnętrznych i połączone z lokalnymi sekcjami
    END_DOMAINSCOMBINE=$(grep -oic '@COMBINEDOMAINSinclude' "${TEMPLATE}")

    # Łączenie lokalnych i zewnętrznych sekcji w jedno oraz doklejanie ich w odpowiednie miejsca
    for ((n = 1; n <= END_DOMAINSCOMBINE; n++)); do
        initCVars "COMBINEDOMAINSinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
            fi
        else
            SECTION=${SECTIONS_DIR}/$(awk '$1 == "@COMBINEDOMAINSinclude" { print $3; exit }' "$FINAL").${SECTIONS_EXT}
        fi
        getConvertableRulesForHosts "$LOCAL"
        getConvertableRulesForHosts "$SECTION"
        convertToDomains
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL + $(basename "$LOCAL") => domains\n|" "$HOSTS_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL + $(basename "$LOCAL") => domains" >>"$HOSTS_TEMP"
        fi
        includeSection "COMBINEDOMAINSinclude"
    done

    # Obliczanie ilości sekcji/list filtrów, z których zostanie wyodrębnionych część reguł (jedynie reguły zawierajace gwiazdki) w celu konwersji na format regex zgodny z PiHole
    END_PH=$(grep -oic '@PHinclude' "${TEMPLATE}")

    # Konwertowanie na format regex zgodny z PiHole i doklejanie zawartości sekcji/list filtrów w odpowiednie miejsca
    for ((n = 1; n <= END_PH; n++)); do
        initVars "PHinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
            fi
        fi
        getConvertableRulesForPH "$SECTION"
        convertToPihole
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL => Pi-hole RegEx\n|" "$PH_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL => Pi-hole RegEx" >>"$PH_TEMP"
        fi
        includeSection "PHinclude"
    done

    # Obliczanie ilości sekcji, które zostaną pobrane ze źródeł zewnętrznych, skonwerterowane na format regex zgodny z Pi-hole (jedynie reguły zawierajace gwiazdki) i połączone z lokalnymi sekcjami
    END_PHCOMBINE=$(grep -oic '@COMBINEPHinclude' "${TEMPLATE}")

    # Konwertowanie na format regex zgodny z PiHole oraz łączenie lokalnych i zewnętrznych sekcji w jedno oraz doklejanie ich w odpowiednie miejsca
    for ((n = 1; n <= END_PHCOMBINE; n++)); do
        initCVars "COMBINEPHinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
                externalCleanup
            fi
        else
            SECTION=${SECTIONS_DIR}/$(awk '$1 == "@COMBINEPHinclude" { print $3; exit }' "$FINAL").${SECTIONS_EXT}
        fi
        # shellcheck disable=SC2016
        if grep -qo '^||.*\*.*^$' "$LOCAL" || grep -qo '^||.*\*.*^$all$' "$LOCAL"; then
            getConvertableRulesForPH "$LOCAL"
            getConvertableRulesForPH "$SECTION"
            convertToPihole
        else
            getConvertableRulesForPH "$SECTION"
            convertToPihole
            cat "$LOCAL" >>"$PH_TEMP"
            sort -uV -o "$PH_TEMP" "$PH_TEMP"
        fi
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL + $(basename "$LOCAL") => Pi-hole RegEx\n|" "$PH_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL + $(basename "$LOCAL") => Pi-hole RegEx" >>"$PH_TEMP"
        fi
        includeSection "COMBINEPHinclude"
    done

    # Usuwanie zbędnych instrukcji z finalnego pliku
    sed -i '/@path /d' "$FINAL"
    sed -i '/@sectionsExt /d' "$FINAL"

    # Przejście do katalogu, w którym znajduje się lokalne repozytorium git
    cd "$MAIN_PATH" || exit

    # Ustawianie nazwy kodowej (krótszej nazwy listy filtrów) do opisu commita w zależności od tego, co jest wpisane w polu „Codename:". Jeśli nie ma takiego pola, to codename=nazwa_pliku.
    if grep -q "! Codename" "$i"; then
        filter=$(grep -oP -m 1 '! Codename: \K.*' "$i")
    else
        # shellcheck disable=SC2034
        filter="$FILTERLIST"
    fi

    # Dodawanie zmienionych sekcji do repozytorium git
    if [ ! "$RTM" ]; then
        git add "$SECTIONS_DIR"/*
        git commit -m "$(gettext "Update sections")" -m "[ci skip]"
    fi

    # Ustawienie strefy czasowej
    TIMEZONE=$(grep -oP -m 1 '@tz \K.*' "$CONFIG")
    if [ -n "$TIMEZONE" ]; then
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
        if [[ "$VERSION_FORMAT" = "Year.Month.NumberOfCommitsInMonth" ]]; then
            version=$(date +"%Y").$(date +"%-m").$(git rev-list --count HEAD --after="$(date -d "-$(date +%d) days " "+%Y-%m-%dT23:59")" "$FINAL")
        elif [[ "$VERSION_FORMAT" = "Year.Month.Day.TodayNumberOfCommits" ]]; then
            version=$(date +"%Y").$(date +"%-m").$(date +"%-d").$(($(git rev-list --count HEAD --before="$(date '+%F' --date="tomorrow")"T24:00 --after="$(date '+%F' -d "1 day ago")"T23:59 "$FINAL")))
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
        grep -v '! Checksum: ' "$i" | grep -v '^$' >"$i".chk
        # Pobieranie sumy kontrolnej... Binarny MD5 zakodowany w Base64
        checksum=$(openssl dgst -md5 -binary "$i".chk | openssl enc -base64 | cut -d "=" -f 1)
        # Zamiana atrapy sumy kontrolnej na prawdziwą
        sed -i "/! Checksum: /c\! Checksum: $checksum" "$i"
        rm -r "$i".chk

        # Dodawanie zmienionych plików do repozytorium git
        git add "$i"

        # Zapisywanie nazw zmienionych plików
        if [ "$SAVE_CHANGED_FN" = "true" ]; then
            git diff --cached --name-only --pretty=format: | sort -u  >> "$SCRIPT_PATH"/V_CHANGED_FILES.txt
        fi

        # Commitowanie zmienionych plików
        if [ "$CI" = "true" ]; then
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
    if [ "$CI" = "true" ]; then
        GIT_SLUG=$(git ls-remote --get-url | sed "s|https://||g" | sed "s|git@||g" | sed "s|:|/|g")
        git push https://"${CI_USERNAME}":"${GIT_TOKEN}"@"${GIT_SLUG}" >/dev/null 2>&1
    else
        printf "%s\n" "$(gettext "Do you want to send changed files to git now?")"
        select yn in $(gettext "Yes") $(gettext "No"); do
            case $yn in
            "$(gettext "Yes")")
                git push
                break
                ;;
            "$(gettext "No")") break ;;
            esac
        done
    fi
fi
