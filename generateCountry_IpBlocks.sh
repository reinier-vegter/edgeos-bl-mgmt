#!/bin/bash

OUTFOLDER=/config/user-data/edgeos-bl-mgmt/country
IPSET="sudo ipset"

# Exit immediately if a simple command exits with a non-zero status
set -e

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
done <<< "$(cat allowed-country-codes.txt | sed 's/#.*//g' | egrep -v '\s+|^$')"

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

echo "Generated $OUTFOLDER/BlockedCountryIPv4.txt"
echo "Generated $OUTFOLDER/BlockedCountryIPv6.txt"
echo "Consolidating IPv4 list"
cat "$OUTFOLDER/BlockedCountryIPv4.txt1" | aggregate -q > "$OUTFOLDER/BlockedCountryIPv4.txt"
# mv "$OUTFOLDER/BlockedCountryIPv6.txt1" "$OUTFOLDER/BlockedCountryIPv6.txt"
echo "done"

################

$IPSET list BlockedCountryIPv4 >/dev/null # Check if already exists. If it doesn't manually create it (README).
$IPSET -X BlockedCountryIPv4Tmp >/dev/null 2>&1 || echo -n ""

[ -f "$OUTFOLDER/.ipset_tmp.txt" ] && rm "$OUTFOLDER/.ipset_tmp.txt"
touch "$OUTFOLDER/.ipset_tmp.txt"
echo "create BlockedCountryIPv4Tmp hash:net family inet hashsize 4096 maxelem 1000000" >> "$OUTFOLDER/.ipset_tmp.txt"

while read cidr; do
  echo "add BlockedCountryIPv4Tmp $cidr" >> "$OUTFOLDER/.ipset_tmp.txt"
done < "$OUTFOLDER/BlockedCountryIPv4.txt"

echo "Loading generated ipset file"
ipset restore -f "$OUTFOLDER/.ipset_tmp.txt"
echo "done"

echo "done, swapping tmp ipset with real one"
$IPSET swap BlockedCountryIPv4Tmp BlockedCountryIPv4
$IPSET -X BlockedCountryIPv4Tmp
echo "Added ranges to ipset 'BlockedCountryIPv4'"

echo "Persisting in file for boot loading"
$IPSET save BlockedCountryIPv4 > "$OUTFOLDER/PersistedIpsetBlockedCountryIPv4.txt"
echo "done"
