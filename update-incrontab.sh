#!/bin/bash

if [ ! -f "$1" ]; then
	echo "filelist $1 does not exist"
	exit 1
fi

. $(dirname $0)/config.sh
if [ ! -d "$CACHEROOT" ] || [ ! -d "$WWWROOT" ]; then
	exit 1
fi

tmpfile=$(mktemp)
cat $1 | sed 's/\/*[^\/]*\/*$//' | sort | uniq | \
while read watchdir; do
	# do not watch IN_MODIFY because rsync will write temp files many times
	# and non-temp files will be atomically deleted or moved by rsync
	echo $WWWROOT$watchdir IN_DELETE,IN_MOVE rm -rf $CACHEROOT$watchdir/\$#
done >$tmpfile

incrontab $tmpfile
rm -f $tmpfile
