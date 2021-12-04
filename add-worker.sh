#!/bin/bash

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

if [ "$(uname)" = "Darwin" ]
then
  KUBERNETES_PUBLIC_ADDRESS=$(hostname)
elif [ "$(uname)" = "Linux" ]
then
  KUBERNETES_PUBLIC_ADDRESS=$(hostname -i)
fi

docker cp master:/root/ca.pem . && docker cp master:/root/ca-key.pem .

current=$(docker ps | grep worker | tail -n 1 | rev | cut -b 1)

i=$(($1 + $current))

while [ $i -gt $current ]
do
docker run -dt --network macaroni --hostname worker-$i --name worker-$i -v worker-$i:/root -v /lib/modules:/lib/modules:ro -v /sys/fs/cgroup:/sys/fs/cgroup:ro --ip=172.172.1.$i --privileged --user root petschenek/ubuntu-systemd:worker

instance=worker

cat > ${instance}-$i-csr.json <<EOF
{
  "CN": "system:node:${instance}-$i",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "clinco Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

EXTERNAL_IP=172.172.1.$i
INTERNAL_IP=127.0.0.1

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance}-$i,${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-$i-csr.json | cfssljson -bare ${instance}-$i


docker cp ca.pem ${instance}-$i:/root/
docker cp ${instance}-$i-key.pem ${instance}-$i:/root/
docker cp ${instance}-$i.pem ${instance}-$i:/root/

kubectl config set-cluster clinco-the-hard-way \
--certificate-authority=ca.pem \
--embed-certs=true \
--server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
--kubeconfig=${instance}-$i.kubeconfig

kubectl config set-credentials system:node:${instance}-$i \
--client-certificate=${instance}-$i.pem \
--client-key=${instance}-$i-key.pem \
--embed-certs=true \
--kubeconfig=${instance}-$i.kubeconfig

kubectl config set-context default \
--cluster=clinco-the-hard-way \
--user=system:node:${instance}-$i \
--kubeconfig=${instance}-$i.kubeconfig

kubectl config use-context default --kubeconfig=${instance}-$i.kubeconfig

docker cp worker-1:/root/kube-proxy.kubeconfig .
docker cp kube-proxy.kubeconfig ${instance}-$i:/root/

docker cp ${instance}-$i.kubeconfig ${instance}-$i:/root/

#docker cp worker.sh ${instance}-$i:/root/
docker exec -it --privileged --user root ${instance}-$i bash -c "./worker.sh"

i=$((i-1))
done

rm -f *.csr *.pem *.json  encryption-config.yaml worker-* kube-* service-* 
