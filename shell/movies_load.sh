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
# API_PATH="api/services/"
# BASE_URL="http://YOUR_HA_IP:8123/"
# INPUT_SELECT="input_select/set_options"
# IMAGE_PATH="images/covers/"
# NAS_MOVIE_URL="http://YOUR_NAS_IP/PATH_TO_MOVIES/"
# TEMP_PATH="temp"
# UNKNOWN_COVER="unknown.jpg"
#
# Load the secrets
source /config/shell_secrets.txt

# CLEANUP
_cleanup() {
  rm -f $TEMP_PATH/movies_tmp_file $TEMP_PATH/movies_file $TEMP_PATH/movie_urls_file $TEMP_PATH/movies_cover_file $TEMP_PATH/movies_chapters.txt
}

# INIT
_init() {
  _cleanup

  # Fetch the HTML-page with the movies
  # adjust to your needs
  curl $NAS_MOVIE_URL -o $TEMP_PATH/movies_tmp_file
  
  # Do some grep and cut magic to turn this:
  # <a href="Adventures%20Of%20Tintin.mp4"><img src="/MyWeb/template/i_file.gif" alt="[   ]"></a></td><td><a href="Adventures%20Of%20Tintin.mp4">Adventures Of Tintin.mp4</a>
  # into this:
  # Adventures Of Tintin.mp4
  # Adventures Of Tintin
  # 
  # grep "i_file.gif" == find lines with "i_file.gif" string in it.
  # Cut the found string i pieces using ">" as delimiter
  # and return instance number 9.
  #
  # URLS
  # Cut this string by "<" and return the first
  #
  # Titles
  # Cut this string by "." and return the first
  #
  # Save output in 2 files
  grep "i_file.gif" $TEMP_PATH/movies_tmp_file | cut -d'>' -f9 | cut -d'<' -f1 > $TEMP_PATH/movie_urls_file
  grep "i_file.gif" $TEMP_PATH/movies_tmp_file | cut -d'>' -f9 | cut -d'.' -f1 > $TEMP_PATH/movies_file
}

load_all_movies() {
  load_movies
  load_movie_urls
  load_movie_covers
  _cleanup
}

# Load movie titles from txt file, form a JSON query
# and send it to HomeAssistant
load_movies() {
  # prepare the query
  #
  # make a online, paste....
  # replace the | with json delimiter ","
  # finish the query
  movie_query="{\"entity_id\":\"input_select.movie\",\"options\":[\"$(cat $TEMP_PATH/movies_file | paste -sd '|' - | sed 's/|/\",\"/g')\"]}"

  # Send the query wth a API call
  _send_data "$movie_query" "$BASE_URL$API_PATH$INPUT_SELECT"
}

load_movie_urls() {
  # Prepare the query string
  #
  # Add NAS_MOVIE_URL at the begining of the line with "awk -v nas="$NAS_MOVIE_URL" '{print nas$0}'""
  # Simple urlencode "sed 's/ /%20/g'"
  # Make a oneliner separeted with | "paste -sd '|' - "
  # Replace | with JSON delimiter "sed "s/|/\",\"/g""
  # Finish the query
  movie_url_query="{\"entity_id\":\"input_select.movie_url\",\"options\":[\"$(cat $TEMP_PATH/movie_urls_file | awk -v nas="$NAS_MOVIE_URL" '{print nas$0}' | sed 's/ /%20/g' | paste -sd '|' - | sed "s/|/\",\"/g")\"]}"

  _send_data "$movie_url_query" "$BASE_URL$API_PATH$INPUT_SELECT"
}

# Fetch the cover of the movie from iMDB
# if no cover use the $UNKNOWN_COVER
load_movie_covers() {
  # Read the movietitles
  while read line; do
    # Initialize the image file with the title and path
    file="$IMAGE_PATH$line.jpg"

    # If the image is not present, then fetch the iMDB
    # HTML page found when searching for the title
    if [ ! -f "/config/www/$file" ]; then
      curl -G \
        --silent \
        --data-urlencode "s=tt" \
        --data-urlencode "q=$line" \
        "https://www.imdb.com/find" -o $TEMP_PATH/movies_cover_file

      # Extract the URL of the primary image and change the dimensions
      cover_url=`grep "primary_photo" $TEMP_PATH/movies_cover_file | cut -d'>' -f4 | cut -d'=' -f2 | cut -d'"' -f2 | sed -r 's/V1_.*_AL/V1_UX400_CR0,0,400,566_AL/g'`

      # If the URL is greater then 5 chars, then we found a URL
      # and we should now download it to the www folder
      #
      # Else use the unknown cover 
      if [ ${#cover_url} -ge 5 ]; then
        curl "$cover_url" -o "/config/www/$file"
      else
        file="$IMAGE_PATH$UNKNOWN_COVER"
      fi
    fi

    movie_cover_query="$movie_cover_query,\"/local/$file\""
  done < $TEMP_PATH/movies_file
  movie_cover_query="{\"entity_id\":\"input_select.movie_cover\",\"options\":[${movie_cover_query:1}]}"

_send_data "$movie_cover_query" "$BASE_URL$API_PATH$INPUT_SELECT"
}

load_timecodes() {
  # Initial cleanup

  rm -f $TEMP_PATH/movies_chapters.txt
#  if file_exists_web "$1"; then
    # Extract the metadata from the given URL, store it in movies_chapters.txt
    ffmpeg -i "$1" -f ffmetadata $TEMP_PATH/movies_chapters.txt
  
    # Exctract the timebase - often 1/1000, but not allways
    timebase=$(grep -m 1 "TIMEBASE" $TEMP_PATH/movies_chapters.txt | cut -d'/' -f2)

    # Extract the timecodes ( Start of chapters) and divide it with the timebase
    timecodes=$(grep "START" $TEMP_PATH/movies_chapters.txt | cut -d'=' -f2 | awk -v t="$timebase" '{print $1/t}' | tr '\n' ',' | sed 's/.$//')

    # Extract the end of the last chapter ( duration )
    # and divide it with the timebase
    duration=$(tac $TEMP_PATH/movies_chapters.txt | grep -m 1 "END" | cut -d'=' -f2 | awk -v t="$timebase" '{print $1/t}')

    # Cleanup
    rm -f $TEMP_PATH/movies_chapters.txt
  
    # Append duration to timecode and echo it to the sensor
    echo $timecodes","$duration
#  fi
}

# PRIVATE CALLS
_init