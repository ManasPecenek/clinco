FROM ubuntu:22.04

ARG TARGETARCH

ENV ARCH=${TARGETARCH}
ENV container=docker 
ENV K8S_VERSION=v1.31.0
ENV ETCD_VERSION=v3.5.16

WORKDIR /root

RUN apt update && \
    apt install wget systemd systemd-cron kmod socat conntrack ipset iproute2 -y && \
    apt clean autoclean && \
    apt autoremove --yes

RUN wget -q --show-progress --https-only --timestamping \
"https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-${TARGETARCH}.tar.gz" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kube-apiserver" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kube-controller-manager" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kube-scheduler" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
"https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRI_VERSION}/crictl-${CRI_VERSION}-linux-${TARGETARCH}.tar.gz" \
"https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.${TARGETARCH}" \
"https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${TARGETARCH}-${CNI_VERSION}.tgz" \
"https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${TARGETARCH}.tar.gz" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kube-proxy"\
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kubelet"

COPY ca.conf init.sh add.sh master.sh worker.sh ./

RUN chmod +x init.sh add.sh master.sh worker.sh kubectl \
    && mv ./kubectl /usr/local/bin/kubectl

STOPSIGNAL SIGRTMIN+3

ENTRYPOINT ["/sbin/init"]



