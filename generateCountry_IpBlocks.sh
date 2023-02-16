#!/bin/bash

OUTFOLDER=/config/user-data/edgeos-bl-mgmt/country
IPSET="sudo ipset"

# Exit immediately if a simple command exits with a non-zero status
set -e

[ ! -d "$OUTFOLDER" ] && mkdir -p "$OUTFOLDER"

# Download data from registries 
curl --silent https://ftp.apnic.net/stats/apnic/delegated-apnic-latest --output "$OUTFOLDER"/.delegated-apnic-latest.txt
curl --silent https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest --output "$OUTFOLDER"/.delegated-arin-extended-latest.txt
curl --silent https://ftp.ripe.net/ripe/stats/delegated-ripencc-latest --output "$OUTFOLDER"/.delegated-ripencc-latest.txt
curl --silent https://ftp.afrinic.net/pub/stats/afrinic/delegated-afrinic-latest --output "$OUTFOLDER"/.delegated-afrinic-latest.txt
curl --silent https://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-latest --output "$OUTFOLDER"/.delegated-lacnic-latest.txt

# Generate country codes
# awk -F '|' '{ print $2 }' "$OUTFOLDER"/.delegated-*-latest.txt | sort | uniq | grep -E '[A-Z]{2}' > "$OUTFOLDER"/.country_code.txt

# Generate country ip blocks
echo "" > "$OUTFOLDER"/AllowedCountryIPv4.txt
echo "" > "$OUTFOLDER"/AllowedCountryIPv6.txt
while read cc; do 
    echo "Generating $cc"
    grep "$cc|ipv4|" "$OUTFOLDER"/.delegated-*-latest.txt | awk -F '|' '{ printf("%s/%d\n", $4, 32-log($5)/log(2)) }' >> "$OUTFOLDER"/AllowedCountryIPv4.txt
    grep "$cc|ipv6|" "$OUTFOLDER"/.delegated-*-latest.txt | awk -F '|' '{ printf("%s/%d\n", $4, $5) }' >> "$OUTFOLDER"/AllowedCountryIPv6.txt
done <<< "$(cat allowed-country-codes.txt | sed 's/#.*//g' | egrep -v '\s+|^$')"
cat "$OUTFOLDER/AllowedCountryIPv4.txt" | sort | uniq > "$OUTFOLDER/AllowedCountryIPv4.txt1"
cat "$OUTFOLDER/AllowedCountryIPv6.txt" | sort | uniq > "$OUTFOLDER/AllowedCountryIPv6.txt1"

echo "Generated $OUTFOLDER/AllowedCountryIPv4.txt"
echo "Generated $OUTFOLDER/AllowedCountryIPv6.txt"
echo "Consolidating IPv4 list"
cat "$OUTFOLDER/AllowedCountryIPv4.txt1" | aggregate -q > "$OUTFOLDER/AllowedCountryIPv4.txt"
mv "$OUTFOLDER/AllowedCountryIPv6.txt1" "$OUTFOLDER/AllowedCountryIPv6.txt"
echo "done"

################

$IPSET -N AllowedCountryIPv4 hash:net maxelem 1000000 >/dev/null 2>&1 || echo -n ""
$IPSET -X AllowedCountryIPv4Tmp >/dev/null 2>&1 || echo -n ""

[ -f "$OUTFOLDER/.ipset_tmp.txt" ] && rm "$OUTFOLDER/.ipset_tmp.txt"
touch "$OUTFOLDER/.ipset_tmp.txt"
echo "create AllowedCountryIPv4Tmp hash:net family inet hashsize 4096 maxelem 1000000" >> "$OUTFOLDER/.ipset_tmp.txt"

while read cidr; do
  echo "add AllowedCountryIPv4Tmp $cidr" >> "$OUTFOLDER/.ipset_tmp.txt"
done < "$OUTFOLDER/AllowedCountryIPv4.txt"

echo "Loading generated ipset file"
ipset restore -f "$OUTFOLDER/.ipset_tmp.txt"
echo "done"

echo "done, swapping tmp ipset with real one"
$IPSET swap AllowedCountryIPv4Tmp AllowedCountryIPv4
$IPSET -X AllowedCountryIPv4Tmp
echo "Added ranges to ipset 'AllowedCountryIPv4'"

echo "Persisting in file for boot loading"
$IPSET save AllowedCountryIPv4 > "$OUTFOLDER/PeristedIpsetAllowedCountryIPv4.txt"
echo "done"
