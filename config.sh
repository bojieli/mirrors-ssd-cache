NGINXLOGDIR=/var/log/nginx/mirrors
LOGDIR=/var/log/ssd-cache-log
WWWROOT=/srv/www
CACHEROOT=/mnt/ssd/cache
CACHETMPDIR=/mnt/ssd/tmp
#cachesize=$((1000*1000*1000*235)) # leave 4G save space
cachesize=$((1000*1000*1000*238)) # leave 4G save space

today=$(date +'%Y%m%d')

. $(dirname $0)/functions.sh
