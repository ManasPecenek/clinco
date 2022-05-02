#!/bin/bash

[[ -f "admin.kubeconfig" ]] && rm -f admin.kubeconfig


[[ -z "$(docker network ls | grep clinco)" ]] && \
docker network create --driver=bridge --subnet=172.172.0.0/16 --gateway=172.172.172.172 --scope=local --attachable=false --ingress=false clinco


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


while getopts "v:n:" option; do
  case $option in
  v)
    ETCD_VOLUME=$OPTARG;;
  n) 
    NODE_COUNT=$OPTARG;;
  esac
done

[[ -z "$NODE_COUNT" ]] && echo "Please decide the worker node count" && exit 1

if [[ -z "$ETCD_VOLUME" ]]
then
  docker run -dt --network clinco --hostname master --name master -v etcd-$RANDOM:/var/lib/etcd --ip=172.172.0.1 -p 6443:6443 -p 80:80 -p 443:443 --privileged --user root petschenek/ubuntu-systemd:master-$ARCH-21.10
else
  docker run -dt --network clinco --hostname master --name master -v etcd-$ETCD_VOLUME:/var/lib/etcd --ip=172.172.0.1 -p 6443:6443 -p 80:80 -p 443:443 --privileged --user root petschenek/ubuntu-systemd:master-$ARCH-21.10
fi

i=$NODE_COUNT
while [ $i -gt 0 ]
do
docker run -dt --network clinco --hostname worker-$i --name worker-$i -v /lib/modules:/lib/modules:ro --ip=172.172.1.$i --privileged --user root petschenek/ubuntu-systemd:worker-$ARCH-21.10
i=$((i-1))
done


#########################################################################################################################

docker exec -it --privileged --user root master bash -c "./$ARCH-master.sh $NODE_COUNT $KUBERNETES_PUBLIC_ADDRESS"

docker cp master:/root/admin.kubeconfig .

#########################################################################################################################
j=$NODE_COUNT
while [ $i -gt 0 ]
do
docker cp master:/root/worker-$j.kubeconfig .
docker cp master:/root/kube-proxy.kubeconfig .
docker cp master:/root/ca.pem .
docker cp master:/root/worker-$j-key.pem .
docker cp master:/root/worker-$j.pem .

docker cp worker-$j.kubeconfig worker-$j:/root/ && rm -f worker-$j.kubeconfig
docker cp kube-proxy.kubeconfig worker-$j:/root/ && rm -f kube-proxy.kubeconfig
docker cp ca.pem worker-$j:/root/ && rm -f ca.pem
docker cp worker-$j-key.pem worker-$j:/root/ && rm -f worker-$j-key.pem
docker cp worker-$j.pem worker-$j:/root/ && rm -f worker-$j.pem

docker exec -it --privileged --user root worker-$j bash -c "./$ARCH-worker.sh $NODE_COUNT"

i=$((i-1))
done
#########################################################################################################################
export KUBECONFIG=./admin.kubeconfig
[[ -z $(docker volume ls | awk '{print $2}' | grep etcd |  cut -d "-" -f2 | grep -w "$ETCD_VOLUME") ]] && sleep 15 && kubectl apply -f kube-tools/coredns-1.9.1.yaml
