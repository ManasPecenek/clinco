FROM --platform=linux/arm64 ubuntu:22.04

ENV container=docker 
ENV CRI_VERSION=v1.26.0
ENV RUNC_VERSION=v1.1.4
ENV CNI_VERSION=v1.2.0
ENV CONTAINERD_VERSION=1.6.15
ENV K8S_VERSION=v1.26.1

WORKDIR /root

VOLUME ["/var/lib/containerd"]

RUN apt update -y && apt upgrade -y && apt install -y wget systemd systemd-cron sudo kmod socat conntrack ipset && apt clean -y

RUN wget -q --show-progress --https-only --timestamping \
https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRI_VERSION}/crictl-${CRI_VERSION}-linux-arm64.tar.gz \
https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.arm64 \
https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-arm64-${CNI_VERSION}.tgz \
https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-arm64.tar.gz \
https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/arm64/kubectl \
https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/arm64/kube-proxy \
https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/arm64/kubelet

COPY ./arm64-worker.sh .

RUN chmod +x arm64-worker.sh

STOPSIGNAL SIGRTMIN+3

RUN apt update && apt install -y iproute2

ENTRYPOINT ["/sbin/init"]
