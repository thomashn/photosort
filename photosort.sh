#!/usr/bin/env bash
# This script takes photos and videos from a folder,
# checks it for duplicates and puts it into a
# sorted folder.


set -o pipefail
set -o nounset


MONITOR=$1
if [ ! -d "${MONITOR}" ]; then
    echo "Directory $MONITOR does not exists"; exit 1
fi
PROCESSING="${MONITOR}/.processing"
ARCHIVE=$2
if [ ! -d "${ARCHIVE}" ]; then
    echo "Directory $ARCHIVE does not exists"; exit 1
fi


# We don't want multiple processes at once
LOCK=/tmp/photosort_$(basename "${MONITOR}").lock
if [ -f "$LOCK" ]; then
    if ps | grep $(cat "$LOCK"); then
        echo "Photo sorting already running"; exit 1
    fi
fi
echo "$$" > $LOCK



if [ ! -d "$PROCESSING" ]; then
   echo "Creating dir processing directory $(pwd)/$PROCESSING"
   mkdir "$PROCESSING"
fi


FILES=$(find "$MONITOR" -maxdepth 1 -iregex '.*\.\(mp4\|mov\|jpg\)')
if [[ -z "$FILES" ]]; then
    echo "No new files where found in $(pwd)/$MONITOR"
else
    # If somebody is transfering something; we don't want to interfere.
    # The assumption is that if files are open, the script should not
    # do anything. 
    if lsof $FILES | grep ' REG '; then
        echo "Files are in use"; rm $LOCK; exit 1
    fi

    # Files are moved to another folde since we don't want changes to occur
    # during processing. Moving should be done on the same filesystem; keeping
    # it somewhat "atomic".
    for FILE in $FILES; do
        echo "Moving $FILE to $PROCESSING for processing"
        mv "$FILE" "$PROCESSING"
    done
fi


# Unless you are very orderly, you probably have transfered some of the 
# photos before.
echo "Looking for duplicates in $(pwd)/$PROCESSING against $(pwd)/$ARCHIVE ..."
DUPES=$(fdupes -r "$PROCESSING" "$ARCHIVE" | grep "${PROCESSING}"/)
if [[ -z "$DUPES" ]]; then
    echo "No duplicates where found in $(pwd)/$PROCESSING"
else
    for DUPE in $DUPES; do
        echo "Removing duplicate $DUPE"
        rm "$DUPE"
    done
fi


# We want to enforce our own naming scheme on all the files placed into the 
# archive folder.
exiftool -P -d "$ARCHIVE/%Y/%m/%Y%m%d_%H%M%S" -ext mov -ext jpg \
    '-FileName<${CreateDate}%-c.%le' \
    '-FileName<${DateTimeOriginal}%-c.%le' \
    "$PROCESSING"


# When we are done, we also want to cleanup the monitor folder
# so that people may add entire folders, as this eases the whole
# copy process.
EMPTY_DIRS=$(find "$MONITOR" -type d -empty \( ! -iname ".*" \))
if [ ! -z "${EMPTY_DIRS}" ]; then
    rmdir "${EMPTY_DIRS}"
fi

rm $LOCK
