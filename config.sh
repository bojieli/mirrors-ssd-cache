NGINXLOGDIR=/var/log/nginx/mirrors
LOGDIR=/var/log/ssd-cache-log
WWWROOT=/srv/www
CACHEROOT=/mnt/ssd/cache
CACHETMPDIR=/mnt/ssd/tmp
TMPROOT=/tmp/ssd
LOCKFILE=/tmp/ssd-cache.lock
cachesize=$((1024*1024*1024*200)) # 200G

today=$(date +'%Y%m%d')

. $(dirname $0)/functions.sh
