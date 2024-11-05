FROM ubuntu:22.04

ARG TARGETARCH

ENV ARCH=${TARGETARCH}
ENV container=docker 
ENV CRI_VERSION=v1.31.0
ENV RUNC_VERSION=v1.1.15
ENV CNI_VERSION=v1.6.0
ENV CONTAINERD_VERSION=1.7.23
ENV K8S_VERSION=v1.31.0

WORKDIR /root

VOLUME ["/var/lib/containerd"]

RUN apt update && \
    apt install -y wget systemd systemd-cron kmod socat conntrack ipset iproute2 && \
    apt clean autoclean && \
    apt autoremove --yes

RUN wget -q --show-progress --https-only --timestamping \
https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRI_VERSION}/crictl-${CRI_VERSION}-linux-${TARGETARCH}.tar.gz \
https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.${TARGETARCH} \
https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${TARGETARCH}-${CNI_VERSION}.tgz \
https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${TARGETARCH}.tar.gz \
https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kubectl \
https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kube-proxy \
https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kubelet

COPY worker.sh .

RUN chmod +x worker.sh

STOPSIGNAL SIGRTMIN+3

ENTRYPOINT ["/sbin/init"]
