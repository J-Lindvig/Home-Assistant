#!/bin/bash

# TOOLS
# I have a bunch of tools in a separate file
# Essentially you will only need this function:
#
# _send_data
# $1 = query
# $2 = URL
# _send_data() {
#   curl -X POST \
#   -H "Accept: application/json" \
#   -H "Authorization: Bearer $APITOKEN" \
#   -H "Content-Type: application/json" \
#   -d "$1" \
#   $2
# }
#
# Load the tools
source /config/shell/tools.sh

# CONST
# I stored my shell-secrets in "/config/shell_secrets.txt"
# These are the needed secrets:
#
# APITOKEN="YOUR TOKEN"
# API_STATES_PATH="api/states"
# BASE_URL="http://YOUR_HA_IP:8123/"
# TEMP_PATH="temp"
#
# Load the secrets
source /config/shell_secrets.txt

# Have we provided a "Days in advance"?
# No, then 0
if [ -z "$1" ]; then
  DAYS_IN_ADVANCE=0
else
  DAYS_IN_ADVANCE=$1
fi

# Initial cleanup
rm -f $TEMP_PATH/flag_tmp_file $TEMP_PATH/combined_file

# Fecth the HTML page
curl https://designflag.dk/om-flag/flagdage/ -o $TEMP_PATH/flag_tmp_file

# Extract the Year
YEAR=$(grep "<h1>Officielle flagdage 2020</h1>" $TEMP_PATH/flag_tmp_file | cut -d' ' -f3 | cut -d'<' -f1)

# Extract the data - combine the 2 columns on 1 line - store in a file
grep '<td style="text-align: left;" valign="top" width="102">\|<td style="text-align: left;" valign="top" width="550">' $TEMP_PATH/flag_tmp_file | cut -d'>' -f2 | cut -d'<' -f1 | awk 'NF' | sed '{N; s/\n/|/}' > $TEMP_PATH/combined_file

# Prepare the placeholders
STATE=-1
QUERY=""
ATTR="\"events\": [ "
CNT=0
NOW=$(date +"%s")
while read line; do

  # Extract the day
  DAY=$(echo "$line" | cut -d'.' -f1)

  # Extract the month and convert it to number
  MONTH=$(case $(echo "$line" | cut -d' ' -f2 | cut -d'|' -f1) in
      januar)     echo 1;;
      februar)    echo 2;;
      marts)      echo 3;;
      april)      echo 4;;
      maj)        echo 5;;
      juni)       echo 6;;
      juli)       echo 7;;
      august)     echo 8;;
      september)  echo 9;;
      oktober)    echo 10;;
      november)   echo 11;;
      december)   echo 12;;
  esac)
  
  # Calculate the timestamp
  TIMESTAMP=$(date -d "$YEAR-$MONTH-$DAY" +"%s")

  # Format date in proper manner
  DATE=$(date -d "$YEAR-$MONTH-$DAY" +"%d-%m-%Y")

  # Extract the description of the event
  EVENT=$(echo "$line" | cut -d'|' -f2)

  # Check events until we have found the first event in the future
  if [[ $STATE -lt 0 ]]; then

    # Calculate days to the next event
    NEW_STATE=$(( ($TIMESTAMP - $NOW)/(60*60*24) ))

    # Is the new event today or in the future
    if [[ $NEW_STATE -ge 0 ]]; then

      # Set the state of the next event
      STATE=$NEW_STATE
      
      # Prepare the main part of the query
      # ( substract days in advsnce )
      QUERY="{ \"state\": \"$(($NEW_STATE - $DAYS_IN_ADVANCE))\", \"attributes\": { \"next_date\": \"$DATE\", \"next_event\": \"$EVENT\", \"next_timestamp\": \"$TIMESTAMP\", \"days_in_advance\": \"$DAYS_IN_ADVANCE\", \"icon\": \"mdi:flag\""
    fi
  fi

  # Load all events
  # Have been here before....? Add ","
  CNT=$((CNT+1))
  if [[ $CNT -gt 1 ]]; then
    ATTR="$ATTR, "
  fi

  # Append the data of the event
  ATTR="$ATTR{ \"date\": \"$DATE\", \"event\": \"$EVENT\", \"timestamp\": \"$TIMESTAMP\" }"

done < $TEMP_PATH/combined_file

# Finish the query
QUERY="$QUERY, $ATTR ] } }"

echo $QUERY > $TEMP_PATH/log

# Send the query to the API
_send_data "$QUERY" "$BASE_URL$API_STATES_PATH/sensor.flagday_dk"

# Cleanup on exit
rm -f $TEMP_PATH/flag_tmp_file $TEMP_PATH/combined_file