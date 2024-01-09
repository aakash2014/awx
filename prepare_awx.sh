#!/bin/bash
path=`pwd`
mkdir awx
cd awx
tar -xvzf ../awx_packaged.tar.gz

printf "***********************************************************************\nLoading All images\n***********************************************************************"
docker load --input temp_image.tar
docker load --input awx_awx1.tar
docker load --input redis_awx.tar
docker load --input postgres_awx1.tar
docker network create awxnetwork
mountpath=$path"/awx/mount"

printf "***********************************************************************\nCreating postgres image\n***********************************************************************"
docker container create --net awxnetwork --network-alias=postgres  --name tools_postgres_1 postgres_awx:v1

printf "***********************************************************************\nLoading postgres volume\n***********************************************************************"

./docker-volume.sh tools_postgres_1 load tools_postgres_1-volumes.tar

printf "***********************************************************************\nCreating redis image\n***********************************************************************"

docker container create --net awxnetwork --network-alias=redis_1 --name=tools_redis_1 -v $mountpath/redis.conf:/usr/local/etc/redis/redis.conf redis_awx:v1

printf "***********************************************************************\nLoading redis volume\n***********************************************************************"

./docker-volume.sh tools_redis_1 load tools_redis_1-volumes.tar

printf "***********************************************************************\nCreating AWX image\n***********************************************************************"

redis_socket_volume=`docker inspect tools_redis_1 | grep '"Source": \|"Destination' | grep '/var/run/redis' -B1 | grep Source | cut -d "/" -f6`
docker container create --net awxnetwork --network-alias=awx_1 --link="tools_postgres_1:postgres" --link="tools_postgres_1:tools_postgres_1" --link="tools_redis_1:redis_1" --link="tools_redis_1:tools_redis_1" --name tools_awx_1 -v $mountpath/database.py:/etc/tower/conf.d/database.py -v $mountpath/nginx.conf:/etc/nginx/nginx.conf -v $mountpath/receptor.conf:/etc/receptor/receptor.conf -v $mountpath/websocket_secret.py:/etc/tower/conf.d/websocket_secret.py -v $mountpath/SECRET_KEY:/etc/tower/SECRET_KEY -v $mountpath/nginx.locations.conf:/etc/nginx/conf.d/nginx.locations.conf -v $mountpath/local_settings.py:/etc/tower/conf.d/local_settings.py -v $mountpath/receptor.conf.lock:/etc/receptor/receptor.conf.lock -v $mountpath/supervisord.conf:/etc/supervisord.conf -v /var/lib/docker/volumes/$redis_socket_volume/_data:/var/run/redis -p 2222:2222 -p 3000:3001 -p 8888:8888 -p 8080:8080 -p 8043:8043 -p 8013:8013 -p 7899-7999:7899-7999 -p 6899:6899 awx_awx:v1

printf "***********************************************************************\nLoading AWX volume\n***********************************************************************"
./docker-volume.sh tools_awx_1 load c38088454830-volumes.tar
docker image rm ubuntu:22.04
