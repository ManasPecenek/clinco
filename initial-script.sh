#!/bin/bash

set -e

export TERM=xterm
blue="$(tput setab 9; tput setaf 4)" && export blue
red="$(tput setab 9; tput setaf 1)" && export red
none="\033[0m" && export none

if ! docker info > /dev/null 2>&1; then
  echo -e "\n"$red"Docker is not running - please start docker and try again!"$none"\n"
  exit 1
fi

[[ -z "$(docker network ls | grep clinco)" ]] && \
docker network create --driver=bridge --subnet=172.172.0.0/16 --gateway=172.172.172.172 --scope=local --attachable=false --ingress=false clinco #> /dev/null # 2>&1

[[ $? -eq 0 ]] && echo -e "\n"$blue"*** Docker Network clinco Created ***"$none"\n"

if [[ "$(uname)" = *"Darwin"* ]]
then
  export KUBERNETES_PUBLIC_ADDRESS=$(ipconfig getifaddr en0)
elif [[ "$(uname)" = *"Linux"* ]]
then
  export KUBERNETES_PUBLIC_ADDRESS=127.0.0.1 #$(hostname -I)  #172.17.0.1 #host.docker.internal #$(hostname)
fi

# if [[ "$(uname -m)" = *"arm"* || "$(uname -m)" = *"aarch"* ]]
# then
#   export ARCH=arm64
# elif [[ "$(uname -m)" = *"x86"* ]]
# then
#   export ARCH=amd64
# else
#   echo $red"Could not find your architecture"$none"\n" && exit 1
# fi


while getopts "v:n:" option; do
  case $option in
  v)
    ETCD_VOLUME=$OPTARG;;
  n) 
    NODE_COUNT=$OPTARG;;
  *) echo "usage: $0 [-v] [-r]" #>&2
     exit 1 ;;
  esac
done

# [[ -z "$NODE_COUNT" ]] && export NODE_COUNT=1

# [[ -z "$ETCD_VOLUME" ]] && export ETCD_VOLUME=$RANDOM

export NODE_COUNT=${NODE_COUNT:-1}

export ETCD_VOLUME=${ETCD_VOLUME:-$RANDOM}

echo -e "\n"$blue"*** Creating Master Node ***"$none"\n"
docker run -dt --network clinco --hostname master --name master -v etcd-$ETCD_VOLUME:/var/lib/etcd --ip=172.172.0.1 -p 6443:6443 -p 8443:8443 --privileged --user root petschenek/clinco-master:22.04 > /dev/null 2>&1
# docker compose -f docker-compose/docker-compose.yml up --build -d --force-recreate

[[ $? -eq 0 ]] && echo -e $blue"*** Master Node Created ***"$none"\n" || echo -e $red"ERROR Could not Create Master Node"$none"\n"


i=$NODE_COUNT
while [ $i -gt 0 ]
do
echo -e $blue"*** Creating Worker Node $i ***"$none"\n"
if [[ $i -ne 1 ]];
then
  docker run -dt --network clinco --hostname worker-$i --name worker-$i -v /lib/modules:/lib/modules:ro --ip=172.172.1.$i --privileged --user root petschenek/clinco-worker:22.04 #> /dev/null
else
  # docker compose -f docker-compose/docker-compose.worker.yml up --build -d --force-recreate
  docker run -dt --network clinco -p 80:80 -p 443:443 --hostname worker-$i --name worker-$i -v /lib/modules:/lib/modules:ro --ip=172.172.1.$i --privileged --user root petschenek/clinco-worker:22.04 #> /dev/null
fi
[[ $? -eq 0 ]] && echo -e $blue"*** Worker Node $i Created ***"$none"\n" || echo -e $red"ERROR! Could not Create Worker Node $i"$none"\n"
i=$((i-1))
done


#########################################################################################################################
echo -e $blue"*** Configuring Master Node ***"$none"\n"

docker exec -i --privileged --user root master bash -c "./master.sh $NODE_COUNT $KUBERNETES_PUBLIC_ADDRESS" #> /dev/null

[[ $? -eq 0 ]] && echo -e $blue"*** Master Node Configured ***"$none"\n" || echo -e $red"ERROR! Could not Configure Master Node"$none"\n"

docker cp master:/root/admin.kubeconfig .kubeconfig

#########################################################################################################################
j=$NODE_COUNT
while [ $j -gt 0 ]
do

echo -e $blue"*** Configuring Worker Node $j ***"$none"\n"

docker exec -i --privileged --user root worker-$j bash -c "./worker.sh $NODE_COUNT $j" #> /dev/null

[[ $? -eq 0 ]] && echo -e $blue"*** Worker Node $j Configured ***"$none"\n" || echo -e $red"ERROR! Could not Configure Worker Node $j"$none"\n"

j=$((j-1))
done
#########################################################################################################################
# KUBECONFIG=~/.kube/config:.kubeconfig kubectl config view --flatten > ./.merged-config
# mv ./.merged-config ~/.kube/config
export KUBECONFIG=.kubeconfig

echo -e $blue"*** Deploying CoreDNS ***"$none"\n"; sleep 15
kubectl apply -f https://raw.githubusercontent.com/ManasPecenek/clinco/main/kube-tools/coredns-1.9.1.yaml #> /dev/null
[[ $? -eq 0 ]] && echo -e $blue"*** CoreDNS Deployed ***"$none"\n" || echo -e $red"ERROR! Could not Deploy CoreDNS"$none"\n"

echo -e $blue"*** Deploying Local Path Provisioner ***"$none"\n"
kubectl apply -f https://raw.githubusercontent.com/ManasPecenek/clinco/main/kube-tools/local-storage-class.yaml #> /dev/null
[[ $? -eq 0 ]] && echo -e $blue"*** Local Path Provisioner Deployed***"$none"\n" || echo -e $red"ERROR! Could not Deploy Local Path Provisioner"$none"\n"

echo -e $blue"*** Deploying Nginx Ingress Controller ***"$none"\n"
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




