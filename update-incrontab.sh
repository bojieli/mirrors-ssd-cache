#!/bin/bash

if [ ! -f "$1" ]; then
    echo "filelist $1 does not exist"
    exit 1
fi

. $(dirname $0)/config.sh
if [ ! -d "$CACHEROOT" ] || [ ! -d "$WWWROOT" ]; then
    exit 1
fi

tmpfile=$(mktemp -p /tmp incron.XXXXXXX)
while read filepath; do
    watchdir="${filepath%/*}"
    # watch IN_MODIFY to fit non-standard sync scripts
        # tradeoff: rsync will write temp files many times, generating many false events
    echo $WWWROOT$watchdir IN_MODIFY,IN_DELETE,IN_MOVE rm -rf $CACHEROOT$watchdir/\$#
done <$1 | sort -u >$tmpfile

incrontab $tmpfile 2>&1
rm -f $tmpfile
