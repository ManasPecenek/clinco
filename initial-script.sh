#!/bin/bash


if [ -z "$(docker network ls | grep clinco)" ]
then
docker network create --driver=bridge --subnet=172.172.0.0/16 --gateway=172.172.172.172 --scope=local --attachable=false --ingress=false clinco
fi

docker run -dt --network clinco --hostname master --name master -v master:/root -v etcd:/var/lib/etcd --ip=172.172.0.1 -p 6443:6443 -p 80:80 --privileged --user root petschenek/ubuntu-systemd:master

i=$1
while [ $i -gt 0 ]
do
docker run -dt --network clinco --hostname worker-$i --name worker-$i -v worker-$i:/root -v /lib/modules:/lib/modules:ro --ip=172.172.1.$i --privileged --user root petschenek/ubuntu-systemd:worker
i=$((i-1))
done
i=$1

# cat > ca-config.json <<EOF
# {
#   "signing": {
#     "default": {
#       "expiry": "8760h"
#     },
#     "profiles": {
#       "kubernetes": {
#         "usages": ["signing", "key encipherment", "server auth", "client auth"],
#         "expiry": "8760h"
#       }
#     }
#   }
# }
# EOF

# cat > ca-csr.json <<EOF
# {
#   "CN": "Kubernetes",
#   "key": {
#     "algo": "rsa",
#     "size": 2048
#   },
#   "names": [
#     {
#       "C": "US",
#       "L": "Portland",
#       "O": "Kubernetes",
#       "OU": "CA",
#       "ST": "Oregon"
#     }
#   ]
# }
# EOF

# cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# docker cp ca.pem master:/root/
# docker cp ca-key.pem master:/root/

# if [ "$(uname)" = "Darwin" ]
# then
#   KUBERNETES_PUBLIC_ADDRESS=$(hostname)
# elif [ "$(uname)" = "Linux" ]
# then
#   KUBERNETES_PUBLIC_ADDRESS=$(hostname -i)
# fi

# #########################################################################################################################
# while [ $i -gt 0 ]
# do

# instance=worker

# cat > ${instance}-$i-csr.json <<EOF
# {
#   "CN": "system:node:${instance}-$i",
#   "key": {
#     "algo": "rsa",
#     "size": 2048
#   },
#   "names": [
#     {
#       "C": "US",
#       "L": "Portland",
#       "O": "system:nodes",
#       "OU": "clinco Hard Way",
#       "ST": "Oregon"
#     }
#   ]
# }
# EOF


# EXTERNAL_IP=172.172.1.$i
# INTERNAL_IP=127.0.0.1
# cfssl gencert \
#   -ca=ca.pem \
#   -ca-key=ca-key.pem \
#   -config=ca-config.json \
#   -hostname=${instance}-$i,${EXTERNAL_IP},${INTERNAL_IP} \
#   -profile=kubernetes \
#   ${instance}-$i-csr.json | cfssljson -bare ${instance}-$i


# docker cp ca.pem ${instance}-$i:/root/
# docker cp ${instance}-$i-key.pem ${instance}-$i:/root/
# docker cp ${instance}-$i.pem ${instance}-$i:/root/

# kubectl config set-cluster clinco-the-hard-way \
# --certificate-authority=ca.pem \
# --embed-certs=true \
# --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
# --kubeconfig=${instance}-$i.kubeconfig

# kubectl config set-credentials system:node:${instance}-$i \
# --client-certificate=${instance}-$i.pem \
# --client-key=${instance}-$i-key.pem \
# --embed-certs=true \
# --kubeconfig=${instance}-$i.kubeconfig

# kubectl config set-context default \
# --cluster=clinco-the-hard-way \
# --user=system:node:${instance}-$i \
# --kubeconfig=${instance}-$i.kubeconfig

# kubectl config use-context default --kubeconfig=${instance}-$i.kubeconfig

# i=$((i-1))
# done
# i=$1
# #########################################################################################################################

docker exec -it --privileged --user root master bash -c "./master.sh $1"

#########################################################################################################################
while [ $i -gt 0 ]
do
docker cp ${instance}-$i.kubeconfig ${instance}-$i:/root/
docker cp kube-proxy.kubeconfig ${instance}-$i:/root/

docker exec -it --privileged --user root ${instance}-$i bash -c "./worker.sh"

docker cp ca.pem ${instance}-$i:/root/
docker cp ${instance}-$i-key.pem ${instance}-$i:/root/
docker cp ${instance}-$i.pem ${instance}-$i:/root/

i=$((i-1))
done
#########################################################################################################################

#rm -f *.csr *.pem *.json  encryption-config.yaml worker-* kube-* service-* 
