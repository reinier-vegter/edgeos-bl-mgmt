#!/bin/bash

OUTFOLDER=/tmp/ip_geo_blocklist

function printHelpExit() {
  echo "Usage:"
  echo "  $0 \"outputfile\" \"allowed_countries_file\""
  echo "  Outputfile: ipset file with ipset-name 'BlockedCountryIPv4Tmp'"
  echo "  allowed_countries_file: country codes allowed, each on a new line"
  exit 1
}
[ "$2" = "" ] && printHelpExit
OUTFILE=$1
ALLOWED_COUNTRY_FILE=$2

# Exit immediately if a simple command exits with a non-zero status
set -e

# [ ! -d "$OUTFOLDER" ] && mkdir -p "$OUTFOLDER"
function stopError() {
  msg=$1
  echo "$msg"
  exit 1
}

# Check binaries and folders.
command -v mapcidr > /dev/null || stopError "Install [mapcidr]"
[ ! -d "$(dirname "$OUTFILE")" ] && stopError "Folder [$(dirname "$OUTFILE")] does not exist"
[ -f "$OUTFILE" ] && stopError "File [$OUTFILE] already exists"
[ ! -f "$ALLOWED_COUNTRY_FILE" ] && stopError "File [$ALLOWED_COUNTRY_FILE] does not exist"
[ ! -d "$OUTFOLDER" ] && mkdir -p "$OUTFOLDER"

# Download data from registries
echo "Downloading resources..."
curl --silent https://ftp.apnic.net/stats/apnic/delegated-apnic-latest --output "$OUTFOLDER"/.delegated-apnic-latest.txt
curl --silent https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest --output "$OUTFOLDER"/.delegated-arin-extended-latest.txt
curl --silent https://ftp.ripe.net/ripe/stats/delegated-ripencc-latest --output "$OUTFOLDER"/.delegated-ripencc-latest.txt
curl --silent https://ftp.afrinic.net/pub/stats/afrinic/delegated-afrinic-latest --output "$OUTFOLDER"/.delegated-afrinic-latest.txt
curl --silent https://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-latest --output "$OUTFOLDER"/.delegated-lacnic-latest.txt

echo "Generating list of country codes..."
# Generate country codes
awk -F '|' '{ print $2 }' "$OUTFOLDER"/.delegated-*-latest.txt | sort | uniq | grep -E '[A-Z]{2}' > "$OUTFOLDER"/.country_code.txt
allowed_cc=( )
while read cc; do 
  allowed_cc+=("cc")
done <<< "$(cat "$ALLOWED_COUNTRY_FILE" | sed 's/#.*//g' | egrep -v '\s+|^$')"

# Generate country ip blocks, except allowed ones.
echo "Generating blocklist..."
echo "" > "$OUTFOLDER"/BlockedCountryIPv4.txt
# echo "" > "$OUTFOLDER"/BlockedCountryIPv6.txt
while read cc; do 
  if [[ ! " ${allowed_cc[*]} " =~ " ${cc} " ]]; then
    echo "Adding $cc to blacklist"
    grep "$cc|ipv4|" "$OUTFOLDER"/.delegated-*-latest.txt | awk -F '|' '{ printf("%s/%d\n", $4, 32-log($5)/log(2)) }' >> "$OUTFOLDER"/BlockedCountryIPv4.txt
    # grep "$cc|ipv6|" "$OUTFOLDER"/.delegated-*-latest.txt | awk -F '|' '{ printf("%s/%d\n", $4, $5) }' >> "$OUTFOLDER"/BlockedCountryIPv6.txt
  fi
done < "$OUTFOLDER"/.country_code.txt
cat "$OUTFOLDER/BlockedCountryIPv4.txt" | sort | uniq > "$OUTFOLDER/BlockedCountryIPv4.txt1"
# cat "$OUTFOLDER/BlockedCountryIPv6.txt" | sort | uniq > "$OUTFOLDER/BlockedCountryIPv6.txt1"

echo "Generated $OUTFOLDER/BlockedCountryIPv4.txt1"
# echo "Generated $OUTFOLDER/BlockedCountryIPv6.txt"
echo "Consolidating IPv4 list"
mapcidr -cl "$OUTFOLDER/BlockedCountryIPv4.txt1" -aggregate > "$OUTFOLDER/BlockedCountryIPv4.txt"

# Generate ipset file
touch "$OUTFILE"
echo "create BlockedCountryIPv4Tmp hash:net family inet hashsize 4096 maxelem 1000000" >> "$OUTFILE"
while read cidr; do
  echo "add BlockedCountryIPv4Tmp $cidr" >> "$OUTFILE"
done < "$OUTFOLDER/BlockedCountryIPv4.txt"

echo "Resulting ipset in [$OUTFILE] with ipset-name [BlockedCountryIPv4Tmp]"
echo "done"

