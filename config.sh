#!/bin/bash

NGINXLOGDIR=/var/log/nginx/mirrors
LOGDIR=/var/log/ssd-cache-log
WWWROOT=/srv/www
CACHEROOT=/mnt/ssd/cache
TMPROOT=/tmp/ssd
LOCKFILE=/tmp/ssd-cache.lock
cachesize=$((1024*1024*1024*200)) # 200G

today=$(date +'%Y%m%d')

function timestamp()
{
	stat -L -c '%X' $1
}
function atomic_cp()
{
	echo "$2"
	dstdir=$(dirname $2)
	if [ ! -d "$dstdir" ]; then
		mkdir -p $dstdir
	fi
	tmpfile=$(mktemp --tmpdir=$dstdir)
	cp -L --preserve=all $1 $tmpfile
	mv $tmpfile $2
}
function remove_uncached_files()
{
	diff --old-line-format='' --new-line-format='%L' --unchanged-line-format='' \
		<(cat $1 | sort | uniq) \
		<(find $CACHEROOT -type f | cut -c $((${#CACHEROOT}+1))- | sort | uniq) \
	| while read f; do
		echo $CACHEROOT$f
		rm -rf $CACHEROOT$f
	done
}
function remove_expired_files()
{
	find $CACHEROOT -type f | cut -c $((${#CACHEROOT}+1))- \
	| while read f; do
		if [ -f "$WWWROOT$f" ] && [ "$(timestamp $WWWROOT$f)" == "$(timestamp $CACHEROOT$f)" ]; then
			continue
		fi
		echo $CACHEROOT$f
		rm -rf $CACHEROOT$f
	done
}
function sync_from_file_list()
{
	cache_list=$1

	if [ ! -d "$WWWROOT" ]; then
		exit 1
	fi
	if [ ! -d "$CACHEROOT" ]; then
		mkdir -p $CACHEROOT
	fi

	lockfile -r0 -l 86400 $LOCKFILE 2>/dev/null
	if [[ 0 -ne "$?" ]]; then
		echo "Waiting for $LOCKFILE..."
		lockfile -r-1 -l 86400 $LOCKFILE
		if [[ 0 -ne "$?" ]]; then
			exit 1
		fi
	fi

	echo "===== Removing no longer cached (swapped out) files ====="
	remove_uncached_files $cache_list

	echo "===== Removing expired files ====="
	remove_expired_files

	echo "===== Synchronizing new files ====="
	cat $cache_list | while read f; do
		if [ ! -f "$WWWROOT$f" ]; then # source file not exist or is a directory
			continue
		fi
		if [ -d "$CACHEROOT$f" ]; then # it was a directory, now a file
			rm -rf $CACHEROOT$f
		fi
		if [ ! -f "$CACHEROOT$f" ]; then # file not cached
			atomic_cp $WWWROOT$f $CACHEROOT$f
		fi
		# cached but expired files have been removed
	done

	rm -f $LOCKFILE
}
