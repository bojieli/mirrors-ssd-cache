NGINXLOGDIR=/var/log/nginx/mirrors
LOGDIR=/var/log/ssd-cache-log
WWWROOT=/srv/www
CACHEROOT=/mnt/ssd/cache
CACHETMPDIR=/mnt/ssd/tmp
cachesize=$((1024*1024*1024*225)) # leave 4G save space

today=$(date +'%Y%m%d')

. $(dirname $0)/functions.sh
