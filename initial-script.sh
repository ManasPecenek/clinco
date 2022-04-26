#!/bin/bash


if [ -z "$(docker network ls | grep clinco)" ]
then
docker network create --driver=bridge --subnet=172.172.0.0/16 --gateway=172.172.172.172 --scope=local --attachable=false --ingress=false clinco
fi


if [[ "$(uname)" = *"Darwin"* ]]
then
  KUBERNETES_PUBLIC_ADDRESS=$(ipconfig getifaddr en0)
elif [[ "$(uname)" = *"Linux"* ]]
then
  KUBERNETES_PUBLIC_ADDRESS=$(hostname -i)
fi

if [[ "$(uname -m)" = *"arm64"* || "$(uname -m)" = *"aarch64"* ]]
then
  TAG=arm64-21.10
else
  TAG=amd64-21.10
fi


docker run -dt --network clinco --hostname master --name master -v master:/root -v etcd:/var/lib/etcd --ip=172.172.0.1 -p 6443:6443 -p 80:80 --privileged --user root petschenek/ubuntu-systemd:master-$TAG

i=$1
while [ $i -gt 0 ]
do
docker run --cpus=2 -dt --network clinco --hostname worker-$i --name worker-$i -v worker-$i:/root -v /lib/modules:/lib/modules:ro --ip=172.172.1.$i --privileged --user root petschenek/ubuntu-systemd:worker-$TAG
i=$((i-1))
done
i=$1

#########################################################################################################################

docker exec -it --privileged --user root master bash -c "./master.sh $1 $KUBERNETES_PUBLIC_ADDRESS"

docker cp master:/root/admin.kubeconfig .

#########################################################################################################################
while [ $i -gt 0 ]
do
docker cp master:/root/worker-$i.kubeconfig .
docker cp master:/root/kube-proxy.kubeconfig .
docker cp master:/root/ca.pem .
docker cp master:/root/worker-$i-key.pem .
docker cp master:/root/worker-$i.pem .

docker cp worker-$i.kubeconfig worker-$i:/root/ && rm -f worker-$i.kubeconfig
docker cp kube-proxy.kubeconfig worker-$i:/root/ && rm -f kube-proxy.kubeconfig
docker cp ca.pem worker-$i:/root/ && rm -f ca.pem
docker cp worker-$i-key.pem worker-$i:/root/ && rm -f worker-$i-key.pem
docker cp worker-$i.pem worker-$i:/root/ && rm -f worker-$i.pem

docker exec -it --privileged --user root worker-$i bash -c "./worker.sh"

i=$((i-1))
done
#########################################################################################################################
export KUBECONFIG=./admin.kubeconfig
sleep 10 && kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
sleep 10 && kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns-1.8.yaml


