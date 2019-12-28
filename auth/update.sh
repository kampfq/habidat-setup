#!/bin/bash
set -e

source ../store/nginx/networks.env
source ../store/auth/passwords.env

envsubst < docker-compose.yml > ../store/auth/docker-compose.yml

echo "Pulling images and recreate containers..."

docker-compose -f ../store/auth/docker-compose.yml -p "$HABIDAT_DOCKER_PREFIX-auth" pull
docker-compose -f ../store/auth/docker-compose.yml -p "$HABIDAT_DOCKER_PREFIX-auth" up -d 
