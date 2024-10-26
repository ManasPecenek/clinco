#!/bin/bash

set -e

i=$1




KUBERNETES_PUBLIC_ADDRESS=$2

KUBERNETES_HOSTNAMES="master kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster kubernetes.svc.cluster.local kubernetes.default.svc.cluster.local"

INTERNAL_IP=172.172.0.1

DOCKER_BRIDGE=172.17.0.1

certs=(
  "admin" "node-0" "node-1"
  "kube-proxy" "kube-scheduler"
  "kube-controller-manager"
  "kube-api-server"
  "service-accounts"
)

for i in ${certs[*]}; do
  openssl genrsa -out "${i}.key" 4096

  openssl req -new -key "${i}.key" -sha256 \
    -config "ca.conf" -section ${i} \
    -out "${i}.csr"
  
  openssl x509 -req -days 3653 -in "${i}.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "${i}.crt"
done


#########################################################################################################################
while [ $i -gt 0 ]
do

instance=worker

EXTERNAL_IP=${KUBERNETES_PUBLIC_ADDRESS} # 172.172.1.$i
INTERNAL_IP=172.172.1.$i # 127.0.0.1
MASTER_IP=172.172.0.1


kubectl config set-cluster clinco-the-hard-way \
--certificate-authority=ca.crt \
--embed-certs=true \
--server=https://${MASTER_IP}:6443 \
--kubeconfig=${instance}-$i.kubeconfig

kubectl config set-credentials system:node:${instance}-$i \
--client-certificate=${instance}-$i.crt \
--client-key=${instance}-$i.key \
--embed-certs=true \
--kubeconfig=${instance}-$i.kubeconfig

kubectl config set-context default \
--cluster=clinco-the-hard-way \
--user=system:node:${instance}-$i \
--kubeconfig=${instance}-$i.kubeconfig

kubectl config use-context default --kubeconfig=${instance}-$i.kubeconfig

i=$((i-1))
done
i=$1
#########################################################################################################################

kubectl config set-cluster clinco-the-hard-way \
--certificate-authority=ca.crt \
--embed-certs=true \
--server=https://${MASTER_IP}:6443 \
--kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
--client-certificate=kube-proxy.crt \
--client-key=kube-proxy.key \
--embed-certs=true \
--kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
--cluster=clinco-the-hard-way \
--user=system:kube-proxy \
--kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig


kubectl config set-cluster clinco-the-hard-way \
--certificate-authority=ca.crt \
--embed-certs=true \
--server=https://127.0.0.1:6443 \
--kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
--client-certificate=kube-controller-manager.crt \
--client-key=kube-controller-manager.key \
--embed-certs=true \
--kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
--cluster=clinco-the-hard-way \
--user=system:kube-controller-manager \
--kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig


kubectl config set-cluster clinco-the-hard-way \
--certificate-authority=ca.crt \
--embed-certs=true \
--server=https://127.0.0.1:6443 \
--kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
--client-certificate=kube-scheduler.crt \
--client-key=kube-scheduler.key \
--embed-certs=true \
--kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
--cluster=clinco-the-hard-way \
--user=system:kube-scheduler \
--kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig


kubectl config set-cluster clinco-the-hard-way \
--certificate-authority=ca.crt \
--embed-certs=true \
--server=https://172.172.0.1:6443 \
--kubeconfig=admin.kubeconfig
# --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \

kubectl config set-credentials admin \
--client-certificate=admin.crt \
--client-key=admin.key \
--embed-certs=true \
--kubeconfig=admin.kubeconfig

kubectl config set-context default \
--cluster=clinco-the-hard-way \
--user=admin \
--kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig


ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
