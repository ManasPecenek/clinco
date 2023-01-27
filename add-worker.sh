#!/bin/bash

if [[ "$(uname)" = *"Darwin"* ]]
then
  KUBERNETES_PUBLIC_ADDRESS=$(ipconfig getifaddr en0)
elif [[ "$(uname)" = *"Linux"* ]]
then
  KUBERNETES_PUBLIC_ADDRESS=$(hostname -i)
fi

if [[ "$(uname -m)" = *"arm"* || "$(uname -m)" = *"aarch"* ]]
then
  ARCH=arm64
elif [[ "$(uname -m)" = *"x86"* ]]
then
  ARCH=amd64
else
  echo "Could not configure your architecture" && exit 1
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
docker run -dt --network clinco --hostname worker-$i --name worker-$i -v /lib/modules:/lib/modules:ro --ip=172.172.1.$i --privileged --user root petschenek/ubuntu-systemd:worker-$ARCH-22.04

instance=worker

docker cp master:/root/ca.pem .
docker cp master:/root/${instance}-$i-key.pem .
docker cp master:/root/${instance}-$i.pem .
docker cp master:/root/kube-proxy.kubeconfig .
docker cp master:/root/${instance}-$i.kubeconfig .


docker cp ca.pem ${instance}-$i:/root/ && rm -f ca.pem
docker cp ${instance}-$i-key.pem ${instance}-$i:/root/ && rm -f ${instance}-$i-key.pem
docker cp ${instance}-$i.pem ${instance}-$i:/root/ && rm -f ${instance}-$i.pem 
docker cp kube-proxy.kubeconfig ${instance}-$i:/root/ && rm -f kube-proxy.kubeconfig
docker cp ${instance}-$i.kubeconfig ${instance}-$i:/root/ && rm -f ${instance}-$i.kubeconfig

docker exec -it --privileged --user root ${instance}-$i bash -c "./$ARCH-worker.sh $current"

i=$((i-1))
done

