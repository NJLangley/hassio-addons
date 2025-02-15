#!/bin/bash
. functions.sh
set -e

CERT_DIR=/data/letsencrypt
WORK_DIR=/data/workdir
CONFIG_PATH=/data/options.json

# Let's encrypt Deets
LE_TERMS=$(jq --raw-output '.lets_encrypt.accept_terms' $CONFIG_PATH)
LE_DOMAINS=$(jq --raw-output '.domains[]' $CONFIG_PATH)
LE_UPDATE="0"

#CloudFlare Deets
export CF_APIKEY=$(jq --raw-output '.cfapikey' $CONFIG_PATH)
export CF_EMAIL=$(jq --raw-output '.cfemail' $CONFIG_PATH)

#-------
DOMAINS=$(jq --raw-output '.domains | join(",")' $CONFIG_PATH)
WAIT_TIME=$(jq --raw-output '.seconds' $CONFIG_PATH)

#Extract Zone ID for Domain
grabzoneid

#Exract A record ID if one exists already
grabaid

#Grab current ip
IP=$(curl -s "https://ipinfo.io/ip")

echo "1"
#Create A Record or update existing with current IP
if [ -z "$AID" ]
  then
    echo "1A"
    createarecord
  else
    echo "1B"
    updateip $IP
fi

# Register/generate certificate if terms accepted
echo "2"

function le_renew() {
    local domain_args=()
    # Prepare domain for Let's Encrypt
    for domain in $LE_DOMAINS; do
        domain_args+=("--domain" "$domain")
    done
    dehydrated --cron --hook ./hooks.sh --challenge dns-01 "${domain_args[@]}" --out "$CERT_DIR" --config "$WORK_DIR/config" || true
    LE_UPDATE="$(date +%s)"
}

if [ "$LE_TERMS" == "true" ]; then
    echo "2A"
    
    # Init folder structs
    mkdir -p "$CERT_DIR"
    mkdir -p "$WORK_DIR"

    # Generate new certs
    if [ ! -d "$CERT_DIR/live" ]; then
        echo "2B"
        # Create empty dehydrated config file so that this dir will be used for storage
        touch "$WORK_DIR/config"
        dehydrated --register --accept-terms --config "$WORK_DIR/config"
    fi
fi

# Loop: Watch for new IP and update. Renew Cert after 30 days
while true; do
    echo "Checking IP..."
    NEWIP=$(curl -s "https://ipinfo.io/ip")

    if [ "$IP" != "$NEWIP" ]; then
      echo "Updating IP..."
      updateip $NEWIP
      echo "Updated IP"
    fi

    echo "Checking if certificate needs updating..."
    now="$(date +%s)"
    if [ "$LE_TERMS" == "true" ] && [ $((now - LE_UPDATE)) -ge 43200 ]; then
        echo "Updating certificate..."
        le_renew
        echo "Updated certificate..."
    fi
    sleep "$WAIT_TIME"
done
