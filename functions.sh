function timestamp()
{
	stat -L -c '%Y' $1
}
function atomic_cp()
{
	dstdir=$(dirname $2)
	if [ ! -d "$dstdir" ]; then
		mkdir -p $dstdir
	fi
	tmpfile=$(mktemp --tmpdir=$CACHETMPDIR)
	cp -L --preserve=all $1 $tmpfile
	mv $tmpfile $2
}
function remove_uncached_files()
{
	diff --old-line-format='' --new-line-format='%L' --unchanged-line-format='' \
		<(cat $1 | sort | uniq) \
		<(find $CACHEROOT -type f | cut -c $((${#CACHEROOT}+1))- | sort | uniq) \
	| while read f; do
		echo $f
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
		echo $f
		rm -rf $CACHEROOT$f
	done
}

# There are actually 3 file lists:
#  - cache_list: files to be cached (param 1 of this func)
#  - WWWROOT: authoritative source
#  - CACHEROOT: cache files
# After sync, CACHEROOT should contain up-to-date files in and only in the intersection of cache_list and WWWROOT.
# So comes the algorithm:
#  1. Remove files in CACHEROOT but not in cache_list
#  2. Remove files in CACHEROOT but not in WWWROOT or not up-to-date
#  3. Copy non-cached files in cache_list to CACHEROOT, if it exists in WWWROOT
#
function sync_from_file_list()
{
	cache_list=$1

	if [ ! -d "$WWWROOT" ]; then
		exit 1
	fi
	if [ ! -d "$CACHEROOT" ]; then
		mkdir -p $CACHEROOT
	fi
	if [ ! -d "$CACHETMPDIR" ]; then
		mkdir -p $CACHETMPDIR
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
			echo $f
			atomic_cp $WWWROOT$f $CACHEROOT$f
		fi
		# cached but expired files have been removed
	done

	rm -f $LOCKFILE
}
