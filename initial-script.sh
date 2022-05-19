#!/bin/bash

[[ -f "admin.kubeconfig" ]] && rm -f admin.kubeconfig


[[ -z "$(docker network ls | grep clinco)" ]] && \
docker network create --driver=bridge --subnet=172.172.0.0/16 --gateway=172.172.172.172 --scope=local --attachable=false --ingress=false clinco > /dev/null 2>&1


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
  echo "Could not find your architecture" && exit 1
fi


while getopts "v:n:" option; do
  case $option in
  v)
    ETCD_VOLUME=$OPTARG;;
  n) 
    NODE_COUNT=$OPTARG;;
  esac
done

[[ -z "$NODE_COUNT" ]] && NODE_COUNT=1

[[ -z "$ETCD_VOLUME" ]] && ETCD_VOLUME=$RANDOM

echo -e "\n*** Creating Master Node *** \n"
docker run -dt --network clinco --hostname master --name master -v etcd-$ETCD_VOLUME:/var/lib/etcd --ip=172.172.0.1 -p 6443:6443 -p 8443:8443 --privileged --user root petschenek/ubuntu-systemd:master-$ARCH-21.10 > /dev/null 2>&1
echo -e "*** Master Node Created *** \n"

i=$NODE_COUNT
while [ $i -gt 0 ]
do
echo -e "*** Creating Worker Node $i *** \n"
if [[ $i -ne 1 ]];
then
  docker run -dt --network clinco --hostname worker-$i --name worker-$i -v /lib/modules:/lib/modules:ro --ip=172.172.1.$i --privileged --user root petschenek/ubuntu-systemd:worker-$ARCH-21.10 > /dev/null 2>&1
else
  docker run -dt --network clinco -p 80:80 -p 443:443 --hostname worker-$i --name worker-$i -v /lib/modules:/lib/modules:ro --ip=172.172.1.$i --privileged --user root petschenek/ubuntu-systemd:worker-$ARCH-21.10 > /dev/null 2>&1
fi
echo -e "*** Worker Node $i Created *** \n"
i=$((i-1))
done


#########################################################################################################################
echo -e "\n*** Configuring Master Node *** \n"

(docker exec -i --privileged --user root master bash -c "./$ARCH-master.sh $NODE_COUNT $KUBERNETES_PUBLIC_ADDRESS") > /dev/null 2>&1

echo -e "*** Master Node Configured *** \n"

docker cp master:/root/admin.kubeconfig .

#########################################################################################################################
j=$NODE_COUNT
while [ $j -gt 0 ]
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

echo -e "*** Configuring Worker Node $j *** \n"
(docker exec -i --privileged --user root worker-$j bash -c "./$ARCH-worker.sh $NODE_COUNT") > /dev/null 2>&1
echo -e "*** Worker Node $j Configured *** \n"
j=$((j-1))
done
#########################################################################################################################
export KUBECONFIG=./admin.kubeconfig
echo -e "*** Deploying CoreDNS *** \n"; sleep 15
kubectl apply -f kube-tools/coredns-1.9.1.yaml > /dev/null 2>&1
echo "*** CoreDNS Deployed ***"

kubectl label node worker-1 ingress-ready=true > /dev/null 2>&1

echo -e "*** Deploying Local Path Provisioner *** \n"
kubectl apply -f /Users/Manas.Pecenek/Desktop/clinco/kube-tools/sc.yaml > /dev/null 2>&1
echo -e "*** Local Path Provisioner Deployed*** \n";

echo -e "*** Deploying Nginx Ingress Controller *** \n"
helm upgrade --install ingress-nginx ingress-nginx \
--repo https://kubernetes.github.io/ingress-nginx \
--namespace ingress-nginx --create-namespace \
--set controller.hostNetwork=true \
--set controller.hostPort.enabled=true  \
--set controller.admissionWebhooks.enabled=false \
--set controller.service.external.enabled=false \
--version 4.1.1 > /dev/null 2>&1
echo -e "*** Nginx Ingress Controller Deployed *** \n"

# [[ -z $(kubectl get deploy -A | awk '{print $2}' | tail +2 | grep -w "coredns") ]] && 




