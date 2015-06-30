#!/bin/bash
function timestamp()
{
    stat -L -c '%Y' $1
}

function atomic_cp()
{
    dstdir="$(dirname $2)"
    if [ ! -d "$dstdir" ]; then
        mkdir -p "$dstdir"
    fi

    ##### Explanation
    # 1. $oriabspath stands for the *REAL* path of $dstfile
    # 2. if original file is a link
    #        if the file that is pointed to hasn't been cached
    #            copy the original file and the dirs that contains it to SSD
    #            create a link(absolute path) on dest
    #        elif the file has been cached
    #            create the link
    #    elif original file is an ordinary file
    #        copy
    #####

    if [ -L "$1" ]; then
        dstfile="${2#$CACHEROOT}" # e.g $dstfile = /ubuntu-releases/14.04.2/ubuntu-14.04.2-desktop-amd64.iso
        t="${dstfile#/*/}" # e.g $t = 14.04.2/ubuntu-14.04.2-desktop-amd64.iso
        repo="${dstfile%$t}" # e.g $repo = /ubuntu-releases/
        dstfile="$t"

        local oriabspath="$(readlink -e $1)" # e.g $oriabspath = /mnt/repo/ubuntu-releases/.pool/ubuntu-14.04.2-desktop-amd64.iso
        [[ -z $oriabspath ]] && return

        ORIGINROOT="${oriabspath%%$repo*}"
        ORIGINROOT+="$repo" # e.g $ORIGINROOT = /mnt/repo/ubuntu-releases/

        linktoname="${oriabspath#$ORIGINROOT}" # e.g $linktoname = .pool/ubuntu-14.04.2-desktop-amd64.iso

        if [[ $linktoname == *mnt* ]]; then
            echo "-------------Wrong Path---------------" >>/tmp/wrongpath.log
            echo "linktoname: $linktoname" >>/tmp/wrongpath.log
            echo "source: $1" >>/tmp/wrongpath.log
            echo "destination: $2" >>/tmp/wrongpath.log
            echo "dstfile: $dstfile" >>/tmp/wrongpath.log
            echo "repo: $repo" >>/tmp/wrongpath.log
            echo "oriabspath: $oriabspath" >>/tmp/wrongpath.log
            echo "ORIGINROOT: $ORIGINROOT" >>/tmp/wrongpath.log
            return
        fi

        if [ ! -f $CACHEROOT$repo$linktoname ]; then
            linktodir="$(dirname $CACHEROOT$repo$linktoname)"
            [ ! -d "$linktodir" ] && mkdir -p "$linktodir"

            local tmpfile="$(mktemp --tmpdir=$CACHETMPDIR)"
            #local tmpfile="$(mktemp -u --tmpdir=$CACHETMPDIR)"
            cp --preserve=all $oriabspath $tmpfile
            mv $tmpfile $CACHEROOT$repo$linktoname
            #echo "cp --preserve=all $oriabspath $tmpfile"
            #echo "mv $tmpfile $CACHEROOT$repo$linktoname"
        fi
        ln -sf $CACHEROOT$repo$linktoname $2
        #echo ln -sf $CACHEROOT$repo$linktoname $2

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
    cat $1 | while read f; do
        if [ -L "$CACHEROOT$f" ]; then
            local oriabspath="$(readlink -e $CACHEROOT$f)"
            [ -n "$oriabspath" ] && echo "${oriabspath#$CACHEROOT}" >> $tmpfile
        fi
    done

    diff --old-line-format='' --new-line-format='%L' --unchanged-line-format='' \
        <(cat $tmpfile | sort -u) \
        <(find $CACHEROOT -type f -o -type l | cut -c $((${#CACHEROOT}+1))- | sort -u) \
    | while read f; do

        echo $f
        rm -rf "$CACHEROOT$f"
    done
    #rm $tmpfile
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
    # ensure that $CACHEROOT and $WWWROOT dont end with '/'
    CACHEROOT="${CACHEROOT%/}"
    WWWROOT="${WWWROOT%/}"

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

    echo "===== Removing broken links ====="
    find $CACHEROOT -type l -xtype l -print -delete

    echo_timestamp

    echo "===== Synchronizing new files ====="
    cat $cache_list | while read f; do
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
    done

    echo_timestamp

    echo $CACHEROOT $(date '+%T') >>/tmp/load.log
    echo "$(df -h /dev/sdb)" >>/tmp/load.log
    rm -f $LOCKFILE
}
