#!/bin/bash

#Extract Zone ID for Domain
function grabzoneid() {

  #Strip Subdomain to get bare domain
  #BASEDOMAIN=$(sed 's/.*\.\(.*\..*\)/\1/' <<< $DOMAIN)

  #Grab Zoneid & Export for Hooks.sh
  export ZONEID=$(curl -sX GET "https://api.cloudflare.com/client/v4/zones" \
    -H "X-Auth-Email: $CF_EMAIL" \
    -H "X-Auth-Key: $CF_APIKEY" \
    -H "Content-Type: application/json" | jq -r --arg DOMAIN "$DOMAIN" '.result[] | (select(.name | contains($DOMAIN))) | .id')
}

#Grab id from existing A record
function grabaid() {

  ARECORD=$(curl -sX GET "https://api.cloudflare.com/client/v4/zones/$ZONEID/dns_records" \
    -H "X-Auth-Email: $CF_EMAIL"\
    -H "X-Auth-Key: $CF_APIKEY"\
    -H "Content-Type: application/json" | jq -r --arg DOMAIN "$DOMAIN" '.result[] | (select(.name | contains($DOMAIN))) | (select (.type | contains("A"))) | {id:.id, ip:.content}')

  AID=$(echo $ARECORD | jq -r '.id')
  AIP=$(echo $ARECORD | jq -r '.ip')
}

#Create A record
function createarecord() {

  curl -sX POST "https://api.cloudflare.com/client/v4/zones/$ZONEID/dns_records"\
    -H "X-Auth-Email: $CF_EMAIL"\
    -H "X-Auth-Key: $CF_APIKEY"\
    -H "Content-Type: application/json"\
    --data '{"type":"A","name":"'$DOMAIN'","content":"'$IP'","proxied":false}' -o /dev/null

echo "A record created for $DOMAIN at $IP"

}

#Update A record IP address
function updateip() {

  curl -sX PUT "https://api.cloudflare.com/client/v4/zones/$ZONEID/dns_records/$AID"\
    -H "X-Auth-Email: $CF_EMAIL"\
    -H "X-Auth-Key: $CF_APIKEY"\
    -H "Content-Type: application/json"\
    --data '{"type":"A","name":"'$DOMAIN'","content":"'$1'","proxied":false}' -o /dev/null

  echo "Updated $DOMAIN with IP: $1"

}
