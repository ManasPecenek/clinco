#!/bin/bash

current=$(docker ps | grep worker | tail -n 1 | rev | cut -b 1)

i=$(($1 + $current))

if [ "$(uname)" = "Darwin" ]
then
  KUBERNETES_PUBLIC_ADDRESS=$(hostname)
elif [ "$(uname)" = "Linux" ]
then
  KUBERNETES_PUBLIC_ADDRESS=$(hostname -i)
fi

docker exec -it --privileged --user root master bash -c "./add.sh $i $current $KUBERNETES_PUBLIC_ADDRESS"

while [ $i -gt $current ]
do
docker run -dt --network clinco --hostname worker-$i --name worker-$i -v worker-$i:/root -v /lib/modules:/lib/modules:ro --ip=172.172.1.$i --privileged --user root petschenek/ubuntu-systemd:worker

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

docker exec -it --privileged --user root ${instance}-$i bash -c "./worker.sh"

i=$((i-1))
done

