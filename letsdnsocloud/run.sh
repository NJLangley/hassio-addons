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

#Grab current ip
OLDIP="0.0.0.0"

# Update the DNS A records if required
function ip_add_or_update() {
    for DOMAIN in $LE_DOMAINS; do
        echo "Checking DNS records for $DOMAIN"

        #Extract Zone ID for Domain
        grabzoneid
        #Exract A record ID if one exists already
        grabaid

        echo "A Record ID:          $AID"
        echo "A Record IP Address:  $AIP"

        #Create A Record or update existing with current IP
        if [ -z "$AID" ]
        then
            createarecord
        elif [ "$AIP" != "$NEWIP" ]
        then
            updateip $NEWIP
        else
            echo "DNS A Record is up to date for $DOMAIN"
        fi

        # Reset the old IP to the current IP
        OLDIP=$NEWIP
    done
}

# Register/generate certificate if terms accepted
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
    # Init folder structs
    mkdir -p "$CERT_DIR"
    mkdir -p "$WORK_DIR"

    # Generate new certs
    if [ ! -d "$CERT_DIR/live" ]; then
        # Create empty dehydrated config file so that this dir will be used for storage
        touch "$WORK_DIR/config"
        dehydrated --register --accept-terms --config "$WORK_DIR/config"
    fi
fi

# Loop: Watch for new IP and update. Renew Cert after 30 days
while true; do

    NEWIP=$(curl -s "https://ipinfo.io/ip")

    if [ "$IP" != "$NEWIP" ]; then
      updateip $NEWIP
    fi

    now="$(date +%s)"
    if [ "$LE_TERMS" == "true" ] && [ $((now - LE_UPDATE)) -ge 43200 ]; then
        le_renew
    fi
    sleep "$WAIT_TIME"
done
