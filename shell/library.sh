#!/bin/bash
# TOOLS
# I have a bunch of tools in a separate file
# Essentially you will only need these functions:
#
# # $1 = query
# # $2 = URL
# _send_data() {
#   curl -X POST \
#   -H "Accept: application/json" \
#   -H "Authorization: Bearer $APITOKEN" \
#   -H "Content-Type: application/json" \
#   -d "$1" \
#   $2
# }
#
# # Start a Parsehub Scraper
# # 1: Start URL for scraper
# # 2: Project ID
# # 3: Start values aka login credentials
# _parsehub_start_scrape() {
#   curl -X POST \
#     -d "api_key=$PARSEHUB_API_TOKEN" \
#     -d "start_url=$1" \
#     -d "start_value_override=$3" \
#     -d "send_email=0" \
#     "https://www.parsehub.com/api/v2/projects/$2/run"
# }
#
# # PARSEHUB_API_TOKEN
# # $PARSEHUB_LIBRARY_TOKEN
# # File
# _parsehub_get_data() {
#   rm -f "$2"
#   curl -X GET "https://www.parsehub.com/api/v2/projects/$1/last_ready_run/data?api_key=$PARSEHUB_API_TOKEN" | gunzip > "$2"
# }
#
# Load the tools
source /config/shell/tools.sh

# CONST
# I stored my shell-secrets in "/config/shell_secrets.txt"
# These are the needed secrets:
#
# APITOKEN="YOUR TOKEN TO YOUR HOME ASSISTANT"
# API_STATES_PATH="api/states"
# BASE_URL="http://YOUR_HA_IP:8123/"
# TEMP_PATH="temp"
# PARSEHUB_LIBRARY_TOKEN="YOUR PROJECT TOKEN"
# PARSEHUB_LIBRARY_URL="https://bibliotek.dk/"
# PARSEHUB_USERS_FILE="/config/shell/library_users.txt"
# PARSEHUB_LIBRARY_SLEEP=90
# Load the secrets
source /config/shell_secrets.txt

### BEGIN ###

# Read the users and their credentials and call the functions
library_update() {
  while read line; do
    if [[ ! ${line:0:1} == "#" ]]; then
      TEMP_CREDENTIALS=$(echo $line | awk -F',' '/.*/{ print "{\"mail\":\"" $1 "\",\"password\":\"" $2 "\"}"}')
      TEMP_FRIENDLY_NAME=$(echo $line | awk -F',' '/.*/{ print $3}')
      TEMP_ENTITY_ID=$(echo $line | awk -F',' '/.*/{ print $4}')

      library_scrape "$TEMP_CREDENTIALS"

      sleep $PARSEHUB_LIBRARY_SLEEP
      
      library_get "$TEMP_FRIENDLY_NAME" "$TEMP_ENTITY_ID"
    fi
  done < "$PARSEHUB_USERS_FILE"
}

library_scrape() {
  # Start the scraper with the generic function
  # Takes the following variables:
  # PARSEHUB_LIBRARY_URL
  # PARSEHUB_LIBRARY_TOKEN
  # CREDENTIALS
  _parsehub_start_scrape $PARSEHUB_LIBRARY_URL $PARSEHUB_LIBRARY_TOKEN $1
}

# Get the library loans and send it to HA
# 1: Friendly_name for sensor in HA
# 2: Entity_id for sensor
library_get() {

  # Initial cleanup - just in case
  rm -f "$TEMP_PATH/parsehub_edit_$2.json"

  # Call the generic script for fetching the last run and ready scraping
  # Takes the following variables:
  # PARSEHUB_LIBRARY_TOKEN
  # Path and filename of the output
  _parsehub_get_data "$PARSEHUB_LIBRARY_TOKEN" "$TEMP_PATH/parsehub_$2.json"

  # Parsehub is limited in manipulating the extracted data
  # Here we search for the date in the "Due_In" field and calculate the amount
  # of days to the expiration date of the loan
  # Output is saved in a new file
  sed 's/.*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/|\1/' "$TEMP_PATH/parsehub_$2.json" | while read d; do if [[ ${d:0:1} == "|" ]]; then echo '"Due_In" :"'$(( ($(date -d ${d#?} +%s) - $(date +%s) ) / 86400 ))'",'; else echo $d; fi; done > "$TEMP_PATH/parsehub_edit_$2.json"

  # Set the state to the Due_In value of the first loan - the one with the
  # lowest value.
  # Append the attributes: summary, list of loans and friendly_name
  # Use the generic function and send it to Home Assistant
  _send_data "{\"state\": "$(grep -m 1 "Due_In" "$TEMP_PATH/parsehub_edit_$2.json" | cut -d':' -f2)"\"attributes\": $(cat "$TEMP_PATH/parsehub_edit_$2.json"), \"friendly_name\": \"$1\"}}" "$BASE_URL$API_STATES_PATH/sensor.library_$2"

  # Cleanup on exit  
  rm -f "$TEMP_PATH/parsehub_edit_$2.json" "$TEMP_PATH/parsehub_$2.json"
}