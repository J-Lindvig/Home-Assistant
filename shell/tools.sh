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
  rm -f $TEMP_PATH/tmp_file $TEMP_PATH/dates_file $TEMP_PATH/events_file $TEMP_PATH/combined_file
  
  curl https://designflag.dk/om-flag/flagdage/ -o $TEMP_PATH/tmp_file
  
  YEAR=$(grep "<h1>Officielle flagdage 2020</h1>" $TEMP_PATH/tmp_file | cut -d' ' -f3 | cut -d'<' -f1)
 
  grep '<td style="text-align: left;" valign="top" width="102">\|<td style="text-align: left;" valign="top" width="550">' $TEMP_PATH/tmp_file | cut -d'>' -f2 | cut -d'<' -f1 | awk 'NF' | sed '{N; s/\n/|/}' > $TEMP_PATH/combined_file
  
  day=$(echo "26. maj 2020" | cut -d'.' -f1); month=$(echo "26. maj 2020" | cut -d' ' -f2); if [ "$month" = "maj" ]; then month=5; fi; date -d "2020-$month-$day" +"%s"
  
#  grep -E '<td style="text-align: left;" valign="top" width="102">[0-9].*</td>' $TEMP_PATH/tmp_file | cut -d'>' -f2 | cut -d'<' -f1 > $TEMP_PATH/dates_file
  
#  grep -E '<td style="text-align: left;" valign="top" width="550">.*</td>' $TEMP_PATH/tmp_file | cut -d'>' -f2 | cut -d'<' -f1 | awk 'NF' > $TEMP_PATH/events_file
 
#  paste -d '\n' $TEMP_PATH/dates_file $TEMP_PATH/events_file > $TEMP_PATH/combined_file
  
#  cnt=0
  # QUERY="{\"entity_id\": \"sensor.flag_days_DK\", \"events\": [ {"
  #   while read line; do
  #     cnt=$((cnt+1))
  #     if [[ "$cnt" -gt 2 ]]; then
  #       query="$query,\"$l\""
  #     fi
  #   done < "$d"
  #   query="$query}"

#    _send_data "$query" "$2"
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
