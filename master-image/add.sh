#!/bin/bash

set -e

i=$1
current=$2

while [ $i -gt $current ]
do

  instance=worker
  INTERNAL_IP=172.172.1.$i
  KUBERNETES_PUBLIC_ADDRESS=$3
  EXTERNAL_IP=${KUBERNETES_PUBLIC_ADDRESS}

  cat <<EOF > ca-worker.conf
  [${instance}-${i}]
  distinguished_name = ${instance}-${i}_distinguished_name
  prompt             = no
  req_extensions     = ${instance}-${i}_req_extensions

  [${instance}-${i}_req_extensions]
  basicConstraints     = CA:FALSE
  extendedKeyUsage     = clientAuth, serverAuth
  keyUsage             = critical, digitalSignature, keyEncipherment
  nsCertType           = client
  nsComment            = "${instance}-${i} Certificate"
  subjectAltName       = DNS:${instance}-${i}, IP:127.0.0.1
  subjectKeyIdentifier = hash

  [${instance}-${i}_distinguished_name]
  CN = system:node:${instance}-${i}
  O  = system:nodes
  C  = US
  ST = Washington
  L  = Seattle
EOF

  openssl genrsa -out "${instance}-${i}.key" 4096

  openssl req -new -key "${instance}-${i}.key" -sha256 \
    -config "ca-worker.conf" -section ${instance}-${i} \
    -out "${instance}-${i}.csr"

  openssl x509 -req -days 3653 -in "${instance}-${i}.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "${instance}-${i}.crt"

  # cfssl gencert \
  #   -ca=ca.crt \
  #   -ca-key=ca.key \
  #   -config=ca-config.json \
  #   -hostname=${instance}-$i,${EXTERNAL_IP},${INTERNAL_IP} \
  #   -profile=kubernetes \
  #   ${instance}-$i-csr.json | cfssljson -bare ${instance}-$i


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
