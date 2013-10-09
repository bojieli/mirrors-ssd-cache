#!/bin/bash
# this script should be run after daily logrotate

. $(dirname $0)/config.sh

function lastweeklog() {
	cat $NGINXLOGDIR/access-f2.log-$today
	for i in {1..6}; do
		xzcat $NGINXLOGDIR/access-f2.log-$(date --date="$i days ago" '+%Y%m%d').xz
	done
}

lastweeklog | awk '{ if($2=="200") print $14 }' | sed 's/[" ]//g' \
	| sort | uniq -c | sort -nr \
	| awk '{ if($1>1) print $1,$2 }' | gzip - >$LOGDIR/filefreq-$today.gz

zcat $LOGDIR/filefreq-$today.gz | \
while read count filename; do
	if [[ "$filename" == /* ]] && [ -f "$WWWROOT$filename" ]; then
		echo $count $(stat -c '%s %Z' "$WWWROOT$filename") $filename
	fi
done | \
awk "{sum+=\$2; if(sum>$cachesize) exit; print \$4}" | sort >$LOGDIR/tocache-$today

rsync -a --delete --files-from=$LOGDIR/tocache-$today $WWWROOT $CACHEROOT
