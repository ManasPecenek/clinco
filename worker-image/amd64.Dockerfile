FROM --platform=linux/amd64 ubuntu:21.10

ENV container=docker 

WORKDIR /root

VOLUME ["/var/lib/containerd"]

RUN apt update -y && apt upgrade -y && apt install -y wget systemd systemd-cron sudo kmod socat conntrack ipset iproutes2 && apt clean -y

RUN wget -q --show-progress --https-only --timestamping \
https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.22.0/crictl-v1.22.0-linux-amd64.tar.gz \
https://github.com/opencontainers/runc/releases/download/v1.1.1/runc.amd64 \
https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-arm64-v1.1.1.tgz \
https://github.com/containerd/containerd/releases/download/v1.5.8/containerd-1.5.8-linux-amd64.tar.gz \
https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubectl \
https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-proxy \
https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubelet

COPY ./amd64-worker.sh .

RUN chmod +x amd64-worker.sh

STOPSIGNAL SIGRTMIN+3

RUN apt update && apt install -y iproute2

ENTRYPOINT ["/sbin/init"]
