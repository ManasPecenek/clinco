#!/bin/bash


if [ -z "$(docker network ls | grep macaroni)" ]
then
docker network create --driver=bridge --subnet=172.172.0.0/16 --gateway=172.172.172.172 --scope=local --attachable=false --ingress=false macaroni
fi

docker run -dt --network macaroni --hostname master --name master -v master:/root -v etcd:/var/lib/etcd -v /sys/fs/cgroup:/sys/fs/cgroup:ro --ip=172.172.0.1 -p 6443:6443 -p 80:80 --privileged --user root petschenek/ubuntu-systemd:master

i=$1
while [ $i -gt 0 ]
do
docker run -dt --network macaroni --hostname worker-$i --name worker-$i -v worker-$i:/root -v /lib/modules:/lib/modules:ro -v /sys/fs/cgroup:/sys/fs/cgroup:ro --ip=172.172.1.$i --privileged --user root petschenek/ubuntu-systemd:worker
i=$((i-1))
done
i=$1


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

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "clinco Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin


cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "clinco Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "clinco Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "clinco Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

if [ "$(uname)" = "Darwin" ]
then
  KUBERNETES_PUBLIC_ADDRESS=$(hostname)
elif [ "$(uname)" = "Linux" ]
then
  KUBERNETES_PUBLIC_ADDRESS=$(hostname -i)
fi

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "clinco Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,172.172.0.1,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes


cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "clinco Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

docker cp ca.pem master:/root/
docker cp ca-key.pem master:/root/
docker cp kubernetes-key.pem master:/root/
docker cp kubernetes.pem master:/root/
docker cp service-account-key.pem master:/root/
docker cp service-account.pem master:/root/
  
#########################################################################################################################
while [ $i -gt 0 ]
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

kubectl config set-cluster kubernetes-the-hard-way \
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
--cluster=kubernetes-the-hard-way \
--user=system:node:${instance}-$i \
--kubeconfig=${instance}-$i.kubeconfig

kubectl config use-context default --kubeconfig=${instance}-$i.kubeconfig

i=$((i-1))
done
i=$1
#########################################################################################################################

kubectl config set-cluster kubernetes-the-hard-way \
--certificate-authority=ca.pem \
--embed-certs=true \
--server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
--kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
--client-certificate=kube-proxy.pem \
--client-key=kube-proxy-key.pem \
--embed-certs=true \
--kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
--cluster=kubernetes-the-hard-way \
--user=system:kube-proxy \
--kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig


kubectl config set-cluster kubernetes-the-hard-way \
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
--cluster=kubernetes-the-hard-way \
--user=system:kube-controller-manager \
--kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig


kubectl config set-cluster kubernetes-the-hard-way \
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
--cluster=kubernetes-the-hard-way \
--user=system:kube-scheduler \
--kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig


kubectl config set-cluster kubernetes-the-hard-way \
--certificate-authority=ca.pem \
--embed-certs=true \
--server=https://127.0.0.1:6443 \
--kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
--client-certificate=admin.pem \
--client-key=admin-key.pem \
--embed-certs=true \
--kubeconfig=admin.kubeconfig

kubectl config set-context default \
--cluster=kubernetes-the-hard-way \
--user=admin \
--kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig


docker cp admin.kubeconfig master:/root/
docker cp kube-scheduler.kubeconfig master:/root/
docker cp kube-controller-manager.kubeconfig master:/root/


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

docker cp encryption-config.yaml master:/root/

docker cp master.sh master:/root/

docker exec -it --privileged --user root master bash -c "./master.sh"

#########################################################################################################################
while [ $i -gt 0 ]
do
docker cp ${instance}-$i.kubeconfig ${instance}-$i:/root/
docker cp kube-proxy.kubeconfig ${instance}-$i:/root/

docker cp worker.sh ${instance}-$i:/root/
docker exec -it --privileged --user root ${instance}-$i bash -c "./worker.sh"
i=$((i-1))
done
#########################################################################################################################
rm -f *.csr *.pem *.json  encryption-config.yaml worker-* kube-* service-* 

