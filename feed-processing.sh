EPISODE_TITLE=$(~pcc/.local/bin/greg check -f $FEED_NAME | head -1 | sed "s/^0: //")
OUTFILE_NAME=$(printf "$INFILE" | awk -F/ '{print $NF}' | cut -d "." -f 1)

echo "$(date -u):"

# Insert an <item> linking the processed files to the feed's XML
ENCLOSURE_TYPE=$(if [ "$OUTFILE_FORMAT" = mp3 ]; then echo 'audio/mpeg'; elif [ "$OUTFILE_FORMAT" = wav ]; then echo 'audio/x-wav'; fi)
OUTFILE_LENGTH=$(wc -c < "$OUTFILE")
OUTFILE_LINK=http://PodcastCleaner.com/feeds/"$FEED_NAME"/"$OUTFILE_NAME"."$OUTFILE_FORMAT"
FEED_RSS="$OUTFILE_PATH"/"$OUTFILE_FORMAT"-feed.rss

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
