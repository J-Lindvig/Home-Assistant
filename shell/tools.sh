#!/bin/bash

source /config/shell_secrets.txt

# DUCKDNS
duckdns_update() {
  curl "https://www.duckdns.org/update?domains=$DUCKDNS_DOMAINS&token=$DUCKDNS_TOKEN&ip="
}

# SCREEN FUNCTIONS
screen_toggle() {
  ssh $TOUCHPANEL_SSH xset -display :0.0 dpms force $1
}

screen_suspend () {
    PID=$$
  ssh $TOUCHPANEL_SSH "echo $SUDO_PASSWORD | sudo -S systemctl suspend"
  sleep 2
  kill $PID
}

# SELECT
select_set_options() {
  _set_input $1 $BASE_URL$API_PATH$INPUT_SELECT $APITOKEN
}

text_set_values() {
  _set_input $1 $BASE_URL$API_PATH$INPUT_TEXT $APITOKEN

}

var_set_values() {
  _set_variable $1 $BASE_URL$API_PATH$VAR_SET $APITOKEN
}

_set_input() {
  ls $1/*.txt | while read d; do

    query="{\"entity_id\":\"$(head -n 1 $d)\",\"options\":[\"$(sed -n 2p $d)\""

    cnt=0
    while read l; do
      cnt=$((cnt+1))
      if [[ "$cnt" -gt 2 ]]; then
        query="$query,\"$l\""
      fi
    done < "$d"
    query="$query]}"

    echo $query

    curl -X POST \
    -H "Accept: application/json" \
    -H "Authorization: Bearer $3" \
    -H "Content-Type: application/json" \
    -d "$query" \
    $2
  done
}

_set_variable() {
  ls $1/*.txt | while read d; do

    query="{\"entity_id\":\"$(head -n 1 $d)\",\"value\":\"$(sed -n 2p $d)\""

    cnt=0
    while read l; do
      cnt=$((cnt+1))
      if [[ "$cnt" -gt 2 ]]; then
        query="$query,\"$l\""
      fi
    done < "$d"
    query="$query}"

    echo $query

    curl -X POST \
    -H "Accept: application/json" \
    -H "Authorization: Bearer $3" \
    -H "Content-Type: application/json" \
    -d "$query" \
    $2
  done
}

# Greentel
get_greentel() {
  rm -f greentel.json

  curl -X GET "https://www.parsehub.com/api/v2/projects/$PARSEHUB_PROJECT_TOKEN/last_ready_run/data?api_key=$PARSEHUB_API_TOKEN" | gunzip > greentel.json

  curl -X POST \
    -H "Accept: application/json" \
    -H "Authorization: Bearer $APITOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"state\": \"$(date +%s)\", \"attributes\": $(cat greentel.json)}" \
    $BASE_URL$API_STATES_PATH/sensor.greentel_status

  rm -f greentel.json
}

_greentel_scrape() {
  curl -X POST \
    -d "api_key=$PARSEHUB_API_TOKEN" \
    "https://www.parsehub.com/api/v2/projects/$PARSEHUB_PROJECT_TOKEN/run"
}
