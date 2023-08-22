#!/bin/bash

file=/home/ion/IPv4CountryBlockIpset.txt
IPSET="sudo ipset"

# Exit immediately if a simple command exits with a non-zero status
set -e

function stopError() {
  echo "$1"
  exit 1
}

if [ ! -f "$file" ]; then
  echo "File [$file] does not exist"
  exit 0
fi

head -n1 "$file" | grep 'BlockedCountryIPv4Tmp' >/dev/null || stopError "File [$file] not for ipset [BlockedCountryIPv4Tmp]"

$IPSET -X BlockedCountryIPv4Tmp >/dev/null 2>&1 || echo -n ""

echo "Loading [$file]"
$IPSET restore -f "$file" -exist
echo "done"

echo "done, swapping tmp ipset with real one"
$IPSET swap BlockedCountryIPv4Tmp BlockedCountryIPv4
$IPSET -X BlockedCountryIPv4Tmp
echo "Added ranges to ipset 'BlockedCountryIPv4'"
