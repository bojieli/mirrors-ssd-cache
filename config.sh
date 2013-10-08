#!/bin/bash

NGINXLOGDIR=/var/log/nginx/mirrors
LOGDIR=/var/log/ssd-cache-log
WWWROOT=/srv/www
CACHEROOT=/mnt/ssd/cache
cachesize=10737418240 # 10G

today=$(date +'%Y%m%d')
