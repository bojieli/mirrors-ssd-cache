#!/bin/bash

NGINXLOGDIR=/var/log/nginx/mirrors
LOGDIR=/var/log/ssd-cache-log
WWWROOT=/srv/www
CACHEROOT=/mnt/ssd/cache
cachesize=$((1024*1024*1024*200)) # 200G

today=$(date +'%Y%m%d')
