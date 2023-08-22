#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

rm /root/IPv4CountryBlockIpset.txt >/dev/null 2>&1

"$SCRIPT_DIR"/generateBlockedCountryIpset.sh ~/IPv4CountryBlockIpset.txt "$SCRIPT_DIR"/allowed_countries \
  && scp ~/IPv4CountryBlockIpset.txt ion@router:/home/ion/ \
  || /root/scripts/pushbullet.sh "Geo Block" "Failed generating new blocklist"

