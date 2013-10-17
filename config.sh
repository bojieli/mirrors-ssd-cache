#!/bin/bash

NGINXLOGDIR=/var/log/nginx/mirrors
LOGDIR=/var/log/ssd-cache-log
WWWROOT=/srv/www
CACHEROOT=/mnt/ssd/cache
TMPROOT=/tmp/ssd
cachesize=$((1024*1024*1024*200)) # 200G

today=$(date +'%Y%m%d')

function sync_from_file_list()
{
	rm -rf $TMPROOT
	mkdir -p $TMPROOT

	cat $1 | while read f; do
		if [ -f $WWWROOT$f ]; then
			if [ ! -d $(dirname $TMPROOT$f) ]; then
				mkdir -p $(dirname $TMPROOT$f)
			fi
			ln -s $WWWROOT$f $TMPROOT$f
		fi
	done
	
	rsync -a --copy-links --delete $TMPROOT/ $CACHEROOT/
	
	rm -rf $TMPROOT
}
