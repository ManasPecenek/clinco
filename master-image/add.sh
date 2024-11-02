#!/bin/bash

set -e

i=$1
current=$2

while [ $i -gt $current ]
do

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

KUBERNETES_PUBLIC_ADDRESS=$3

EXTERNAL_IP=${KUBERNETES_PUBLIC_ADDRESS} # 172.172.1.$i
INTERNAL_IP=172.172.1.$i # 127.0.0.1

cfssl gencert \
  -ca=ca.crt \
  -ca-key=ca.key \
  -config=ca-config.json \
  -hostname=${instance}-$i,${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-$i-csr.json | cfssljson -bare ${instance}-$i


kubectl config set-cluster clinco-the-hard-way \
--certificate-authority=ca.crt \
--embed-certs=true \
--server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
--kubeconfig=${instance}-$i.kubeconfig

kubectl config set-credentials system:node:${instance}-$i \
--client-certificate=${instance}-$i.pem \
--client-key=${instance}-$i-key.pem \
--embed-certs=true \
--kubeconfig=${instance}-$i.kubeconfig

kubectl config set-context ${CLUSTER_NAME} \
--cluster=clinco-the-hard-way \
--user=system:node:${instance}-$i \
--kubeconfig=${instance}-$i.kubeconfig

kubectl config use-context ${CLUSTER_NAME} --kubeconfig=${instance}-$i.kubeconfig

i=$((i-1))
done
