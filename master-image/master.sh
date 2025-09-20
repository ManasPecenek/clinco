#!/bin/bash

set -e

./init.sh $1 $2

tar -xvf etcd-${ETCD_VERSION}-linux-${ARCH}.tar.gz
mv etcd-${ETCD_VERSION}-linux-${ARCH}/etcd* /usr/local/bin/
mkdir -p /etc/etcd /var/lib/etcd
groupadd etcd && useradd -r -s /bin/false -g etcd etcd
chown -R etcd:etcd /etc/etcd /var/lib/etcd
chmod -R 700 /var/lib/etcd
cp ca.crt kube-api-server.crt kube-api-server.key /etc/etcd/
rm -rf etcd*

export MASTER_IP=172.172.0.1

export ETCD_NAME=$(hostname -s)

export KUBERNETES_PUBLIC_ADDRESS=$2

cat <<EOF | tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/etcd-io/etcd

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name=${ETCD_NAME} \\
  --log-outputs=default \\
  --initial-cluster-state=${ETCD_STATE} \\
  --cert-file=/etc/etcd/kube-api-server.crt \\
  --key-file=/etc/etcd/kube-api-server.key \\
  --peer-cert-file=/etc/etcd/kube-api-server.crt \\
  --peer-key-file=/etc/etcd/kube-api-server.key \\
  --peer-trusted-ca-file=/etc/etcd/ca.crt \\
  --peer-client-cert-auth=true \\
  --trusted-ca-file=/etc/etcd/ca.crt \\
  --client-cert-auth=true \\
  --initial-advertise-peer-urls=https://${MASTER_IP}:2380 \\
  --initial-cluster=master=https://${MASTER_IP}:2380 \\
  --initial-cluster-token=etcd-cluster-0 \\
  --listen-peer-urls=https://${MASTER_IP}:2380 \\
  --listen-client-urls=https://${MASTER_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls=https://${MASTER_IP}:2379 \\
  --snapshot-count=10000 \\
  --log-level=debug \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now etcd

sleep 5

mkdir -p /etc/kubernetes/config

chmod +x kube-apiserver kube-controller-manager kube-scheduler
mv kube-apiserver kube-controller-manager kube-scheduler /usr/local/bin/

mkdir -p /var/lib/kubernetes/

cp ca.crt ca.key \
  kube-api-server.crt \
  kube-api-server.key \
  service-accounts.key \
  service-accounts.crt \
  encryption-config.yaml \
  /var/lib/kubernetes/


cat <<EOF | tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${MASTER_IP} \\
  --bind-address=0.0.0.0 \\
  --allow-privileged=true \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/kube-apiserver-audit.log \\
  --authorization-mode=Node,RBAC \\
  --secure-port=6443 \\
  --client-ca-file=/var/lib/kubernetes/ca.crt \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.crt \\
  --etcd-certfile=/var/lib/kubernetes/kube-api-server.crt \\
  --etcd-keyfile=/var/lib/kubernetes/kube-api-server.key \\
  --etcd-servers=https://127.0.0.1:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.crt \\
  --kubelet-client-certificate=/var/lib/kubernetes/kube-api-server.crt \\
  --kubelet-client-key=/var/lib/kubernetes/kube-api-server.key \\
  --service-account-key-file=/var/lib/kubernetes/service-accounts.crt \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-accounts.key \\
  --service-account-issuer=https://kubernetes.default.svc.cluster.local \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kube-api-server.crt \\
  --tls-private-key-file=/var/lib/kubernetes/kube-api-server.key \\
  --enable-bootstrap-token-auth=true \\
  --kubelet-preferred-address-types=InternalIP,Hostname,InternalDNS,ExternalDNS,ExternalIP \\
  --proxy-client-cert-file=/var/lib/kubernetes/ca.crt \\
  --proxy-client-key-file=/var/lib/kubernetes/ca.key \\
  --requestheader-client-ca-file=/var/lib/kubernetes/ca.crt \\
  --requestheader-allowed-names= \\
  --requestheader-extra-headers-prefix=X-Remote-Extra- \\
  --requestheader-group-headers=X-Remote-Group \\
  --requestheader-username-headers=X-Remote-User \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

 #   --enable-aggregator-routing=true \\

systemctl daemon-reload
systemctl enable --now kube-apiserver

sleep 5

cp kube-controller-manager.kubeconfig /var/lib/kubernetes/


cat <<EOF | tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=127.0.0.1 \\
  --cluster-cidr=10.172.0.0/16 \\
  --allocate-node-cidrs=true \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.crt \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca.key \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --authentication-kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --authorization-kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --controllers="*" \\
  --root-ca-file=/var/lib/kubernetes/ca.crt \\
  --client-ca-file=/var/lib/kubernetes/ca.crt \\
  --service-account-private-key-file=/var/lib/kubernetes/service-accounts.key \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now kube-controller-manager

sleep 5

cp kube-scheduler.kubeconfig /var/lib/kubernetes/

cat <<EOF | tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --authentication-kubeconfig=/var/lib/kubernetes/kube-scheduler.kubeconfig \\
  --authorization-kubeconfig=/var/lib/kubernetes/kube-scheduler.kubeconfig \\
  --kubeconfig=/var/lib/kubernetes/kube-scheduler.kubeconfig \\
  --bind-address=127.0.0.1 \\
  --leader-elect=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now kube-scheduler

sleep 5

cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF


