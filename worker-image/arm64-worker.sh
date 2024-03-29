#!/bin/bash

swapoff -a && sysctl vm.swappiness=0

mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes


mkdir -p containerd
tar -xvf crictl-${CRI_VERSION}-linux-arm64.tar.gz
tar -xvf containerd-${CONTAINERD_VERSION}-linux-arm64.tar.gz -C containerd
tar -xvf cni-plugins-linux-arm64-${CNI_VERSION}.tgz -C /opt/cni/bin/
mv runc.arm64 runc
chmod +x crictl kubectl kube-proxy kubelet runc 
mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
mv containerd/bin/* /bin/
rm -f *.gz *.tgz


i=$(hostname -s | cut -b 8)
POD_CIDR=10.172.$i.0/24

cat <<EOF | tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.4.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF


cat <<EOF | tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.4.0",
    "name": "lo",
    "type": "loopback"
}
EOF


mkdir -p /etc/containerd/

cat << EOF | tee /etc/containerd/config.toml
version = 2

[plugins."io.containerd.grpc.v1.cri".containerd]
  # save disk space when using a single snapshotter
  discard_unpacked_layers = true
  # explicitly use default snapshotter so we can sed it in entrypoint
  snapshotter = "overlayfs"
  # explicit default here, as we're configuring it below
  default_runtime_name = "runc"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  # set default runtime handler to v2, which has a per-pod shim
  runtime_type = "io.containerd.runc.v2"

# Setup a runtime with the magic name ("test-handler") used for Kubernetes
# runtime class tests ...
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.test-handler]
  runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri"]
  # use fixed sandbox image
  sandbox_image = "k8s.gcr.io/pause:3.5"
  # allow hugepages controller to be missing
  # see https://github.com/containerd/cri/pull/1501
  tolerate_missing_hugepages_controller = true
  # restrict_oom_score_adj needs to be true when running inside UserNS (rootless)
  restrict_oom_score_adj = false
EOF


cat <<EOF | tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

HOSTNAME=$(hostname -s)

cp ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
cp ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
cp ca.pem /var/lib/kubernetes/


cat <<EOF | tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF

cat <<EOF | tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --register-schedulable=true \\
  --register-node=true \\
  --v=2 \\
  --fail-swap-on=false \\
  --pod-infra-container-image=k8s.gcr.io/pause:3.6
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


cp kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig


cat <<EOF | tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.172.0.0/16"
conntrack:
  maxPerCore: 0
EOF


cat <<EOF | tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
systemctl enable containerd kubelet kube-proxy
systemctl start containerd kubelet kube-proxy

NODE_COUNT=$1
while [[ $NODE_COUNT -gt 0 ]]
do
  if [[ $NODE_COUNT != $i ]] 
  then
    ip r add 10.172.$NODE_COUNT.0/24 via 172.172.1.$NODE_COUNT 
  fi
NODE_COUNT=$((NODE_COUNT-1))
done