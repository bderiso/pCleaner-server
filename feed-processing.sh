FEED_NAME=$(echo "$INFILE" | cut -d "/" -f5)
FEED_PATH"$OUT_DIR"/"$FEED_NAME"

# The default podcast handler is “greg”, which is handy because we can  use it to query variables about individual feeds.
PODCATCHER=greg

# Let’s check to make sure it exists & install if needed
if [ ! -z $(command -v “$PODCATCHER”) ];
 then 
 PODCATCHER=$(command -v greg)
 else echo "$PODCATCHER not installed, we will install it now."
 pip3 install --user greg
 echo “Please configure some feeds in `$PODCATCHER’ before continuing.”
 exit 0
fi

# If you change which podcast handler is used, then the syntax of the following command will also need to be updated.
EPISODE_TITLE=$(“$PODCATCHER” check -f $FEED_NAME | head -1 | sed "s/^0: //")

OUTFILE_NAME=$(printf "$INFILE" | awk -F/ '{print $NF}' | cut -d "." -f 1)

# Check that FEED_PATH exists; if not then make it
if [ ! -e "$FEED_PATH" ]; then
  echo "Creating the input directory: $FEED_PATH"
  mkdir -p "$FEED_PATH"
fi

echo "$(date -u):"

# Insert an <item> linking the processed files to the feed's XML
ENCLOSURE_TYPE=$(if [ "$OUTFILE_FORMAT" = mp3 ]; then echo 'audio/mpeg'; elif [ "$OUTFILE_FORMAT" = wav ]; then echo 'audio/x-wav'; fi)
OUTFILE_LENGTH=$(wc -c < "$OUTFILE")
OUTFILE_LINK=http://PodcastCleaner.com/feeds/"$FEED_NAME"/"$OUTFILE_NAME"."$OUTFILE_FORMAT"
FEED_RSS="$FEED_PATH"/"$OUTFILE_FORMAT"-feed.rss

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

sed -i '/-->/a '"$RSS_ITEM"'' "$FEED_RSS"
