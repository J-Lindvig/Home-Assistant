#!/bin/bash
source /config/shell/tools.sh
source /config/shell_secrets.txt

# Greentel
greentel_get() {
  _parsehub_get_data $PARSEHUB_GREENTEL_TOKEN $TEMP_PATH/greentel.json

  _send_data "{\"state\": \"$(date +%s)\", \"attributes\": $(cat $TEMP_PATH/greentel.json)}" $BASE_URL$API_STATES_PATH/sensor.greentel

  rm -f $TEMP_PATH/greentel.json
}

greentel_scrape() {
  _parsehub_start_scrape \
    $PARSEHUB_GREENTEL_URL \
    $PARSEHUB_GREENTEL_TOKEN \
    $PARSEHUB_GREENTEL_CREDENTIALS
}