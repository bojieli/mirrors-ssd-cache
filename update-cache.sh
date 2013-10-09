#!/bin/bash
# should run after every mirror is updated
# Usage: ./update-cache.sh <mirror-name-in-www-root>

. $(dirname $0)/config.sh

mirror=$1
if [ -z "$mirror" ]; then
	exit 1
fi

TMPFILE=$(mktemp)
cachepath="$CACHEROOT/$mirror"
find $cachepath | cut -c $((${#cachepath}+1))- >$TMPFILE

rsync -a --delete --files-from=$TMPFILE $WWWROOT/$mirror $CACHEROOT/$mirror

rm -f $TMPFILE
