#!/bin/bash

set -e

# cp /home/kube-proxy.kubeconfig .
# cp /home/worker-$2.kubeconfig .
# cp /home/worker-$2.key .
# cp /home/worker-$2.crt .
# cp /home/ca.crt .

swapoff -a && sysctl vm.swappiness=0

mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes


mkdir -p containerd
tar -xvf crictl-${CRI_VERSION}-linux-${ARCH}.tar.gz
tar -xvf containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz -C containerd
tar -xvf cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz -C /opt/cni/bin/
mv runc.${ARCH} runc
chmod +x crictl kube-proxy kubelet runc 
mv crictl kube-proxy kubelet runc /usr/local/bin/
mv containerd/bin/* /bin/
rm -f *.gz *.tgz

MASTER_POD_CIDR=10.172.0.0/24

cat <<EOF | tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "1.0.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${MASTER_POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF


cat <<EOF | tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "1.0.0",
    "name": "lo",
    "type": "loopback"
}
EOF


mkdir -p /etc/containerd/

cat << EOF | tee /etc/containerd/config.toml
version = 2

[plugins."io.containerd.grpc.v1.cri"]
  # use fixed sandbox image
  sandbox_image = "registry.k8s.io/pause:3.10"
  # allow hugepages controller to be missing
  # see https://github.com/containerd/cri/pull/1501
  tolerate_missing_hugepages_controller = true
  # restrict_oom_score_adj needs to be true when running inside UserNS (rootless)
  restrict_oom_score_adj = false

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
      cni_conf_dir = "/etc/cni/net.d"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
        # use systemd cgroup by default
        SystemdCgroup = false

    # Setup a runtime with the magic name ("test-handler") used for Kubernetes
    # runtime class tests ...
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.test-handler]
      runtime_type = "io.containerd.runc.v2"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.test-handler.options]
        SystemdCgroup = false

  [plugins."io.containerd.grpc.v1.cri".cni]
    # bin_dir is the directory in which the binaries for the plugin is kept.
    bin_dir = "/opt/cni/bin"
    # conf_dir is the directory in which the admin places a CNI conf.
    conf_dir = "/etc/cni/net.d"

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
cgroupDriver: "cgroupfs"
kubeletCgroups: "/system.slice/kubelet.service"
cgroupsPerQOS: true
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.crt"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
logging:
  verbosity: 2
memorySwap: {}
resolvConf: "/run/systemd/resolve/resolv.conf"
containerRuntimeEndpoint: "unix:///run/containerd/containerd.sock"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.crt"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}.key"
maxPods: 50
failSwapOn: false
podCIDR: "${MASTER_POD_CIDR}"
healthzBindAddress: "127.0.0.1"
healthzPort: 10248
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

chmod 600 /etc/systemd/system/kubelet.service
cp kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig


cat <<EOF | tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
bindAddress: "0.0.0.0"
bindAddressHardFail: false
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
clusterCIDR: "10.172.0.0/16"
mode: "ipvs"
conntrack:
  maxPerCore: 0
EOF


cat <<EOF | tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml \\
  --config-sync-period=1m0s \\
  --v=2
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
  if [[ $NODE_COUNT != 0 ]]
  then
    ip r add 10.172.$NODE_COUNT.0/24 via 172.172.1.$NODE_COUNT 
  fi
NODE_COUNT=$((NODE_COUNT-1))
done