#!/bin/bash

# VICHS - Version Include Checksum Hosts Sort
# v2.4.2

# MAIN_PATH to miejsce, w którym znajduje się główny katalog repozytorium (zakładamy, że skrypt znajduje się w katalogu o 1 niżej od głównego katalogu repozytorium)
MAIN_PATH=$(dirname "$0")/..

# Przejście do katalogu, w którym znajduje się lokalne repozytorium git
cd "$MAIN_PATH" || exit

# Lokalizacja pliku konfiguracyjnego
CONFIG=$MAIN_PATH/scripts/VICHS.config

# Konfiguracja nazwy użytkownika i maila dla CI
if [ "$CI" = "true" ] ; then
    CI_USERNAME=$(grep -oP -m 1 '@CIusername \K.*' "$CONFIG")
    CI_EMAIL=$(grep -oP -m 1 '@CIemail \K.*' "$CONFIG")
    git config --global user.name "${CI_USERNAME}"
    git config --global user.email "${CI_EMAIL}"
fi

for i in "$@"; do

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
    if [ "$RTM_MODE" = "true" ] ; then
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

    # Usuwanie pustych linii z sekcji
    find "${SECTIONS_DIR}" -type f -exec sed -i '/^$/d' {} \;

    # Usuwanie białych znaków z końca linii
    find "${SECTIONS_DIR}" -type f -exec sed -i 's/[[:space:]]*$//' {} \;

    # Sortowanie sekcji z pominięciem tych, które zawierają specjalne instrukcje
    find "${SECTIONS_DIR}" -type f ! -iname '*_specjalne_instrukcje.txt' -exec sort -uV -o {} {} \;

    # Obliczanie ilości sekcji (wystąpień słowa @include w template'cie)
    END=$(grep -o -i '@include' "${TEMPLATE}" | wc -l)

    # Doklejanie sekcji w odpowiednie miejsca
    for (( n=1; n<=END; n++ ))
    do
        SECTION=${SECTIONS_DIR}/$(grep -oP -m 1 '@include \K.*' "$FINAL").txt
        sed -e '0,/^@include/!b; /@include/{ r '"${SECTION}"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
    done

    # Obliczanie ilości sekcji, w których zostaną zwhitelistowane reguły sieciowe (wystąpień słowa @NWLinclude w template'cie)
    END_NWL=$(grep -o -i '@NWLinclude' "${TEMPLATE}" | wc -l)

    # Doklejanie sekcji w odpowiednie miejsca i zamiana na wyjątki
    for (( n=1; n<=END_NWL; n++ ))
    do
        SECTION=${SECTIONS_DIR}/$(grep -oP -m 1 '@NWLinclude \K.*' "$FINAL").txt
        grep -o '\||.*^' "$SECTION" > "$SECTION.temp"
        sed -e '0,/^@NWLinclude/!b; /@NWLinclude/{ r '"${SECTION}.temp"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        sed -i "s|[|][|]|@@|" "$TEMPORARY"
        sed -i 's/[\^]//g' "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        rm -r "$SECTION.temp"
    done

    # Obliczanie ilości sekcji, w których zostaną zwhitelistowane reguły sieciowe z wykorzystaniem modyfikatora badfilter (wystąpień słowa @BNWLinclude w template'cie)
    END_BNWL=$(grep -o -i '@BNWLinclude' "${TEMPLATE}" | wc -l)

    # Doklejanie sekcji w odpowiednie miejsca i zamiana na wyjątki
    for (( n=1; n<=END_BNWL; n++ ))
    do
        SECTION=${SECTIONS_DIR}/$(grep -oP -m 1 '@BNWLinclude \K.*' "$FINAL").txt
        grep -o '\||.*^' "$SECTION" > "$SECTION.temp"
        sed -e '0,/^@BNWLinclude/!b; /@BNWLinclude/{ r '"${SECTION}.temp"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        sed -i 's/[\^]/\^$badfilter/g' "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        rm -r "$SECTION.temp"
    done

    function external_cleanup {
        sed -i '/! Checksum/d' "$EXTERNAL_TEMP"
        sed -i '/!#include /d' "$EXTERNAL_TEMP"
        sed -i '/Adblock Plus 2.0/d' "$EXTERNAL_TEMP"
        sed -i '/! Dołączenie listy/d' "$EXTERNAL_TEMP"
        sed -i "s|! |!@|g" "$EXTERNAL_TEMP"
    }

    # Obliczanie ilości sekcji/list filtrów, które zostaną pobrane ze źródeł zewnętrznych
    END_URL=$(grep -o -i '@URLinclude' "${TEMPLATE}" | wc -l)

    # Doklejanie zawartości zewnętrznych plików w odpowiednie miejsca
    for (( n=1; n<=END_URL; n++ ))
    do
        EXTERNAL=$(grep -oP -m 1 '@URLinclude \K.*' "$FINAL")
        EXTERNAL_TEMP=$SECTIONS_DIR/external.temp
        wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"
        if ! wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"; then
            echo "Błąd w trakcie pobierania pliku"
            git checkout "$FINAL"
            rm -r "$EXTERNAL_TEMP"
            exit 0
        fi
        external_cleanup
        sed -i "1s|^|!@>>>>>>>> $EXTERNAL\n|" "$EXTERNAL_TEMP"
        echo "!@<<<<<<<< $EXTERNAL" >> "$EXTERNAL_TEMP"
        sed -e '0,/^@URLinclude/!b; /@URLinclude/{ r '"$EXTERNAL_TEMP"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        rm -r "$EXTERNAL_TEMP"
    done

    # Obliczanie ilości zewnętrznych sekcji, w których zostaną zwhitelistowane reguły sieciowe (wystąpień słowa @URLNWLinclude w template'cie)
    END_URLNWL=$(grep -o -i '@URLNWLinclude' "${TEMPLATE}" | wc -l)

    # Doklejanie sekcji w odpowiednie miejsca i zamiana na wyjątki
    for (( n=1; n<=END_URLNWL; n++ ))
    do
        EXTERNAL=$(grep -oP -m 1 '@URLNWLinclude \K.*' "$FINAL")
        EXTERNAL_TEMP=$MAIN_PATH/external.temp
        wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"
        if ! wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"; then
            echo "Błąd w trakcie pobierania pliku"
            git checkout "$FINAL"
            rm -r "$EXTERNAL_TEMP"
            exit 0
        fi
        grep -o '\||.*^' "$EXTERNAL_TEMP" > "$EXTERNAL_TEMP.2"
        external_cleanup
        sed -e '0,/^@URLNWLinclude/!b; /@URLNWLinclude/{ r '"$EXTERNAL_TEMP.2"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        sed -i "s|[|][|]|@@|" "$TEMPORARY"
        sed -i 's/[\^]//g' "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        rm -r "$EXTERNAL_TEMP"
        rm -r "$EXTERNAL_TEMP.2"
    done

    # Obliczanie ilości zewnętrznych sekcji, w których zostaną zwhitelistowane reguły sieciowe z wykorzystaniem modyfikatora badfilter (wystąpień słowa @URLBNWLinclude w template'cie)
    END_URLBNWL=$(grep -o -i '@URLBNWLinclude' "${TEMPLATE}" | wc -l)

    # Doklejanie sekcji w odpowiednie miejsca i zamiana na wyjątki
    for (( n=1; n<=END_URLBNWL; n++ ))
    do
        EXTERNAL=$(grep -oP -m 1 '@URLBNWLinclude \K.*' "$FINAL")
        EXTERNAL_TEMP=$MAIN_PATH/external.temp
        wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"
        if ! wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"; then
            echo "Błąd w trakcie pobierania pliku"
            git checkout "$FINAL"
            rm -r "$EXTERNAL_TEMP"
            exit 0
        fi
        grep -o '\||.*^' "$EXTERNAL_TEMP" > "$EXTERNAL_TEMP.2"
        external_cleanup
        sed -e '0,/^@URLBNWLinclude/!b; /@URLBNWLinclude/{ r '"$EXTERNAL_TEMP.2"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        sed -i 's/[\^]/\^$badfilter/g' "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        rm -r "$EXTERNAL_TEMP"
        rm -r "$EXTERNAL_TEMP.2"
    done


    # Obliczanie ilości sekcji, które zostaną pobrane ze źródeł zewnętrznych i dodane z nich zostaną tylko unikalne elementy
    END_URLU=$(grep -o -i '@URLUinclude' "${TEMPLATE}" | wc -l)

    # Dodawanie unikalnych reguł z zewnętrznych list
    for (( n=1; n<=END_URLU; n++ ))
    do
        EXTERNAL=$(awk '$1 == "@URLUinclude" { print $2; exit }' "$FINAL")
        EXTERNAL_TEMP=$SECTIONS_DIR/external.temp
        UNIQUE_TEMP=$SECTIONS_DIR/unique_external.temp
        wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"

        if  ! wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"; then
            echo "Błąd w trakcie pobierania pliku"
            git checkout "$FINAL"
            rm -r "$EXTERNAL_TEMP"
            exit 0
        fi

        sed  -i '/!.*Title\|modified\|Licence\|License/p;/!/d' "$EXTERNAL_TEMP"
        external_cleanup

        sort -u -o "$EXTERNAL_TEMP" "$EXTERNAL_TEMP"
        sort -u -o "$FINAL_B" "$FINAL_B"

        comm -23 "$EXTERNAL_TEMP" "$FINAL_B" > "$UNIQUE_TEMP"

        sort -uV -o "$UNIQUE_TEMP" "$UNIQUE_TEMP"

        E_TITLE=$(grep -r 'Title:' "$EXTERNAL_TEMP")
        E_MODIFIED=$(grep -r 'modified:' "$EXTERNAL_TEMP")
        E_LICENSE=$(grep -r 'Licence:\|License:' "$EXTERNAL_TEMP")

        sed -i "/!@Title/d" "$UNIQUE_TEMP"
        sed -i "/!@Last modified/d" "$UNIQUE_TEMP"
        sed -i "/!@Licence/d" "$UNIQUE_TEMP"
        sed -i "/!@License/d" "$UNIQUE_TEMP"

        sed -i "1s|^|!@>>>>>>>> $EXTERNAL\n|" "$UNIQUE_TEMP"
        sed -i "2s|^|$E_TITLE\n|" "$UNIQUE_TEMP"
        sed -i "3s|^|$E_LICENSE\n|" "$UNIQUE_TEMP"
        sed -i "4s|^|$E_MODIFIED\n|" "$UNIQUE_TEMP"
        sed -i "5s/^/!\n/" "$UNIQUE_TEMP"
        sed -i "6s/^/!\n/" "$UNIQUE_TEMP"
        echo "!@<<<<<<<< $EXTERNAL" >> "$UNIQUE_TEMP"
        sed -e '0,/^@URLUinclude/!b; /@URLUinclude/{ r '"$UNIQUE_TEMP"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        rm -r "$EXTERNAL_TEMP"
        rm -r "$UNIQUE_TEMP"
    done

    # Obliczanie ilości sekcji, które zostaną pobrane ze źródeł zewnętrznych i połączone z lokalnymi sekcjami
    END_COMBINE=$(grep -o -i '@COMBINEinclude' "${TEMPLATE}" | wc -l)

    # Łączenie lokalnych i zewnętrznych sekcji w jedno oraz doklejanie ich w odpowiednie miejsca
    for (( n=1; n<=END_COMBINE; n++ ))
    do
        LOCAL=${SECTIONS_DIR}/$(awk '$1 == "@COMBINEinclude" { print $2; exit }' "$FINAL").txt
        EXTERNAL=$(awk '$1 == "@COMBINEinclude" { print $3; exit }' "$FINAL")
        EXTERNAL_TEMP=$SECTIONS_DIR/external.temp
        MERGED_TEMP=$SECTIONS_DIR/merged.temp
        wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"
        if  ! wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"; then
            echo "Błąd w trakcie pobierania pliku"
            git checkout "$FINAL"
            rm -r "$EXTERNAL_TEMP"
            exit 0
        fi
        external_cleanup
        sort -u -o "$LOCAL" "$LOCAL"
        sort -u -o "$EXTERNAL_TEMP" "$EXTERNAL_TEMP"
        cat "$LOCAL" "$EXTERNAL_TEMP" >> "$MERGED_TEMP"
        sort -uV -o "$LOCAL" "$LOCAL"
        sort -uV -o "$MERGED_TEMP" "$MERGED_TEMP"
        sed -e '0,/^@COMBINEinclude/!b; /@COMBINEinclude/{ r '"$MERGED_TEMP"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        rm -r "$EXTERNAL_TEMP"
        rm -r "$MERGED_TEMP"
    done

    function convertToHosts() {
        sed -i "s|[|][|]|0.0.0.0 |" "$1"
        sed -i 's/[\^]//g' "$1"
        sed -i '/[/\*]/d' "$1"
        sed -i -r "/0\.0\.0\.0 [0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]/d" "$1"
        sed -r "/^0\.0\.0\.0 (www\.|www[0-9]\.|www\-|pl\.|pl[0-9]\.)/! s/^0\.0\.0\.0 /0.0.0.0 www./" "$1" > "$1.2"
    }

    # Obliczanie ilości sekcji/list filtrów, które zostaną przekonwertowane na hosts
    END_HOSTS=$(grep -o -i '@HOSTSinclude' "${TEMPLATE}" | wc -l)

    # Konwertowanie na hosts i doklejanie zawartości sekcji/list filtrów w odpowiednie miejsca
    for (( n=1; n<=END_HOSTS; n++ ))
    do
        HOSTS_FILE=${SECTIONS_DIR}/$(grep -oP -m 1 '@HOSTSinclude \K.*' "$FINAL").txt
        HOSTS_TEMP=$SECTIONS_DIR/hosts.temp
        grep -o '\||.*^' "$HOSTS_FILE" > "$HOSTS_TEMP"
        grep -o '\0.0.0.0.*' "$HOSTS_FILE" >> "$HOSTS_TEMP"
        convertToHosts "$HOSTS_TEMP"
        if [ -f "$HOSTS_TEMP.2" ]
        then
            cat "$HOSTS_TEMP" "$HOSTS_TEMP.2"  > "$HOSTS_TEMP.3"
            mv "$HOSTS_TEMP.3" "$HOSTS_TEMP"
        fi
        sort -uV -o "$HOSTS_TEMP" "$HOSTS_TEMP"
        sed -e '0,/^@HOSTSinclude/!b; /@HOSTSinclude/{ r '"$HOSTS_TEMP"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        rm -r "$HOSTS_TEMP"
        mv "$TEMPORARY" "$FINAL"
        if [ -f "$HOSTS_TEMP.2" ]
        then
            rm -r "$HOSTS_TEMP.2"
        fi
    done

    # Obliczanie ilości sekcji/list filtrów, które zostaną przekonwertowane na hosts i pobrane ze źródeł zewnętrznych
    END_URLHOSTS=$(grep -o -i '@URLHOSTSinclude' "${TEMPLATE}" | wc -l)

    # Konwertowanie na hosts i doklejanie zawartości sekcji/list filtrów w odpowiednie miejsca
    for (( n=1; n<=END_URLHOSTS; n++ ))
    do
        EXTERNAL=$(grep -oP -m 1 '@URLHOSTSinclude \K.*' "$FINAL")
        EXTERNAL_TEMP=$SECTIONS_DIR/external.temp
        EXTERNALHOSTS_TEMP=$SECTIONS_DIR/external_hosts.temp
        wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"
        if ! wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"; then
            echo "Błąd w trakcie pobierania pliku"
            git checkout "$FINAL"
            rm -r "$EXTERNAL_TEMP"
            exit 0
        fi
        grep -o '\||.*^' "$EXTERNAL_TEMP" > "$EXTERNALHOSTS_TEMP"
        convertToHosts "$EXTERNALHOSTS_TEMP"
        if [ -f "$EXTERNALHOSTS_TEMP.2" ]
        then
            cat "$EXTERNALHOSTS_TEMP" "$EXTERNALHOSTS_TEMP.2"  > "$EXTERNALHOSTS_TEMP.3"
            mv "$EXTERNALHOSTS_TEMP.3" "$EXTERNALHOSTS_TEMP"
        fi
        sort -uV -o "$EXTERNALHOSTS_TEMP" "$EXTERNALHOSTS_TEMP"
        sed -e '0,/^@URLHOSTSinclude/!b; /@URLHOSTSinclude/{ r '"$EXTERNALHOSTS_TEMP"'' -e 'd }' "$FINAL" > "$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        rm -r "$EXTERNAL_TEMP"
        rm -r "$EXTERNALHOSTS_TEMP"
        if [ -f "$EXTERNALHOSTS_TEMP.2" ]
        then
            rm -r "$EXTERNALHOSTS_TEMP.2"
        fi
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
    if [ ! "$RTM_MODE" ] ; then
        git add "$SECTIONS_DIR"/*
        git commit -m "Update sections of $filter [ci skip]"
    fi

    # Ustawienie polskiej strefy czasowej
    export TZ=":Poland"

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
        export LC_ALL=en_US.UTF-8
        modified=$(date +"$(grep -oP -m 1 '@dateFormat \K.*' "$CONFIG")")
        sed -i "s|@modified|$modified|g" "$i"

        # Aktualizacja wersji
        VERSION_FORMAT=$(grep -oP -m 1 '@versionFormat \K.*' "$CONFIG")
        if [[ "$VERSION_FORMAT" = "Year.Month.NumberOfCommitsInMonth" && ! "$RTM_MODE" ]] ; then
            version=$(date +"%Y").$(date +"%-m").$(( $(git rev-list --count HEAD --after="$(date -d "-$(date +%d) days " "+%Y-%m-%dT23:59")" "$FINAL") + 1))
        elif [[ "$VERSION_FORMAT" = "Year.Month.NumberOfCommitsInMonth" && "$RTM_MODE" = "true" ]] ; then
            version=$(date +"%Y").$(date +"%-m").$(git rev-list --count HEAD --after="$(date -d "-$(date +%d) days " "+%Y-%m-%dT23:59")" "$FINAL")
        elif [[ "$VERSION_FORMAT" = "Year.Month.Day.TodayNumberOfCommits" && ! "$RTM_MODE" ]] ; then
            version=$(date +"%Y").$(date +"%-m").$(date +"%-d").$(( $(git rev-list --count HEAD --before="$(date '+%F' --date="tomorrow")"T24:00 --after="$(date '+%F' -d "1 day ago")"T23:59 "$FINAL") + 1))
        elif [[ "$VERSION_FORMAT" = "Year.Month.Day.TodayNumberOfCommits" && "$RTM_MODE" = "true" ]] ; then
            version=$(date +"%Y").$(date +"%-m").$(date +"%-d").$(( $(git rev-list --count HEAD --before="$(date '+%F' --date="tomorrow")"T24:00 --after="$(date '+%F' -d "1 day ago")"T23:59 "$FINAL")))
        elif grep -q -oP -m 1 '@versionDateFormat \K.*' "$CONFIG"; then
            version=$(date +"$(grep -oP -m 1 '@versionDateFormat \K.*' "$CONFIG")")
        else
            version=$(date +"%Y%m%d%H%M")
        fi

        sed -i "s|@version|$version|g" "$i"

        # Aktualizacja pola „aktualizacja"
        export LC_ALL=pl_PL.UTF-8
        aktualizacja=$(date +"$(grep -oP -m 1 '@dateFormat \K.*' "$CONFIG")")
        sed -i "s|@aktualizacja|$aktualizacja|g" "$i"

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
        if [ ! "$RTM_MODE" ] ; then
            git add "$i"
        fi

        # Commitowanie zmienionych plików
        if [ "$CI" = "true" ] ; then
            git commit -m "Update $filter to version $version [ci skip]"
        elif [ ! "$RTM_MODE" ] ; then
            printf "Podaj rozszerzony opis commita do listy filtrów %s$filter, np 'Fix #1, fix #2' (bez ciapek; jeśli nie chcesz rozszerzonego opisu, to możesz po prostu nic nie wpisywać): "
            read -r roz_opis
            git commit -m "Update $filter to version $version [ci skip]" -m "${roz_opis}"
        fi
    else
        echo "Nic nowego nie zostało dodane do listy $filter. Jeżeli mimo to chcesz ją zaktualizować, to ustaw zmienną FORCED i uruchom ponownie skrypt."
        git checkout "$FINAL"
    fi
done

# Wysyłanie zmienionych plików do repozytorium git
commited=$(git cherry -v)
if [ "$commited" ]; then
    if [ "$CI" = "true" ] ; then
        GIT_SLUG=$(git ls-remote --get-url | sed "s|https://||g" | sed "s|git@||g" | sed "s|:|/|g")
        git push https://"${CI_USERNAME}":"${GH_TOKEN}"@"${GIT_SLUG}" HEAD:master > /dev/null 2>&1
    elif [ ! "$RTM_MODE" ] ; then
        echo "Czy chcesz teraz wysłać do gita zmienione pliki?"
        select yn in "Tak" "Nie"; do
            case $yn in
                        Tak )
                        git push
                        break;;
                        Nie ) break;;
            esac
        done
    fi
fi
