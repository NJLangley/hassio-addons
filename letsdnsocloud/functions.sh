#!/bin/bash

#Extract Zone ID for root domain
function grabzoneid() {
  DOMAIN=$1
  ROOTDOMAIN=$(sed 's/.*\.\(.*\..*\)/\1/' <<< $DOMAIN)

  #Grab Zoneid & Export for Hooks.sh
  export ZONEID=$(curl -sX GET "https://api.cloudflare.com/client/v4/zones" \
    -H "X-Auth-Email: $CF_EMAIL" \
    -H "X-Auth-Key: $CF_APIKEY" \
    -H "Content-Type: application/json" | jq -r --arg ROOTDOMAIN "$ROOTDOMAIN" '.result[] | select(.name==$ROOTDOMAIN) | .id')

    # TODO: Add error handling for if the zone does not exist
    # TODO: Add error handling for web request fails
}

#Grab id from existing A record
function grabaid() {
  DOMAIN=$1
  
  # jq was throwing a syntax error when this was done in a single step...
  RESPONSE=$(curl -sX GET "https://api.cloudflare.com/client/v4/zones/$ZONEID/dns_records" \
    -H "X-Auth-Email: $CF_EMAIL"\
    -H "X-Auth-Key: $CF_APIKEY"\
    -H "Content-Type: application/json")
  
  ARECORD=$(echo "$RESPONSE" | jq -r --arg DOMAIN "$DOMAIN" --arg TYPE "A" '.result[] | select((.name==$DOMAIN) and (.type==$TYPE))')
  
  if [ -n "$ARECORD" ]
  then
    AID=$(echo $ARECORD | jq -r '.id')
    AIP=$(echo $ARECORD | jq -r '.content')
  else
    AID=""
    AIP=""
    echo "No A record found for $DOMAIN"
  fi
}

#Create A record
function createarecord() {
  DOMAIN=$1
  IP=$2

  RESPONSE=$(curl -sX POST "https://api.cloudflare.com/client/v4/zones/$ZONEID/dns_records"\
    -H "X-Auth-Email: $CF_EMAIL"\
    -H "X-Auth-Key: $CF_APIKEY"\
    -H "Content-Type: application/json"\
    --data '{"type":"A","name":"'$DOMAIN'","content":"'$IP'","proxied":false}')
  #  | jq
  echo $RESPONSE | jq
  # TODO: Add error handling for web request fails

  echo "A record created for $DOMAIN at $IP"
}

#Update A record IP address
function updateip() {
  DOMAIN=$1
  IP=$2

  #echo "\$IP: $IP"
  #echo "curl -sX PUT \"https://api.cloudflare.com/client/v4/zones/$ZONEID/dns_records/$AID\"\\"
  #echo "-H \"X-Auth-Email: $CF_EMAIL\"\\"
  #echo "-H \"X-Auth-Key: $CF_APIKEY\"\\"
  #echo "-H \"Content-Type: application/json\"\\"
  #echo "--data '{\"type\":\"A\",\"name\":\"'$DOMAIN'\",\"content\":\"'$IP'\",\"proxied\":false}'\\"

  RESPONSE=$(curl -sX PUT "https://api.cloudflare.com/client/v4/zones/$ZONEID/dns_records/$AID"\
    -H "X-Auth-Email: $CF_EMAIL"\
    -H "X-Auth-Key: $CF_APIKEY"\
    -H "Content-Type: application/json"\
    --data '{"type":"A","name":"'$DOMAIN'","content":"'$IP'","proxied":false}')
  #  | jq
  echo $RESPONSE | jq
  # TODO: Add error handling for web request fails

  echo "Updated A record for $DOMAIN with IP: $IP"

}
