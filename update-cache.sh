#!/bin/bash
# should run after every mirror is updated
# Usage: ./update-cache.sh <mirror-name-in-www-root>
# If you want to sync all files, use "all" as param

. $(dirname $0)/config.sh

mirror=$1
if [ -z "$mirror" ]; then
	echo "please specify mirror name"
	exit 1
fi
if [ "$mirror" == "all" ]; then
	mirror=""
fi

tmpfile=$(mktemp)
cachepath="$CACHEROOT/$mirror"
find $cachepath | cut -c $((${#cachepath}+1))- >$tmpfile

# if this file is run before today's cron...
if [ -f "$LOGDIR/tocache-$today" ]; then
	cat $LOGDIR/tocache-$today >>$tmpfile
else
	cat $LOGDIR/tocache-$(date --date="1 day ago" '+%Y%m%d') >>$tmpfile
fi

sync_from_file_list $tmpfile
rm -f $tmpfile
