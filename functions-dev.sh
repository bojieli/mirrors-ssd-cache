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

    #####
    dstfile=$2
    oriabspath="$(readlink -e $dstfile)"
    ORIGINROOT="${oriabspath%$dstfile}"

    if [ $oriabspath != $ORIGINROOT$dstfile ]; then  # origin file is link

        linktoname="${oriabspath#$ORIGINROOT}"
        if [ ! -f $CACHEROOT$linktoname ]; then
            linktodir="$(dirname $CACHEROOT$linktoname)"
            [ ! -d "$linktodir" ] && mkdir -p "$linktodir"
            cp --preserve=all $oriabspath $tmpfile
            mv $tmpfile $dstfile
        fi

        # add --force. in case that the link has been modified 
        # to point to other place
        ln -sf $CACHEROOT$linktoname $CACHEROOT$dstfile 
    else
        cp --preserve=all $oriabspath $tmpfile
        mv $tmpfile $dstfile
    fi
    #####
}

#####
function try_delete()
{
    # FIXME:
    # If you delete all the symbolic links that point to the same file, let's say F, after you try deleting file F,
    # file F will not be deleted, although it should be.

    f=$1
    if [ ! -L $CACHEROOT$f ]; then
        f_strip_slash="${f#/}"
        repo="${f_strip_slash%%/*}"
        repo="$CACHEROOT/$repo"

        # I assume that links and real files are stored in the same repository
        # so I only search in the repo to accelerate the process
        n=$(find -L "$repo" -samefile "$f" 2>/dev/null |wc -l)

        [ "$n" == "1" ] && rm -rf $CACHEROOT$f   # there is no other symbolic links that point to it
    else
        rm -rf $CACHEROOT$f
    fi
}
#####

function remove_uncached_files()
{
	diff --old-line-format='' --new-line-format='%L' --unchanged-line-format='' \
		<(cat $1 | sort | uniq) \
		<(find $CACHEROOT -type f | cut -c $((${#CACHEROOT}+1))- | sort | uniq) \
	| while read f; do
		echo $f

        #####
        try_delete $f
        #####

        #####
		#rm -rf $CACHEROOT$f
        #####
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
        try_delete $f
        #####

        #####
		#rm -rf $CACHEROOT$f
        #####
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

    ###### what do we need to echo timestamp? For crontab?
	echo_timestamp
    ######

	echo "===== Removing no longer cached (swapped out) files ====="
	remove_uncached_files $cache_list

	echo_timestamp
	echo "===== Removing expired files ====="
	remove_expired_files

	echo_timestamp
	echo "===== Synchronizing new files ====="
	cat $cache_list | while read f; do
        #####
		#if [ ! -f "$WWWROOT$f" ]; then # source file not exist or is a directory
		#	continue
		#fi
        #####

        # source file not exist or is a directory
        ##### just simplify, no big deal
        [ ! -f "$WWWROOT$f" ] && continue 
        #####

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
