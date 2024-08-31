#!/bin/bash

set -e

i=$1




KUBERNETES_PUBLIC_ADDRESS=$2

KUBERNETES_HOSTNAMES="kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster kubernetes.svc.cluster.local kubernetes.default.svc.cluster.local"

INTERNAL_IP=172.172.0.1

DOCKER_BRIDGE=172.17.0.1

mkcert -install

cp /root/.local/share/mkcert/rootCA-key.pem ca-key.pem

cp /root/.local/share/mkcert/rootCA.pem ca.pem

# mkcert -key-file ca-key.pem -cert-file ca.pem 127.0.0.1 10.32.0.1 ${KUBERNETES_PUBLIC_ADDRESS} ${INTERNAL_IP} ${KUBERNETES_HOSTNAMES} ${DOCKER_BRIDGE}

mkcert -key-file kubernetes-key.pem -cert-file kubernetes.pem 127.0.0.1 10.32.0.1 ${KUBERNETES_PUBLIC_ADDRESS} ${INTERNAL_IP} ${KUBERNETES_HOSTNAMES} ${DOCKER_BRIDGE}

mkcert -key-file service-account-key.pem -cert-file service-account.pem 127.0.0.1 10.32.0.1 ${KUBERNETES_PUBLIC_ADDRESS} ${INTERNAL_IP} ${KUBERNETES_HOSTNAMES} ${DOCKER_BRIDGE}

mkcert -key-file kube-proxy-key.pem -cert-file kube-proxy.pem 127.0.0.1 10.32.0.1 ${KUBERNETES_PUBLIC_ADDRESS} ${INTERNAL_IP} ${KUBERNETES_HOSTNAMES} ${DOCKER_BRIDGE}

mkcert -key-file kube-controller-manager-key.pem -cert-file kube-controller-manager.pem 127.0.0.1 10.32.0.1 ${KUBERNETES_PUBLIC_ADDRESS} ${INTERNAL_IP} ${KUBERNETES_HOSTNAMES} ${DOCKER_BRIDGE}
  
mkcert -key-file kube-scheduler-key.pem -cert-file kube-scheduler.pem 127.0.0.1 10.32.0.1 ${KUBERNETES_PUBLIC_ADDRESS} ${INTERNAL_IP} ${KUBERNETES_HOSTNAMES} ${DOCKER_BRIDGE}

mkcert -key-file admin-key.pem -cert-file admin.pem 127.0.0.1 10.32.0.1 ${KUBERNETES_PUBLIC_ADDRESS} ${INTERNAL_IP} ${KUBERNETES_HOSTNAMES} ${DOCKER_BRIDGE}

#########################################################################################################################
while [ $i -gt 0 ]
do

instance=worker

EXTERNAL_IP=${KUBERNETES_PUBLIC_ADDRESS} # 172.172.1.$i
INTERNAL_IP=172.172.1.$i # 127.0.0.1
MASTER_IP=172.172.0.1


mkcert -key-file worker-$i-key.pem -cert-file worker-$i.pem 127.0.0.1 ${EXTERNAL_IP} 10.32.0.1 ${MASTER_IP} ${INTERNAL_IP} ${KUBERNETES_HOSTNAMES} ${DOCKER_BRIDGE}

kubectl config set-cluster clinco-the-hard-way \
--certificate-authority=ca.pem \
--embed-certs=true \
--server=https://${MASTER_IP}:6443 \
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

i=$((i-1))
done
i=$1
#########################################################################################################################

kubectl config set-cluster clinco-the-hard-way \
--certificate-authority=ca.pem \
--embed-certs=true \
--server=https://${MASTER_IP}:6443 \
--kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
--client-certificate=kube-proxy.pem \
--client-key=kube-proxy-key.pem \
--embed-certs=true \
--kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
--cluster=clinco-the-hard-way \
--user=system:kube-proxy \
--kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig


kubectl config set-cluster clinco-the-hard-way \
--certificate-authority=ca.pem \
--embed-certs=true \
--server=https://127.0.0.1:6443 \
--kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
--client-certificate=kube-controller-manager.pem \
--client-key=kube-controller-manager-key.pem \
--embed-certs=true \
--kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
--cluster=clinco-the-hard-way \
--user=system:kube-controller-manager \
--kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig


kubectl config set-cluster clinco-the-hard-way \
--certificate-authority=ca.pem \
--embed-certs=true \
--server=https://127.0.0.1:6443 \
--kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
--client-certificate=kube-scheduler.pem \
--client-key=kube-scheduler-key.pem \
--embed-certs=true \
--kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
--cluster=clinco-the-hard-way \
--user=system:kube-scheduler \
--kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig


kubectl config set-cluster clinco-the-hard-way \
--certificate-authority=ca.pem \
--embed-certs=true \
--server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
--kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
--client-certificate=admin.pem \
--client-key=admin-key.pem \
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
