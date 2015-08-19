#!/bin/bash
function timestamp()
{
    stat -L -c '%Y' $1
}

function parselink()
{
    local orilink="$1"
    local content="$(readlink $1)"
    if [[ $content == .* ]]; then
        # relative path
        echo "$(dirname $orilink)/$content"
    else
        # absolute path
        echo "$content"
    fi
}

function atomic_cp()
{
    local dstdir="$(dirname $2)"
    [ ! -d "$dstdir" ] && mkdir -p "$dstdir"
    ##### Explanation
    # 1. $linktofile stands for the path of $dstfile in $CACHEROOT
    # 2. if original file is a link
    #        if the file that is pointed to hasn't been cached
    #            create the dir that contains it in SSD and copy the original file to the dir
    #            copy the original link
    #        elif the file has been cached
    #            copy the original link
    #    elif original file is an ordinary file
    #        copy
    #####

    if [ -L "$1" ]; then

        local linktofile="$(parselink $2)"

        if [[ ! -e $linktofile ]]; then
            local containdir="$(dirname $linktofile)"
            [[ ! -d $containdir ]] && mkdir -p "$containdir"

            local tmpfile="$(mktemp --tmpdir=$CACHETMPDIR)"
            cp --preserve=all -L "$1" "$tmpfile"
            mv "$tmpfile" "$linktofile"
            #local tmpfile="$(mktemp -u --tmpdir=$CACHETMPDIR)"
            #echo cp --preserve=all -L "$1" "$tmpfile"
            #echo mv "$tmpfile" "$linktofile"
        fi

        # copy link
        cp -P --preserve=all "$1" "$2"
        #echo cp -P --preserve=all "$1" "$2"
    else
        local tmpfile="$(mktemp --tmpdir=$CACHETMPDIR)"
        #local tmpfile="$(mktemp -u --tmpdir=$CACHETMPDIR)"
        cp --preserve=all $1 $tmpfile
        mv $tmpfile $2
        #echo "cp --preserve=all $1 $tmpfile"
        #echo "mv $tmpfile $2"
    fi
}

function remove_uncached_files()
{
    local tmpfile="$(mktemp --tmpdir=$CACHETMPDIR keep.XXXXXXXXXX)"
    cp $1 $tmpfile
    while read f; do
        if [ -L "$CACHEROOT$f" ]; then
            local abspath="$(readlink -e $CACHEROOT$f)"
            [ -n "$abspath" ] && echo "${abspath#$CACHEROOT}" >> $tmpfile
        fi
    done < $1

    diff --old-line-format='' --new-line-format='%L' --unchanged-line-format='' \
        <(cat $tmpfile | sort -u) \
        <(find $CACHEROOT -type f -o -type l | cut -c $((${#CACHEROOT}+1))- | sort -u) \
    | while read f; do

        echo $f
        rm -rf "$CACHEROOT$f"
    done
    rm $tmpfile
}
function remove_expired_files()
{
    find $CACHEROOT -type f -o -type l | cut -c $((${#CACHEROOT}+1))- \
    | while read f; do
        if [ -f "$WWWROOT$f" ] && [ "$(timestamp $WWWROOT$f)" == "$(timestamp $CACHEROOT$f)" ]; then
            continue
        fi

        echo $f
        rm -rf "$CACHEROOT$f"
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
    if [ ! -d "$CACHEROOT" ]; then
        echo "CACHEROOT $CACHEROOT does not exist"
        exit 1
    fi

    LOCKFILE=$CACHETMPDIR/sync.lock
    lockfile -r0 -l 86400 $LOCKFILE 2>/dev/null
    if [[ 0 -ne "$?" ]]; then
        echo_timestamp
        echo "===== Waiting for $LOCKFILE ====="
        lockfile -r-1 -l 86400 $LOCKFILE
        [[ 0 -ne "$?" ]] && exit 1
    fi

    echo_timestamp
    echo "===== Removing no longer cached (swapped out) files ====="
    remove_uncached_files $cache_list

    echo_timestamp
    echo "===== Removing expired files ====="
    remove_expired_files

    echo_timestamp
    echo "===== Removing broken links ====="
    find $CACHEROOT -type l -xtype l -print -delete

    echo_timestamp
    echo "===== Synchronizing new files ====="
    while read f; do
        # source file not exist or is a directory
        [ ! -f "$WWWROOT$f" ] && continue

        # it was a directory, now a file
        [ -d "$CACHEROOT$f" ] && rm -rf $CACHEROOT$f

        # file not cached
        if [ ! -f "$CACHEROOT$f" ]; then
            echo $f
            atomic_cp $WWWROOT$f $CACHEROOT$f
        fi
        # cached but expired files have been removed
    done < $cache_list

    echo_timestamp
    echo "===== Removing empty dirs ====="
    find $CACHEROOT -type d -empty -print -delete

    echo_timestamp
    rm -f $LOCKFILE
}
