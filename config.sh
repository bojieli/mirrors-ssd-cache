NGINXLOGDIR=/var/log/nginx/mirrors
LOGDIR=/var/log/ssd-cache-log
WWWROOT=/srv/www
CACHEROOT=/mnt/ssd/cache
CACHETMPDIR=/mnt/ssd/tmp
declare -i cachesize=$((225*1024**3)) # leave 4G save space

today=$(date +'%Y%m%d')

. $(dirname $0)/functions.sh
