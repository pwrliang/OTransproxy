#!/bin/bash
WORKPLACE=$(dirname "$0")
VERSION_FILE="$WORKPLACE/version"
ACCELERATED_DOMAINS="$WORKPLACE/accelerated-domains.china.txt"
CHNROUTE="$WORKPLACE/chnroute.txt"

echo "# RULE  NUM  DATE" > "$VERSION_FILE"

echo 'Generating "accelerated-domains.china"'
if wget --no-check-certificate \
        --timeout=8 \
        -qO- \
        https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf \
        | sed '/^#/d' | cut -d "/" -f 2 | sort | uniq > "$ACCELERATED_DOMAINS"; then
  echo "Ok"
  echo "ACCELERATED_DOMAINS $(wc -l < "$ACCELERATED_DOMAINS")    $(date)" >> "$VERSION_FILE"
else
  echo "Error"
  rm "$ACCELERATED_DOMAINS" >/dev/null 2>&1
  exit 1
fi

echo 'Generating "CHNROUTE"'
if wget --no-check-certificate \
        --timeout=8 \
        -qO- \
        https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/ipip_country/ipip_country_cn.netset \
        | sed '/^#/d' | sort | uniq > "$CHNROUTE"; then
  echo "Ok"
  echo "CHNROUTE $(wc -l < "$CHNROUTE")    $(date)" >> "$VERSION_FILE"
else
  echo "Error"
  rm "$CHNROUTE" >/dev/null 2>&1
  exit 1
fi

