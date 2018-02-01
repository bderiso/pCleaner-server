#!/bin/bash

#Exit on error
set -e

#Debug Mode
set -x

# Premium tier only
#OUTFILE_FORMAT_LIST='mp3,flac,wav'

# Basic Tier
OUTFILE_FORMAT_LIST='mp3'
AUDIO_FX="$(cat /home/pcc/sox-basic-settings)"

IFS=$'\n',

# Check if any new files have been downloaded
if [ -z $(find /home/pcc/Podcasts/ -path /home/pcc/Podcasts/archive -prune -o -type f -print -quit) ]; then
  echo "$(date -u): No files found."
  exit 0
fi

for INFILE in $(find /home/pcc/Podcasts/ -path /home/pcc/Podcasts/archive -prune -o -type f -print); do

  INFILE_FORMAT=$(printf "$INFILE" | cut -d '?' -f 1 | cut -d '.' -f 2)
  if [ "$INFILE_FORMAT" = m4a ]; then
    echo "$(date -u): Unsupported format: m4a. File will be converted."
    /usr/bin/faad -q "$INFILE"
    rsync --remove-source-files "$INFILE" /home/pcc/Podcasts/archive/
    exit 0
  fi
 
    # file has been closed, process it
    FEED_NAME=$(echo "$INFILE" | cut -d "/" -f5)
    EPISODE_TITLE=$(/home/pcc/.local/bin/greg check -f $FEED_NAME | head -1 | sed "s/^0: //")
    OUTFILE_PATH=/var/www/html/feeds/"$FEED_NAME"
    OUTFILE_NAME=$(echo "$INFILE" | cut -d "/" -f6 | cut -d "." -f1)
  
    # Automatic handling of output formats from a space delimited list
    if [ ! -e "$OUTFILE_PATH" ]; then
      mkdir -p "$OUTFILE_PATH"
    fi

    for OUTFILE_FORMAT in $OUTFILE_FORMAT_LIST; do
      OUTFILE="$OUTFILE_PATH"/"$OUTFILE_NAME"."$OUTFILE_FORMAT"

      unset IFS
      echo "$(date -u):"
      sox -V --no-clobber --norm -t "$INFILE_FORMAT" "$INFILE" "$OUTFILE" $(printf "$AUDIO_FX")
      IFS=$'\n',

      # Insert an <item> linking the processed files to the feed's XML
      ENCLOSURE_TYPE=$(if [ "$OUTFILE_FORMAT" = mp3 ]; then echo 'audio/mpeg'; elif [ "$OUTFILE_FORMAT" = wav ]; then echo 'audio/x-wav'; fi)
      OUTFILE_LENGTH=$(wc -c < "$OUTFILE_PATH"/"$OUTFILE_NAME"."$OUTFILE_FORMAT")
      OUTFILE_LINK=http://PodcastCleaner.com/feeds/"$FEED_NAME"/"$OUTFILE_NAME"."$OUTFILE_FORMAT"
      FEED_RSS="$OUTFILE_PATH"/"$OUTFILE_FORMAT"-feed.rss
      FEED_URL="$(/home/pcc/.local/bin/greg info $FEED_NAME | fgrep url | cut -d ' ' -f 6 | sed 's/feed\:\/\//http\:\/\//')"
      RSS_INFO="$(cat <<EOF
$(curl --silent $FEED_URL | sed "/<item>/q" | sed -nE "s/(.*)(.*<item>)/\1/p" | sed -nE "s/.*(<.*<*image)(.*>)/\1\2/p") \
$(curl --silent $FEED_URL | sed "/<item>/q" | sed -nE "s/(.*)(.*<item>)/\1/p" | sed -nE "s/.*(<.*<*thumbnail)(.*>)/\1\2/p") \
 \

EOF
)"
      RSS_ITEM=$(cat <<EOF
 \
<item>  \
<title>$EPISODE_TITLE</title> \
<link>"$OUTFILE_LINK"</link> \
<enclosure type="$ENCLOSURE_TYPE" url="$OUTFILE_LINK" length="$OUTFILE_LENGTH"/> \
<description></description> \
</item> \
 \

EOF
)
      if [ ! -e "$OUTFILE_PATH"/"$OUTFILE_FORMAT"-feed.rss ]; then
        sed "s/<title>/<title>$FEED_NAME - /" /var/www/html/feeds/template.rss > "$FEED_RSS"
        sed -i '/\/channel/ i\ '$(echo $RSS_INFO)'' "$FEED_RSS" 
      fi

      sed -i '/\/channel/ i\ '"$RSS_ITEM"'' "$FEED_RSS"

    done

  # Prevent future runs against the same file
  rsync --remove-source-files "$INFILE" /home/pcc/Podcasts/archive/

done

unset IFS
