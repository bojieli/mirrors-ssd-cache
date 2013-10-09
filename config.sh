#!/bin/bash

NGINXLOGDIR=/var/log/nginx/mirrors
LOGDIR=/var/log/ssd-cache-log
WWWROOT=/srv/www
CACHEROOT=/mnt/ssd/cache
cachesize=107374182400 # 100G

today=$(date +'%Y%m%d')
