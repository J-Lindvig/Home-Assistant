#!/bin/bash

source /config/shell/tools.sh
source /config/shell_secrets.txt

rm -f tmp_file movies_file movie_urls_file cover_file

movie_query=""
movie_url_query=""
movie_cover_query=""

curl $NAS_MOVIE_URL -o tmp_file
grep "i_file.gif" tmp_file | cut -d'>' -f9 | cut -d'<' -f1> movie_urls_file
grep "i_file.gif" tmp_file | cut -d'>' -f9 | cut -d'.' -f1> movies_file

movie_query="{\"entity_id\":\"input_select.movie\",\"options\":["
cnt=0
while read line; do
  cnt=$((cnt+1))
  if [[ "$cnt" -gt 1 ]]; then
    movie_query="$movie_query,"
  fi
  movie_query="$movie_query\"$line\""
done < movies_file
movie_query="$movie_query]}"

movie_url_query="{\"entity_id\":\"input_select.movie_url\",\"options\":["
cnt=0
while read line; do
  cnt=$((cnt+1))
  if [[ "$cnt" -gt 1 ]]; then
    movie_url_query="$movie_url_query,"
  fi
  movie_url_query="$movie_url_query\"$NAS_MOVIE_URL$line\""
done < movie_urls_file
movie_url_query="$movie_url_query]}"

movie_cover_query="{\"entity_id\":\"input_select.movie_cover\",\"options\":["
cnt=0
while read line; do
  cnt=$((cnt+1))

  file="$IMAGE_PATH$line.jpg"

  if [ ! -f "/config/www/$file" ]; then
    curl -G \
      --silent \
      --data-urlencode "s=tt" \
      --data-urlencode "q=$line" \
      "https://www.imdb.com/find" -o cover_file

    cover_url=`grep "primary_photo" cover_file | cut -d'>' -f4 | cut -d'=' -f2 | cut -d'"' -f2 | sed -r 's/V1_.*_AL/V1_SY1000_SX640_AL/g'`

    if [ ${#cover_url} -ge 5 ]; then
      curl "$cover_url" -o "/config/www/$file"
    else
      file="$IMAGE_PATH$UNKNOWN_COVER"
    fi
  fi

  if [[ "$cnt" -gt 1 ]]; then
    movie_cover_query="$movie_cover_query,"
  fi

  movie_cover_query="$movie_cover_query\"/local/$file\""
done < movies_file
movie_cover_query="$movie_cover_query]}"

_send_data "$movie_query" "$BASE_URL$API_PATH$INPUT_SELECT"
_send_data "$movie_url_query" "$BASE_URL$API_PATH$INPUT_SELECT"
_send_data "$movie_cover_query" "$BASE_URL$API_PATH$INPUT_SELECT"

rm -f tmp_file movies_file movie_urls_file cover_file