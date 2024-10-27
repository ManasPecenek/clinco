#!/bin/bash

set -e

if [[ "$(uname)" = *"Darwin"* ]]
then
  export KUBERNETES_PUBLIC_ADDRESS=$(ipconfig getifaddr en0)
elif [[ "$(uname)" = *"Linux"* ]]
then
  export KUBERNETES_PUBLIC_ADDRESS=127.0.0.1 #$(hostname -I)  #172.17.0.1 #host.docker.internal #$(hostname)
fi

while getopts "n:" option; do
  case $option in
  n) 
    ADDITIONAL_NODE_COUNT=$OPTARG;;
  *) echo "usage: $0 [-v] [-r]" >&2
     exit 1 ;;
  esac
done

[[ -z "$ADDITIONAL_NODE_COUNT" ]] && ADDITIONAL_NODE_COUNT=1

current=$(docker ps | grep -c worker-)

i=$(($ADDITIONAL_NODE_COUNT + $current))


docker exec -it --privileged --user root master bash -c "./add.sh $i $current $KUBERNETES_PUBLIC_ADDRESS"

while [ $i -gt $current ]
do
docker run -dt --network clinco --hostname worker-$i --name worker-$i -v /lib/modules:/lib/modules:ro -v shared-volume:/home --ip=172.172.1.$i --privileged --user root petschenek/clinco-worker:22.04 > /dev/null 2>&1

instance=worker

docker exec -it --privileged --user root ${instance}-$i bash -c "./worker.sh $current"

i=$((i-1))
done

