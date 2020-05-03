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
  ssh $TOUCHPANEL_SSH -E SSH_Log.log "echo $SUDO_PASSWORD | sudo -S systemctl suspend"
  sleep 2
  kill $PID
}

ssh_test() {
  PATH_TO_VID="http://192.168.0.10/MyWeb/video/Film/Dansk%20tale/Adventures%20Of%20Tintin.mp4"
  PATH_TO_OUT_DIR="/config/www/images/covers"
#  ffmpeg -ss 1024 -i "$PATH_TO_VID" -f image2 -s "640x480" -vframes 1 $PATH_TO_OUT_DIR/Batman.png

  ffmpeg -ss 1024.32 -i "$PATH_TO_VID" -vframes 1 -vf scale=-1:240 out_3.png

}

ssh_test_old() {
  ffmpeg -i http://192.168.0.10/MyWeb/video/Film/Dansk%20tale/Vilde%20Rolf.m4v -f ffmetadata chapters.txt
  cnt=0
  start=""
  while read -r line; do
    a_start=$(echo $line | grep 'START'| cut -d'=' -f2);
    if [ ${#a_start} -ge 1 ]; then
      cnt=$((cnt+1))
      if [[ "$cnt" -gt 1 ]]; then
        start=$start"|"
      fi
      start="$start$((a_start/1000))"
    fi
  done < chapters.txt
  echo $start > start.log
}

# SELECT
select_set_options() {
  _set_input $1 $BASE_URL$API_PATH$INPUT_SELECT
}

text_set_values() {
  _set_input $1 $BASE_URL$API_PATH$INPUT_TEXT

}

var_set_values() {
  _set_variable $1 $BASE_URL$API_PATH$VAR_SET
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

    _send_data "$query" "$2"
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

    _send_data "$query" "$2"
  done
}

# $1 = query
# $2 = URL
_send_data() {
  curl -X POST \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $APITOKEN" \
  -H "Content-Type: application/json" \
  -d "$1" \
  $2
}

# Greentel
get_greentel() {
  rm -f greentel.json

  curl -X GET "https://www.parsehub.com/api/v2/projects/$PARSEHUB_PROJECT_TOKEN/last_ready_run/data?api_key=$PARSEHUB_API_TOKEN" | gunzip > greentel.json

  _send_data "{\"state\": \"$(date +%s)\", \"attributes\": $(cat greentel.json)}" $BASE_URL$API_STATES_PATH/sensor.greentel

  rm -f greentel.json
}

_greentel_scrape() {
  curl -X POST \
    -d "api_key=$PARSEHUB_API_TOKEN" \
    -d "start_url=$PARSEHUB_GREENTEL_URL" \
    -d "start_value_override=$PARSEHUB_GREENTEL_CREDENTIALS" \
    -d "send_email=0" \
    "https://www.parsehub.com/api/v2/projects/$PARSEHUB_PROJECT_TOKEN/run"
}
