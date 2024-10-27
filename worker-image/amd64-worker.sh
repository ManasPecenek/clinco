#!/bin/bash

set -e

cp /home/kube-proxy.kubeconfig .
cp /home/worker-$2.kubeconfig .
cp /home/worker-$2.key .
cp /home/worker-$2.crt .
cp /home/ca.crt .

swapoff -a && sysctl vm.swappiness=0

mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes


mkdir -p containerd
tar -xvf crictl-${CRI_VERSION}-linux-amd64.tar.gz
tar -xvf containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz -C containerd
tar -xvf cni-plugins-linux-amd64-${CNI_VERSION}.tgz -C /opt/cni/bin/
mv runc.amd64 runc
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

cp ${HOSTNAME}.key ${HOSTNAME}.crt /var/lib/kubelet/
cp ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
cp ca.crt /var/lib/kubernetes/


cat <<EOF | tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: "0s"
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.crt"
authorization:
  mode: "Webhook"
  webhook:
    cacheAuthorizedTTL: "0s"
    cacheUnauthorizedTTL: "0s"
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
resolvConf: "/run/systemd/resolve/resolv.conf"
containerRuntimeEndpoint: "unix:///var/run/containerd/containerd.sock"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.crt"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}.key"
cgroupDriver: "systemd"
cgroupsPerQOS: true
cpuManagerReconcilePeriod: "0s"
evictionHard:
  memory.available: "50Mi"
  imagefs.available: "0%"
  nodefs.available: "0%"
  nodefs.inodesFree: "0%"
evictionPressureTransitionPeriod: "0s"
failSwapOn: false
fileCheckFrequency: "0s"
healthzBindAddress: "127.0.0.1"
healthzPort: 10248
httpCheckFrequency: "0s"
logging:
  flushFrequency: 0
  options:
    json:
      infoBufferSize: "0"
    text:
      infoBufferSize: "0"
  verbosity: 0
memorySwap: {}
nodeStatusReportFrequency: "0s"
nodeStatusUpdateFrequency: "0s"
rotateCertificates: true
runtimeRequestTimeout: "0s"
shutdownGracePeriod: "0s"
shutdownGracePeriodCriticalPods: "0s"
staticPodPath: "/etc/kubernetes/manifests"
streamingConnectionIdleTimeout: "0s"
syncFrequency: "0s"
volumeStatsAggPeriod: "0s"
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
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --v=2
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
systemctl enable --now containerd kubelet kube-proxy
sleep 5


NODE_COUNT=$1
while [[ $NODE_COUNT -gt 0 ]]
do
  if [[ $NODE_COUNT != $i ]]
  then
    ip r add 10.172.$NODE_COUNT.0/24 via 172.172.1.$NODE_COUNT 
  fi
NODE_COUNT=$((NODE_COUNT-1))
done