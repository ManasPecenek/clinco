#!/bin/bash

export TERM=xterm
blue="$(tput setab 9; tput setaf 4)" && export blue
red="$(tput setab 9; tput setaf 1)" && export red
none="\033[0m" && export none


[[ -f "admin.kubeconfig" ]] && rm -f admin.kubeconfig


[[ -z "$(docker network ls | grep clinco)" ]] && \
docker network create --driver=bridge --subnet=172.172.0.0/16 --gateway=172.172.172.172 --scope=local --attachable=false --ingress=false clinco > /dev/null # 2>&1
[[ $? -eq 0 ]] && echo -e "\n*** Docker Network clinco Created *** \n"

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
  *) echo "usage: $0 [-v] [-r]" >&2
     exit 1 ;;
  esac
done

[[ -z "$NODE_COUNT" ]] && NODE_COUNT=1

[[ -z "$ETCD_VOLUME" ]] && ETCD_VOLUME=$RANDOM

echo -e "\n*** Creating Master Node *** \n"
docker run -dt --network clinco --hostname master --name master -v etcd-$ETCD_VOLUME:/var/lib/etcd --ip=172.172.0.1 -p 6443:6443 -p 8443:8443 --privileged --user root petschenek/ubuntu-systemd:master-$ARCH-22.04 > /dev/null 2>&1
[[ $? -eq 0 ]] && echo -e $blue"*** Master Node Created ***"$none"\n" || echo -e $red"ERROR Could not Create Master Node"$none"\n"


i=$NODE_COUNT
while [ $i -gt 0 ]
do
echo -e "*** Creating Worker Node $i *** \n"
if [[ $i -ne 1 ]];
then
  docker run -dt --network clinco --hostname worker-$i --name worker-$i -v /lib/modules:/lib/modules:ro --ip=172.172.1.$i --privileged --user root petschenek/ubuntu-systemd:worker-$ARCH-22.04 > /dev/null 2>&1
else
  docker run -dt --network clinco -p 80:80 -p 443:443 --hostname worker-$i --name worker-$i -v /lib/modules:/lib/modules:ro --ip=172.172.1.$i --privileged --user root petschenek/ubuntu-systemd:worker-$ARCH-22.04 > /dev/null 2>&1
fi
[[ $? -eq 0 ]] && echo -e $blue"*** Worker Node $i Created ***"$none"\n" || echo -e $red"ERROR! Could not Create Worker Node $i"$none"\n"
i=$((i-1))
done


#########################################################################################################################
echo -e "*** Configuring Master Node *** \n"

(docker exec -i --privileged --user root master bash -c "./$ARCH-master.sh $NODE_COUNT $KUBERNETES_PUBLIC_ADDRESS") > /dev/null 2>&1

[[ $? -eq 0 ]] && echo -e $blue"*** Master Node Configured ***"$none"\n" || echo -e $red"ERROR! Could not Configure Master Node"$none"\n"

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

[[ $? -eq 0 ]] && echo -e $blue"*** Worker Node $j Configured ***"$none"\n" || echo -e $red"ERROR! Could not Configure Worker Node $j"$none"\n"

j=$((j-1))
done
#########################################################################################################################
export KUBECONFIG=./admin.kubeconfig

echo -e "*** Deploying CoreDNS *** \n"; sleep 15
kubectl apply -f https://raw.githubusercontent.com/ManasPecenek/clinco/main/kube-tools/coredns-1.9.1.yaml > /dev/null
[[ $? -eq 0 ]] && echo -e $blue"*** CoreDNS Deployed ***"$none"\n" || echo -e $red"ERROR! Could not Deploy CoreDNS"$none"\n"

echo -e "*** Deploying Local Path Provisioner *** \n"
kubectl apply -f https://raw.githubusercontent.com/ManasPecenek/clinco/main/kube-tools/local-storage-class.yaml > /dev/null
[[ $? -eq 0 ]] && echo -e $blue"*** Local Path Provisioner Deployed***"$none"\n" || echo -e $red"ERROR! Could not Deploy Local Path Provisioner"$none"\n"

echo -e "*** Deploying Nginx Ingress Controller *** \n"
helm upgrade --install ingress-nginx ingress-nginx \
--repo https://kubernetes.github.io/ingress-nginx \
--namespace ingress-nginx --create-namespace \
--set controller.hostNetwork=true \
--set controller.hostPort.enabled=true  \
--set controller.admissionWebhooks.enabled=false \
--set controller.nodeSelector."kubernetes\.io\/hostname"=worker-1 \
--set controller.service.external.enabled=false \
--version 4.1.1 > /dev/null
[[ $? -eq 0 ]] && echo -e $blue"*** Nginx Ingress Controller Deployed ***"$none"\n" || echo -e $red"ERROR! Could not Deploy Nginx Ingress Controller"$none"\n"

# [[ -z $(kubectl get deploy -A | awk '{print $2}' | tail +2 | grep -w "coredns") ]] && 




