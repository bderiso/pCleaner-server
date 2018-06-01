#!/bin/bash

# Exit on error
set -e

# Debug Mode
#set -x

# Set the Internal File Separator to newlines only
IFS=$'\n'

# Check dependecies & install if needed
if [ ! -z $(command -v faad) ];
 then echo;
 else echo "faad not installed, we will install it now.";
 brew install faad2;
fi

if [ ! -z $(command -v sox) ];
 then echo;
 else echo "sox not installed, we will install it now.";
 brew install sox;
fi

# Find & variablize the installed path for dependecies
FAAD=$(command -v faad)
SOX=$(command -v sox)

# Setting locations
# Input directory
IN_DIR=~pcc/Podcasts
# Output directory
OUT_DIR=/var/www/html/feeds
# Audio Settings
FX=~pcc/pCleaner-settings

# Check that IN_DIR, OUT_DIR & FX exist; if not then make them
if [ ! -e "$IN_DIR" ]; then
  echo "Creating the input directory: $IN_DIR"
  mkdir -p "$IN_DIR"
fi

if [ ! -e "$OUT_DIR" ]; then
  echo "Creating the output directory: $OUT_DIR"
  mkdir -p "$OUT_DIR"
fi

if [ ! -e "$FX" ]; then
  echo "Generating the audio settings file: $FX"
  cp ./pCleaner-settings.template "$FX"
fi

# Check if this script is running on MacOS, and if so then clean up the Input Directory 
if [ $(uname -s) = Darwin ]; then
  find "$IN_DIR" -name ".DS_Store" -delete
fi

# Check if any new files have been downloaded; if zero then exit
if [ -z $(find "$IN_DIR" -path "$IN_DIR"/archive -prune -o -type f -print -quit) ]; then
  echo "$(date -u): No new files found in $IN_DIR"
  exit 0
fi

# Find the first file in the input directory & send it through the audio processing then loop/repeat until no files are found
for INFILE in $(find "$IN_DIR" -path "$IN_DIR"/archive -prune -o -type f -print); do
  
  # Check the format of the file, if it is M4A then it will need to be converted due ot a limitation with sox
  # If the file is M4A, it will be converted to WAV using faad and then restart the script
  INFILE_FORMAT=$(printf "${INFILE##*.}")
  if [ "$INFILE_FORMAT" = m4a ]; then
    echo "Unsupported format: m4a. File will be converted."
    "$FAAD" -q "$INFILE"
    rsync --remove-source-files "$INFILE" "$IN_DIR"/archive/
    exec "$0"
  fi

  OUTFILE_NAME=$(printf "$INFILE" | awk -F/ '{print $NF}' | cut -d "." -f 1)

  # Automatic handling of output formats from a space delimited list
  OUTFILE_FORMAT_LIST='wav'
  for OUTFILE_FORMAT in $OUTFILE_FORMAT_LIST; do
    OUTFILE="$OUT_DIR"/"$OUTFILE_NAME"."$OUTFILE_FORMAT"

  echo "$(date -u):"

  # This is where the magic happens
  source ~/pCleaner-settings
  "$SOX" -V --no-clobber -t "$INFILE_FORMAT" "$INFILE" "$OUTFILE" highpass "$HP" lowpass "$LP" mcompand "$AD $K:$T,$R -6 $F" 160 "$AD $K:$T,$R -6 $F" 1000 "$AD $K:$T,$R -6 $F" 8000 "$AD $K:$T,$R -6 $F" gain -n -2
  done

  # Prevent future runs against the same file by moving out of the way
  rsync --remove-source-files "$INFILE" "$IN_DIR"/archive/

  if [ -e ./feed-processing.sh ]; then
    ./feed-processing.sh
  fi

done

unset IFS
