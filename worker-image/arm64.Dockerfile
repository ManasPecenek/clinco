FROM --platform=linux/arm64 ubuntu:21.10

ENV container=docker 

WORKDIR /root

VOLUME ["/var/lib/containerd"]

RUN apt update -y && apt upgrade -y && apt install -y wget systemd systemd-cron sudo kmod socat conntrack ipset && apt clean -y

RUN wget -q --show-progress --https-only --timestamping \
https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.22.0/crictl-v1.22.0-linux-arm64.tar.gz \
https://github.com/opencontainers/runc/releases/download/v1.1.1/runc.arm64 \
https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-arm64-v1.1.1.tgz \
https://github.com/containerd/containerd/releases/download/v1.6.3/containerd-1.6.3-linux-arm64.tar.gz \
https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/arm64/kubectl \
https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/arm64/kube-proxy \
https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/arm64/kubelet

COPY ./arm64-worker.sh .

RUN chmod +x arm64-worker.sh

STOPSIGNAL SIGRTMIN+3

RUN apt update && apt install -y iproute2

ENTRYPOINT ["/sbin/init"]
