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
# Load the secrets
source /config/shell_secrets.txt

# HALF MAST DAYS
GOOD_FRIDAY="Langfredag"
GERMAN_OCCUPATION_DAY="9-4"

# NORDIC NATIONALDAYS
GREENLAND="Grønland"
FAROE_ISLANDS="Færø"

# IMAGES
FLAG_IMAGE_PATH="/local/images/flags/"
DENMARK_IMAGE="Denmark.png"
GREENLAND_IMAGE="Greenland.png"
FAROE_ISLANDS_IMAGE="Faroe_Islands.png"

# Initial cleanup
rm -f $TEMP_PATH/flag_tmp_file $TEMP_PATH/combined_file

# Fetch the HTML page
curl https://designflag.dk/om-flag/flagdage/ -o $TEMP_PATH/flag_tmp_file

# Extract the Year
# Result ex: "2020"
YEAR=$(grep "<h1>Officielle flagdage" $TEMP_PATH/flag_tmp_file | cut -d' ' -f3 | cut -d'<' -f1)

# Extract the data - combine the 2 columns on 1 line - store in a file
grep '<td style="text-align: left;" valign="top" width="102">\|<td style="text-align: left;" valign="top" width="550">' $TEMP_PATH/flag_tmp_file | cut -d'>' -f2 | cut -d'<' -f1 | awk 'NF' | sed '{N; s/\n/|/}' > $TEMP_PATH/combined_file

# Prepare the placeholders
STATE=-1
QUERY=""
ATTR="\"events\": [ "
NOW_IN_DAYS=$(( ($(date +"%s") / 86400) -1 ))

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
    NEW_STATE=$(( ($TIMESTAMP / 86400) - $NOW_IN_DAYS ))

    # Is the new event today or in the future
    if [[ $NEW_STATE -ge 0 ]]; then

      # Set the state of the next event
      STATE=$NEW_STATE
      
      # Prepare the main part of the query
      # ( substract days in advance )
      QUERY="{ \"state\": \"$NEW_STATE\", \"attributes\": { \"date\": \"$DATE\", \"event\": \"$EVENT\", \"timestamp\": \"$TIMESTAMP\", \"icon\": \"mdi:flag\", \"friendly_name\": \"`echo $EVENT | cut -d'.' -f1`\""

      # IMAGE
      QUERY="$QUERY, \"entity_picture\": \"$FLAG_IMAGE_PATH"
      if [[ `echo $EVENT | grep $GREENLAND; echo $?` ]]; then
        if [[ `echo $EVENT | grep $FAROE_ISLANDS; echo $?` ]]; then
          QUERY="$QUERY$DENMARK_IMAGE\""
        else
          QUERY="$QUERY$FAROE_ISLANDS_IMAGE\""
        fi
      else
        QUERY="$QUERY$GREENLAND_IMAGE\""
      fi

      # GOOd FRIDAY...?
      QUERY="$QUERY, \"half_mast_all_day\": "
      if [[ `echo $EVENT | grep $GOOD_FRIDAY; echo $?` ]]; then
        QUERY="$QUERY false"
      else
        QUERY="$QUERY true"
      fi

      # GERMAN_OCCUPATION_DAY
      QUERY="$QUERY, \"half_mast_end_time\": "
      if [ "$DAY-$MONTH" = $GERMAN_OCCUPATION_DAY ]; then
        QUERY="$QUERY \"12:00:00\""
      else
        QUERY="$QUERY false"
      fi
    fi
  fi

  # Append the data of the event
  ATTR="$ATTR{ \"date\": \"$DATE\", \"event\": \"$EVENT\", \"timestamp\": \"$TIMESTAMP\""

  # GOOd FRIDAY...?
  ATTR="$ATTR, \"half_mast_all_day\": "
  if [ `echo $EVENT | grep $GOOD_FRIDAY; echo $?` ]; then
    ATTR="$ATTR false"
  else
    ATTR="$ATTR true"
  fi

  # GERMAN_OCCUPATION_DAY
  ATTR="$ATTR, \"half_mast_end_time\": "
  if [ "$DAY-$MONTH" = $GERMAN_OCCUPATION_DAY ]; then
    ATTR="$ATTR \"12:00:00\""
  else
    ATTR="$ATTR false"
  fi

  ATTR="$ATTR, \"entity_picture\": \"$FLAG_IMAGE_PATH"
  if [[ `echo $EVENT | grep $GREENLAND; echo $?` ]]; then
    if [[ `echo $EVENT | grep $FAROE_ISLANDS; echo $?` ]]; then
      ATTR="$ATTR$DENMARK_IMAGE\""
    else
      ATTR="$ATTR$FAROE_ISLANDS_IMAGE\""
    fi
  else
    ATTR="$ATTR$GREENLAND_IMAGE\""
  fi

  ATTR="$ATTR },"

done < $TEMP_PATH/combined_file

# Finish the query
QUERY="$QUERY, ${ATTR:0:-1} ] } }"

# Send the query to the API
_send_data "$QUERY" "$BASE_URL$API_STATES_PATH/sensor.flagday_dk"

# Cleanup on exit
#rm -f $TEMP_PATH/flag_tmp_file $TEMP_PATH/combined_file