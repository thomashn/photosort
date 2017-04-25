#!/usr/bin/env bash
# This script takes photos and videos from a folder,
# checks it for duplicates and puts it into a
# sorted folder.


set -o pipefail
set -o nounset


MONITOR=$1
echo "Monitor directory $1"
if [ ! -d "${MONITOR}" ]; then
    echo "Directory $MONITOR does not exists"; exit 1
fi
PROCESSING="${MONITOR}/.processing"
ARCHIVE=$2
echo "Archive into directory $2"
if [ ! -d "${ARCHIVE}" ]; then
    echo "Directory $ARCHIVE does not exists"; exit 1
fi


# We don't want multiple processes at once
LOCK=$(echo /tmp/photosort_$(basename "${MONITOR}").lock | tr " " "_")
echo "Check lock $LOCK"
if [ -f "$LOCK" ]; then
    if ps | grep $(cat "$LOCK"); then
        echo "Photo sorting already running"; exit 1
    fi
fi
echo "$$" > "$LOCK"



if [ ! -d "$PROCESSING" ]; then
   echo "Creating dir processing directory $(pwd)/$PROCESSING"
   mkdir "$PROCESSING"
fi


function move_only_closed {
    OPEN=$(lsof "$MONITOR" | grep ' REG ')
    while read FILE; do
        if echo "$OPEN" | grep "$FILE"; then
            echo "$FILE is in use"
        else
            echo "Moving $FILE to $1"
            mv "$FILE" "$1"
        fi
    done
}
find "$MONITOR" -maxdepth 1 -iregex '.*\.\(mp4\|mov\|jpg\)' | move_only_closed "$PROCESSING" "$MONITOR"


# Unless you are very orderly, you probably have transfered some of the 
# photos before.
fdupes -r "$PROCESSING" "$ARCHIVE" | grep "${PROCESSING}" | while read FILE; do 
    echo "Removing duplicate $FILE"
    rm "$FILE"
done

# We want to enforce our own naming scheme on all the files placed into the 
# archive folder.
exiftool -P -d "${ARCHIVE}/%Y/%m/%Y%m%d_%H%M%S" -ext mov -ext jpg \
    '-FileName<${CreateDate}%-c.%le' \
    '-FileName<${DateTimeOriginal}%-c.%le' \
    "$PROCESSING"


# When we are done, we also want to cleanup the monitor folder
# so that people may add entire folders, as this eases the whole
# copy process.
find "$MONITOR" -type d -empty \( ! -iname ".*" \) -delete

rm "$LOCK"
