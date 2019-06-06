#!/bin/bash

# VICHS - Version Include Checksum Hosts Sort
# v2.2.1

# MAIN_PATH to miejsce, w którym znajduje się główny katalog repozytorium (zakładamy, że skrypt znajduje się w katalogu o 1 niżej od głównego katalogu repozytorium)
MAIN_PATH=$(dirname "$0")/..

# Przejście do katalogu, w którym znajduje się lokalne repozytorium git
cd $MAIN_PATH

# Lokalizacja pliku konfiguracyjnego
CONFIG=$MAIN_PATH/scripts/VICHS.config

# Konfiguracja nazwy użytkownika i maila dla CI
if [ "$CI" = "true" ] ; then
    CI_USERNAME=$(grep -oP -m 1 '@CIusername \K.*' $CONFIG)
    CI_EMAIL=$(grep -oP -m 1 '@CIemail \K.*' $CONFIG)
    git config --global user.name "${CI_USERNAME}"
    git config --global user.email "${CI_EMAIL}"
fi

for i in "$@"; do

    # FILTERLIST to nazwa pliku, który chcemy zbudować
    FILTERLIST=$(basename $i .txt)

    TEMPLATE=$MAIN_PATH/templates/${FILTERLIST}.template
    FINAL=$i
    TEMPORARY=$MAIN_PATH/${FILTERLIST}.temp

    # Podmienianie zawartości pliku końcowego na zawartość template'u
    cp -R $TEMPLATE $FINAL

    # Usuwanie DEV z nazwy filtrów
    if [ "$RTM_MODE" = "true" ] ; then
        sed -i "s| DEV||g" $FINAL
    fi

    # Ustalanie ścieżki do sekcji
    if grep -q "@path" $FINAL; then
        SECTIONS_DIR=$MAIN_PATH/$(grep -oP -m 1 '@path \K.*' $FINAL)
    elif grep -q "@path" $CONFIG; then
        SECTIONS_DIR=$MAIN_PATH/$(grep -oP -m 1 '@path \K.*' $CONFIG)
    else
        SECTIONS_DIR=$MAIN_PATH/sections/$FILTERLIST
    fi

    # Usuwanie pustych linii z sekcji
    find ${SECTIONS_DIR} -type f -exec sed -i '/^$/d' {} \;

    # Usuwanie białych znaków z końca linii
    find ${SECTIONS_DIR} -type f -exec sed -i 's/[[:space:]]*$//' {} \;

    # Sortowanie sekcji z pominięciem tych, które zawierają specjalne instrukcje
    find ${SECTIONS_DIR} -type f ! -iname ""*_specjalne_instrukcje.txt"" -exec sort -uV -o {} {} \;

    # Obliczanie ilości sekcji (wystąpień słowa @include w template'cie
    END=$(grep -o -i '@include' ${TEMPLATE} | wc -l)

    # Doklejanie sekcji w odpowiednie miejsca
    for (( n=1; n<=$END; n++ ))
    do
        SEKCJA=$(grep -oP -m 1 '@include \K.*' $FINAL)
        sed -e '0,/^@include/!b; /@include/{ r '${SECTIONS_DIR}/${SEKCJA}.txt'' -e 'd }' $FINAL > $TEMPORARY
        cp -R $TEMPORARY $FINAL
    done

    # Obliczanie ilości sekcji/list filtrów, które zostaną pobrane ze źródeł zewnętrznych
    END_URL=$(grep -o -i '@URLinclude' ${TEMPLATE} | wc -l)

    # Doklejanie zawartości zewnętrznych plików w odpowiednie miejsca
    for (( n=1; n<=$END_URL; n++ ))
    do
        EXTERNAL=$(grep -oP -m 1 '@URLinclude \K.*' $FINAL)
        wget -O $SECTIONS_DIR/external.temp "${EXTERNAL}"
        sed -i '/! Checksum/d' $SECTIONS_DIR/external.temp
        sed -i '/!#include /d' $SECTIONS_DIR/external.temp
        sed -i '/Adblock Plus 2.0/d' $SECTIONS_DIR/external.temp
        sed -i '/! Dołączenie listy/d' $SECTIONS_DIR/external.temp
        sed -i "s|! |!@|g" $SECTIONS_DIR/external.temp
        sed -e '0,/^@URLinclude/!b; /@URLinclude/{ r '$SECTIONS_DIR/external.temp'' -e 'd }' $FINAL > $TEMPORARY
        cp -R $TEMPORARY $FINAL
        rm -r $SECTIONS_DIR/external.temp
    done

    # Obliczanie ilości list, które zostaną przekonwertowane na hosts i pobrane ze źródeł zewnętrznych
    END_HOSTS=$(grep -o -i '@HOSTSinclude' ${TEMPLATE} | wc -l)

    # Konwertowanie na hosts i doklejanie zawartości list w odpowiednie miejsca
    for (( n=1; n<=$END_HOSTS; n++ ))
    do
        EXTERNAL=$(grep -oP -m 1 '@HOSTSinclude \K.*' $FINAL)
        wget -O $SECTIONS_DIR/external.temp "${EXTERNAL}"
        grep -o '\||.*^' $SECTIONS_DIR/external.temp > $SECTIONS_DIR/external_hosts.temp
        sed -i "s|[|][|]|0.0.0.0 |" $SECTIONS_DIR/external_hosts.temp
        sed -i 's/[/\^]//g' $SECTIONS_DIR/external_hosts.temp
        sed -i '/[/\*]/d' $SECTIONS_DIR/external_hosts.temp
        sort -uV -o $SECTIONS_DIR/external_hosts.temp $SECTIONS_DIR/external_hosts.temp
        sed -e '0,/^@HOSTSinclude/!b; /@HOSTSinclude/{ r '$SECTIONS_DIR/external_hosts.temp'' -e 'd }' $FINAL > $TEMPORARY
        cp -R $TEMPORARY $FINAL
        rm -r $SECTIONS_DIR/external.temp
        rm -r $SECTIONS_DIR/external_hosts.temp
    done

    # Usuwanie tymczasowego pliku
    rm -r $TEMPORARY

    # Usuwanie instrukcji informującej o ścieżce do sekcji
    sed -i '/@path /d' $FINAL

    # Przejście do katalogu, w którym znajduje się lokalne repozytorium git
    cd $MAIN_PATH

    # Ustawianie nazwy kodowej (krótszej nazwy listy filtrów) do opisu commita w zależności od tego, co jest wpisane w polu „Codename:". Jeśli nie ma takiego pola, to codename=nazwa_pliku.
    if grep -q "! Codename" $i; then
        filter=$(grep -oP -m 1 '! Codename: \K.*' $i);
    else
        filter=$(basename $i);
    fi

    # Dodawanie zmienionych sekcji do repozytorium git
    if [ ! "$RTM_MODE" ] ; then
        git add $SECTIONS_DIR/*
        git commit -m "Update sections of $filter [ci skip]"
    fi

    # Ustawienie polskiej strefy czasowej
    export TZ=":Poland"

    # Aktualizacja daty i godziny w polu „Last modified"
    export LC_ALL=en_US.UTF-8
    modified=$(date +"$(grep -oP -m 1 '@dateFormat \K.*' $CONFIG)")
    sed -i "s|@modified|$modified|g" $i

    # Aktualizacja wersji
    VERSION_FORMAT=$(grep -oP -m 1 '@versionFormat \K.*' $CONFIG)
    if [[ "$VERSION_FORMAT" = "Year.Month.NumberOfCommitsInMonth" && ! "$RTM_MODE" ]] ; then
        version=$(date +"%Y").$(date +"%-m").$(( $(git rev-list --count HEAD --after=$(date -d "-$(date +%d) days " "+%Y-%m-%dT23:59") $FINAL) + 1))
    elif [[ "$VERSION_FORMAT" = "Year.Month.NumberOfCommitsInMonth" && "$RTM_MODE" = "true" ]] ; then
        version=$(date +"%Y").$(date +"%-m").$(git rev-list --count HEAD --after=$(date -d "-$(date +%d) days " "+%Y-%m-%dT23:59") $FINAL)
    elif [[ "$VERSION_FORMAT" = "Year.Month.Day.TodayNumberOfCommits" && ! "$RTM_MODE" ]] ; then
        version=$(date +"%Y").$(date +"%-m").$(date +"%-d").$(( $(git rev-list --count HEAD --before=$(date '+%F' --date="tomorrow")T24:00 --after=$(date '+%F' -d "1 day ago")T23:59 $FINAL) + 1))
    elif [[ "$VERSION_FORMAT" = "Year.Month.Day.TodayNumberOfCommits" && "$RTM_MODE" = "true" ]] ; then
        version=$(date +"%Y").$(date +"%-m").$(date +"%-d").$(( $(git rev-list --count HEAD --before=$(date '+%F' --date="tomorrow")T24:00 --after=$(date '+%F' -d "1 day ago")T23:59 $FINAL)))
    elif [ "$(grep -oP -m 1 '@versionDateFormat \K.*' $CONFIG)"] ; then
        version=$(date +"$(grep -oP -m 1 '@versionDateFormat \K.*' $CONFIG)")
    else
        version=$(date +"%Y%m%d%H%M")
    fi

    sed -i "s|@version|$version|g" $i

    # Aktualizacja pola „aktualizacja"
    export LC_ALL=pl_PL.UTF-8
    aktualizacja=$(date +"$(grep -oP -m 1 '@dateFormat \K.*' $CONFIG)")
    sed -i "s|@aktualizacja|$aktualizacja|g" $i

    # Aktualizacja sumy kontrolnej
    # Założenie: kodowanie UTF-8 i styl końca linii Unix
    # Usuwanie starej sumy kontrolnej i pustych linii
    grep -v '! Checksum: ' $i | grep -v '^$' > $i.chk
    # Pobieranie sumy kontrolnej... Binarny MD5 zakodowany w Base64
    suma_k=`cat $i.chk | openssl dgst -md5 -binary | openssl enc -base64 | cut -d "=" -f 1`
    # Zamiana atrapy sumy kontrolnej na prawdziwą
    sed -i "/! Checksum: /c\! Checksum: $suma_k" $i
    rm -r $i.chk

    # Dodawanie zmienionych plików do repozytorium git
    if [ ! "$RTM_MODE" ] ; then
        git add $i
    fi

    # Commitowanie zmienionych plików
    if [ "$CI" = "true" ] ; then
        git commit -m "Update $filter to version $version [ci skip]"
    elif [ ! "$RTM_MODE" ] ; then
        printf "Podaj rozszerzony opis commita do listy filtrów $filter, np 'Fix #1, fix #2' (bez ciapek; jeśli nie chcesz rozszerzonego opisu, to możesz po prostu nic nie wpisywać): "
        read roz_opis
        git commit -m "Update $filter to version $version [ci skip]" -m "${roz_opis}"
    fi

done

# Wysyłanie zmienionych plików do repozytorium git
if [ "$CI" = "true" ] ; then
    GIT_SLUG=$(git ls-remote --get-url | sed "s|https://||g" | sed "s|git@||g" | sed "s|:|/|g")
    git push https://${CI_USERNAME}:${GH_TOKEN}@${GIT_SLUG} HEAD:master > /dev/null 2>&1
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
