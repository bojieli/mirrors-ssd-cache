#!/bin/bash
# should run after every mirror is updated
# Usage: ./update-cache.sh <mirror-name-in-www-root>
# If you want to sync all files, use "all" as param

. $(dirname $0)/config.sh

mirror="${1%/}"
if [ -z "$mirror" ]; then
    echo "please specify mirror name"
    exit 1
fi
if [ "$mirror" == "all" ]; then
    mirror=""
elif [ ! -d "$WWWROOT/$mirror" ]; then
    echo "directory $WWWROOT/$mirror does not exist"
    exit 1
else
    WWWROOT=$WWWROOT/$mirror
    CACHEROOT=$CACHEROOT/$mirror
    CACHETMPDIR=$CACHETMPDIR/$mirror
fi

if [ -f "$LOGDIR/tocache-$today" ]; then
    tocache_list=$LOGDIR/tocache-$today
else # today's cron has not run...
    tocache_list=$LOGDIR/tocache-$(date --date="1 day ago" '+%Y%m%d') 
fi

if [ -z "$mirror" ]; then # full update
    sync_from_file_list $tocache_list
else # update one mirror
    tmpfile=$(mktemp /tmp/mirror.XXXXXXX)

    trap "rm -f $tmpfile" EXIT

    grep "^/$mirror/" $tocache_list | cut -c $((${#mirror}+2))- >$tmpfile
    sync_from_file_list $tmpfile
fi

