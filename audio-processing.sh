#!/bin/bash

#Exit on error
set -e

#Debug Mode
#set -x

# Premium tier only
#OUTFILE_FORMAT_LIST='mp3,flac,wav'

# Basic Tier
OUTFILE_FORMAT_LIST='mp3'
AUDIO_FX="$(cat /home/pcc/sox-basic-settings)"

IFS=$'\n',

# Check if any new files have been downloaded
if [ ! -n "$(find /home/pcc/Podcasts/ -path /home/pcc/Podcasts/archive -prune -o -type f -print -quit)" ]; then
  echo "$(date -u): No files found."
  exit 0
fi

for INFILE in "$(find /home/pcc/Podcasts/ -path /home/pcc/Podcasts/archive -prune -o -type f -print)"; do

  # Make sure the file isn't already being processed
  until STATUS=	$(lsof "$INFILE" 2>&1 > /dev/null); do
    if [ ! -n "$STATUS" ]; then
      # lsof printed an error string, file may or may not be open
      break
    fi
    # lsof returned 1 but didn't print an error string, assume the file is open
    exit 1 
  done
 
  INFILE_FORMAT=$(printf "$INFILE" | cut -d '?' -f 1 | cut -d '.' -f 2)
  if [ "$INFILE_FORMAT" = m4a ]; then
    echo "$(date -u): Unsupported format: m4a. File will be converted."
    /usr/bin/faad "$INFILE"
    rsync --remove-source-files "$INFILE" /home/pcc/Podcasts/archive/
    exit 0
  fi
 
  if [ -z "$STATUS" ]; then
    # file has been closed, process it
    FEED_NAME=$(echo "$INFILE" | cut -d "/" -f5)
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
      sox -V --norm -t "$INFILE_FORMAT" "$INFILE" "$OUTFILE" $(printf "$AUDIO_FX")
      IFS=$'\n',

      # Insert an <item> linking the processed files to the feed's XML
      ENCLOSURE_TYPE=$(if [ "$OUTFILE_FORMAT" = mp3 ]; then echo 'audio/mpeg'; elif [ "$OUTFILE_FORMAT" = wav ]; then echo 'audio/x-wav'; fi)
      OUTFILE_LENGTH=$(wc -c < "$OUTFILE_PATH"/"$OUTFILE_NAME"."$OUTFILE_FORMAT")
      OUTFILE_LINK=http://$(hostname -i)/feeds/"$FEED_NAME"/"$OUTFILE_NAME"."$OUTFILE_FORMAT"
      FEED_RSS="$OUTFILE_PATH"/"$OUTFILE_FORMAT"-feed.rss
      FEED_URL="$(/home/pcc/.local/bin/greg info 'Moon Eye Music Hour' | fgrep url | cut -d ' ' -f 6 | sed 's/feed/http/')"
      RSS_IMAGE=$(cat <<'EOF'
"$(curl --silent "$FEED_URL" | fgrep -A4 '<image>')" \
 \
EOF
)
      RSS_ITEM=$(cat <<'EOF'
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
      if [ ! -e "$OUTFILE_PATH"/"$OUTFILE_FORMAT"-feed.rss ]; then
        sed 's/<title>/<title>$FEED_NAME - /' /var/www/html/feeds/template.rss > "$FEED_RSS"
        sed -i '/\/channel/ i\ '"$RSS_IMAGE"'' "$FEED_RSS" 
      fi

      sed -i '/\/channel/ i\ '"$RSS_ITEM"'' "$FEED_RSS"

    done
  fi

  # Prevent future runs against the same file
  rsync --remove-source-files "$INFILE" /home/pcc/Podcasts/archive/

done

unset IFS
