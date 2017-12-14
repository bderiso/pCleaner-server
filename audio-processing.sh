#!/bin/bash
set -x
set -e

OUTFILE_FORMAT_LIST='wav mp3'

#Update podcasts & download any new episodes
~pcc/.local/bin/greg sync

# Check if any new files have been downloaded
if [ ! -n $(/usr/bin/find ~pcc/Podcasts/ -name "*.mp3" -print -quit) ]; then
  echo "No files found."
  exit 0
fi

for infile in $(/usr/bin/find ~pcc/Podcasts/ -name "*.mp3"); do

  #Make sure the file isn't already being processed
  until status=$(/usr/bin/lsof $infile 2>&1 > /dev/null); do
    if [ ! -n "$status" ]; then
      # lsof printed an error string, file may or may not be open
      break
    fi
    # lsof returned 1 but didn't print an error string, assume the file is open
    sleep 1
  done
  
  if [ -z "$status" ]; then
  # file has been closed, process it
  FEED_NAME=$(echo $infile | cut -d "/" -f5)
  OUTFILE_PATH=/var/www/html/feeds/$FEED_NAME
  OUTFILE_NAME=$(echo $infile | cut -d "/" -f6 | cut -d "." -f1)

    # Automatic handling of output formats from a space delimited list
    if [ ! -e $OUTFILE_PATH ]; then
      mkdir -p $OUTFILE_PATH
    fi

    for FORMAT in $OUTFILE_FORMAT_LIST; do
      OUTFILE=$OUTFILE_PATH/$OUTFILE_NAME.$FORMAT
      sox --norm $infile $OUTFILE $(/bin/cat ~pcc/sox-basic-settings)
  
      #Insert an <item> linking the processed files to the feed's XML
      RSS_ITEM=$(cat <<EOF
 \
<item>  \
<title>$FEED_NAME - PodCast Cleaner feed</title> \
<link>http://$(hostname -i)/feeds/$FEED_NAME/$OUTFILE_NAME.$FORMAT</link> \
<enclosure type="$(if [ $FORMAT = mp3 ]; then echo 'audio/mpeg'; elif [ $FORMAT = wav ]; then echo 'audio/x-wav'; fi)" url="http://$(hostname -i)/feeds/$FEED_NAME/$OUTFILE_NAME.$FORMAT" length="$(wc -c < $OUTFILE_PATH/$OUTFILE_NAME.$FORMAT)"/> \
<description>$FEED_NAME - $(date -u)</description> \
</item> \
 \

EOF
)
      if [ ! -e $OUTFILE_PATH/$FORMAT-feed.rss ]; then
        cp /var/www/html/feeds/feeds.rss $OUTFILE_PATH/$FORMAT-feed.rss
      fi

      sed -i '/\/channel/ i\ '"$RSS_ITEM"'' $OUTFILE_PATH/$FORMAT-feed.rss

    done
  fi

  #Prevent future runs against the same file. Maybe we should just archive it instead of removing?
  rm $infile

done
