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
    #####
	#cp -L --preserve=all $1 $tmpfile
	#mv $tmpfile $2
    #####

    
    ##### Explanation
    # 1. find out the *REAL* path of $dstfile and store it in $oriabspath
    # 2. if original file is a link, then
    #        if the file that is pointed to has not been cached
    #            1. copy the original file and the dirs that contains it to ssd cache
    #            2. create a symbolic link in $dstfile and let it points to the cached original file
    #        if the file has been cached
    #            1. just create the link
    #    if original file is an ordinary file
    #        just copy
    #####

    #####
    dstfile=$2

    oriabspath="$(readlink -e $dstfile)"
    [ -z $oriabspath ] && return  # broken link or file not exist. In genernal, should never get here

    ORIGINROOT="${oriabspath%$dstfile}"

    if [ $oriabspath != $ORIGINROOT$dstfile ]; then  # original file is a link
        linktoname="${oriabspath#$ORIGINROOT}"
        if [ ! -f $CACHEROOT$linktoname ]; then
            linktodir="$(dirname $CACHEROOT$linktoname)"
            [ ! -d "$linktodir" ] && mkdir -p "$linktodir"
            cp --preserve=all $oriabspath $tmpfile
            mv $tmpfile $dstfile
        fi

        # add --force. in case that the link has been modified to point to other place
        ln -sf $CACHEROOT$linktoname $CACHEROOT$dstfile 
    else
        cp --preserve=all $oriabspath $tmpfile
        mv $tmpfile $dstfile
    fi
    #####
}

function remove_uncached_files()
{
	diff --old-line-format='' --new-line-format='%L' --unchanged-line-format='' \
		<(cat $1 | sort | uniq) \
		<(find $CACHEROOT -type f | cut -c $((${#CACHEROOT}+1))- | sort | uniq) \
	| while read f; do
		echo $f

        #####
        # No matter it is a real file or a link, just remove it.
        # try_files in nginx will handle the error case properly.
        #####

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

        #####
        # No matter it is a real file or a link, just remove it.
        # try_files in nginx will handle the error case properly.
        #####

		rm -rf $CACHEROOT$f
	done
}
function echo_timestamp()
{
	date '+===== TIMESTAMP %s %F %T ====='
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
	if [ ! -f "$cache_list" ]; then
		echo "cache list $cache_list does not exist"
		exit 1
	fi
	if [ ! -d "$WWWROOT" ]; then
		echo "WWWROOT $WWWROOT does not exist"
		exit 1
	fi
	mkdir -p $CACHEROOT
	mkdir -p $CACHETMPDIR

	LOCKFILE=$CACHETMPDIR/sync.lock
	lockfile -r0 -l 86400 $LOCKFILE 2>/dev/null
	if [[ 0 -ne "$?" ]]; then
		echo_timestamp
		echo "===== Waiting for $LOCKFILE ====="
		lockfile -r-1 -l 86400 $LOCKFILE
		if [[ 0 -ne "$?" ]]; then
			exit 1
		fi
	fi

	echo_timestamp

	echo "===== Removing no longer cached (swapped out) files ====="
	remove_uncached_files $cache_list

	echo_timestamp
	echo "===== Removing expired files ====="
	remove_expired_files

	echo_timestamp

    #####
	echo "===== Removing broken links ====="
    find $CACHEROOT -type l -xtype l -delete
    #####

	echo "===== Synchronizing new files ====="
	cat $cache_list | while read f; do
		[ ! -f "$WWWROOT$f" ] && continue # source file not exist or is a directory

		if [ -d "$CACHEROOT$f" ]; then # it was a directory, now a file
			rm -rf $CACHEROOT$f
		fi

		if [ ! -f "$CACHEROOT$f" ]; then # file not cached
			echo $f
			atomic_cp $WWWROOT$f $CACHEROOT$f
		fi
		# cached but expired files have been removed
	done

	echo_timestamp
	rm -f $LOCKFILE
}
