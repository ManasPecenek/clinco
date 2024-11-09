#!/bin/bash

set -eux

if [[ "$(uname)" = *"Darwin"* ]]
then
  export KUBERNETES_PUBLIC_ADDRESS=$(ipconfig getifaddr en0)
elif [[ "$(uname)" = *"Linux"* ]]
then
  export KUBERNETES_PUBLIC_ADDRESS=$(hostname -I)
fi

while getopts "c:n:" option; do
  case $option in
  c) 
    CLUSTER_NAME=$OPTARG;;
  n) 
    ADDITIONAL_NODE_COUNT=$OPTARG;;
  *) echo "usage: $0 [-n] [-c]" #>&2
     exit 1 ;;
  esac
done

export CLUSTER_NAME=${CLUSTER_NAME:-clinco}

export ADDITIONAL_NODE_COUNT=${ADDITIONAL_NODE_COUNT:-1}

current=$(docker ps | grep -c worker-)

i=$(($ADDITIONAL_NODE_COUNT + $current))


docker exec -it --privileged --user root master bash -c "./add.sh $i $current $KUBERNETES_PUBLIC_ADDRESS"

while [ $i -gt $current ]
do
  docker run -dt --network clinco --hostname worker-$i --name worker-$i -e CLUSTER_NAME -v /lib/modules:/lib/modules:ro -v clinco-shared:/home --ip=172.172.1.$i --privileged --user root petschenek/clinco-worker:22.04 #> /dev/null

  instance=worker

  docker exec -it --privileged --user root ${instance}-$i bash -c "./worker.sh $current"

  i=$((i-1))
done

