#!/bin/bash

OUTFOLDER=/config/user-data/edgeos-bl-mgmt/country
IPSET="sudo ipset"

# Exit immediately if a simple command exits with a non-zero status
set -e
file=$OUTFOLDER/PeristedIpsetAllowedCountryIPv4.txt

if [ ! -f "$file" ]; then
  echo "File [$file] does not exist. Run [generateCountry_IpBlocks.sh] to generate it..."
  exit 0
fi

echo "Loading [$file]"
$IPSET restore -f "$file"
echo "done"
