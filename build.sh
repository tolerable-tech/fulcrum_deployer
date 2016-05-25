#!/bin/bash

IMAGE_NAME="tolerable/fulcrum_deployer"
IMAGE_LATEST_NAME=$IMAGE_NAME:latest
IMAGE_VERSION_NAME=$IMAGE_NAME:$(cat VERSION)

function push() {
  docker push $IMAGE_LATEST_NAME
  docker push $IMAGE_VERSION_NAME
}

function build() {
  docker build --force-rm -t $IMAGE_LATEST_NAME .
  docker tag  $IMAGE_LATEST_NAME $IMAGE_VERSION_NAME
}

function run() {
  source ./.env
  docker run  -e "DIGITALOCEAN_APP_ID=$DIGITALOCEAN_APP_ID"\
                -e "DIGITALOCEAN_SECRET=$DIGITALOCEAN_SECRET"\
                -e "SECRET_TOKEN=$SECRET_TOKEN"\
                -p :4001:4001 \
                --volume $(pwd):/app \
                --rm --name test $IMAGE_LATEST_NAME
}

for var in "$@"; do
  case $var in
    "a")
      build
      push
      ;;
    "push")
      push
      ;;
    "build")
      build
      ;;
    "run")
      run
      ;;
    * )
      build
      ;;
  esac
done
