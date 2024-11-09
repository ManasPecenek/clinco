#!/bin/bash

set -e

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


current=$(docker ps --filter "name=worker-" -q | wc -l)

k=$(($ADDITIONAL_NODE_COUNT + $current))

docker exec -it --privileged --user root master bash -c "./add.sh $k $current $KUBERNETES_PUBLIC_ADDRESS"

while [ $k -gt $current ]
do
  docker run -dt --network clinco --hostname worker-$k --name worker-$k -e CLUSTER_NAME -v /lib/modules:/lib/modules:ro -v clinco-shared:/home --ip=172.172.1.$k --privileged --user root petschenek/clinco-worker:22.04 #> /dev/null

  instance=worker

  docker exec -it --privileged --user root ${instance}-$k bash -c "./worker.sh $ADDITIONAL_NODE_COUNT $k"

  k=$((k-1))
done

