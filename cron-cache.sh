#!/bin/bash
# this script should be run after daily logrotate

. $(dirname $0)/config.sh

function lastndaylog() {
	cat $NGINXLOGDIR/access-f2.log-$today
	days=$(($1-1))
	while true; do
		xzcat $NGINXLOGDIR/access-f2.log-$(date --date="$days days ago" '+%Y%m%d').xz
		days=$(($days-1))
		[ $days -eq 0 ] && break
	done
}

function lastweeklog() {
	lastndaylog 7
}

lastndaylog 2 | awk '{ if($2=="200") print $14 }' \
	| sed 's/[" ]//g' | sed 's/[\/][\/]*/\//g' \
	| sort | uniq -c | sort -nr \
	| awk '{ if($1>1) print $1,$2 }' | gzip - >$LOGDIR/filefreq-$today.gz

filelist=$LOGDIR/tocache-$today

zcat $LOGDIR/filefreq-$today.gz | \
while read count filename; do
	# temporarily do not cache rubygems
	[[ "$filename" == /rubygems* ]] && continue
	if [[ "$filename" == /* ]] && [ -f "$WWWROOT$filename" ]; then
		echo $count $(stat -L -c '%s %Z' "$WWWROOT$filename") $filename
	fi
done | \
awk "{sum+=\$2; if(sum>$cachesize) exit; print \$4}" | sort >$filelist

$(dirname $0)/update-incrontab.sh $filelist

sync_from_file_list $filelist
