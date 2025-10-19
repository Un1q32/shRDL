#!/bin/sh

if [ -z "$1" ]; then
    printf "Usage: %s [--no-debs] [--single-threaded] [--jobs=JOBS] <repo url>\n" "${0##*/}"
    exit 1
fi

while [ $# -gt 0 ]; do
    case $1 in
        --no-debs) nodebs=1 ;;
        --single-threaded) singlethreaded=1 ;;
        --jobs=*) jobs=${1#*=} ;;
        --jobs) jobs=$2 && shift ;;
        http://*|https://*) domain="${1%/}" && repodomain=${domain#*//} ;;
        *) printf "Usage: %s [--no-debs] [--single-threaded] [--jobs=JOBS] <repo url>\n" "${0##*/}" ; exit 1 ;;
    esac
    shift
done

for dep in curl gzip bzip2; do
    if ! command -v $dep > /dev/null; then
        printf "%s not found, please install %s\n" "$dep" "$dep"
        exit 1
    fi
done

headers1="X-Machine: iPod4,1"
headers2="X-Unique-ID: 0000000000000000000000000000000000000000"
headers3="X-Firmware: 6.1"
headers4="User-Agent: Telesphoreo APT-HTTP/1.0.999"

[ -d "downloaded/$repodomain" ] || mkdir -p "downloaded/$repodomain"
cd "downloaded/$repodomain" || exit 1
:> urllist.txt

if [ "$(curl -H "$headers1" -H "$headers2" -H "$headers3" -H "$headers4" -w '%{http_code}' -L -s -o Packages.bz2 "$domain/Packages.bz2")" -eq 200 ]; then
    archive=bz2
    prog=bzip2
elif [ "$(curl -H "$headers1" -H "$headers2" -H "$headers3" -H "$headers4" -w '%{http_code}' -L -s -o Packages.gz "$domain/Packages.gz")" -eq 200 ]; then
    archive=gz
    prog=gzip
    rm Packages.bz2
else
    printf "Couldn't find a Packages file. Exiting\n"
    rm Packages.bz2 Packages.gz
    exit 1
fi

$prog -df Packages.$archive

while read -r line; do
    case $line in
        Filename:*)
            deburl=${line#Filename: }
            case $deburl in
                ./*) deburl=${deburl#./} ;;
            esac
            printf '%s\n' "$domain/$deburl" >> urllist.txt
        ;;
    esac
done < ./Packages

[ -n "$nodebs" ] && exit 0

[ ! -d debs ] && mkdir debs
cd debs || exit 1

command -v pgrep > /dev/null || singlethreaded=1

printf "Downloading debs\n"
if [ -n "$singlethreaded" ]; then
    while read -r i; do
        curl -H "$headers1" -H "$headers2" -H "$headers3" -H "$headers4" -g -L -s -O "$i"
    done < ../urllist.txt
else
    [ -z "$jobs" ] && jobs=16
    while read -r i; do
        while [ "$(pgrep curl | wc -l)" -ge "$jobs" ]; do
            sleep 0.1
        done
        curl -H "$headers1" -H "$headers2" -H "$headers3" -H "$headers4" -g -L -s -O "$i" &
    done < ../urllist.txt
    wait
fi
printf "Done!\n"
