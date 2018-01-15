#!/bin/bash
IFS=$'\n',
set -e
#set -x

# Premium tier only
#OUTFILE_FORMAT_LIST='wav,mp3'

# Basic Tier
OUTFILE_FORMAT_LIST='mp3'

# Timestamp the logs
echo "$(date -u):"

# Update podcasts & download any new episodes
/home/pcc/.local/bin/greg sync

# Check if any new files have been downloaded
if [ ! -n "$(find /home/pcc/Podcasts/ -path /home/pcc/Podcasts/archive -prune -o -type f -print -quit)" ]; then
  echo "$(date -u): No files found."
  exit 0
fi

for INFILE in $(find /home/pcc/Podcasts/ -path /home/pcc/Podcasts/archive -prune -o -type f -print); do

  # Make sure the file isn't already being processed
  until STATUS=	$(lsof "$INFILE" 2>&1 > /dev/null); do
    if [ ! -n "$STATUS" ]; then
      # lsof printed an error string, file may or may not be open
      break
    fi
    # lsof returned 1 but didn't print an error string, assume the file is open
   exit 1 
  done
  
  if [ -z "$STATUS" ]; then
  # file has been closed, process it
  FEED_NAME=$(echo "$INFILE" | cut -d "/" -f5)
  OUTFILE_PATH=/var/www/html/feeds/"$FEED_NAME"
  OUTFILE_NAME=$(echo "$INFILE" | cut -d "/" -f6 | cut -d "." -f1)

    # Automatic handling of output formats from a space delimited list
    if [ ! -e "$OUTFILE_PATH" ]; then
      mkdir -p "$OUTFILE_PATH"
    fi

    for FORMAT in $OUTFILE_FORMAT_LIST; do
      OUTFILE="$OUTFILE_PATH"/"$OUTFILE_NAME"."$FORMAT"

      IFS=$'\n'
#      I don't know why this stopped working, but it no longer parses the effects proerly; it tries to read them as an infile...
#      sox --norm $INFILE $OUTFILE "$(cat ~pcc/sox-basic-settings)"
      echo "$(date -u):"
      sox -V --norm $INFILE $OUTFILE
      IFS=$'\n',

      # Insert an <item> linking the processed files to the feed's XML
      ENCLOSURE_TYPE=$(if [ "$FORMAT" = mp3 ]; then echo 'audio/mpeg'; elif [ "$FORMAT" = wav ]; then echo 'audio/x-wav'; fi)
      OUTFILE_LENGTH=$(wc -c < "$OUTFILE_PATH"/"$OUTFILE_NAME"."$FORMAT")
      OUTFILE_LINK=http://$(hostname -i)/feeds/"$FEED_NAME"/"$OUTFILE_NAME"."$FORMAT"
      RSS_ITEM=$(cat <<EOF
 \
<item>  \
<title>"$FEED_NAME" - PodCast Cleaner Feed</title> \
<link>"$OUTFILE_LINK"</link> \
<enclosure type="$ENCLOSURE_TYPE" url="$OUTFILE_LINK" length="$OUTFILE_LENGTH"/> \
<description>"$FEED_NAME" - $(date -u)</description> \
</item> \
 \

EOF
)
      if [ ! -e "$OUTFILE_PATH"/"$FORMAT"-feed.rss ]; then
        cp /var/www/html/feeds/feeds.rss "$OUTFILE_PATH"/"$FORMAT"-feed.rss
      fi

      sed -i '/\/channel/ i\ '"$RSS_ITEM"'' "$OUTFILE_PATH"/"$FORMAT"-feed.rss

    done
  fi

  # Prevent future runs against the same file
  rsync --remove-source-files "$INFILE" ~/Podcasts/archive/

done

unset IFS
