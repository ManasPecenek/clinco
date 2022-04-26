FROM --platform=linux/arm64 ubuntu:21.10

ENV container=docker 

WORKDIR /root

VOLUME ["/var/lib/containerd"]

RUN apt update -y && apt upgrade -y && apt install -y wget systemd systemd-cron sudo kmod socat conntrack ipset && apt clean -y

RUN wget -q --show-progress --https-only --timestamping \
https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.22.0/crictl-v1.22.0-linux-amd64.tar.gz \
https://github.com/opencontainers/runc/releases/download/v1.0.0-rc93/runc.amd64 \
https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-amd64-v0.9.1.tgz \
https://github.com/containerd/containerd/releases/download/v1.5.8/containerd-1.5.8-linux-amd64.tar.gz \
https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubectl \
https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-proxy \
https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubelet

COPY ./worker.sh .

RUN chmod +x worker.sh

STOPSIGNAL SIGRTMIN+3

ENTRYPOINT ["/sbin/init"]
