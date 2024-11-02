FROM ubuntu:22.04

ARG TARGETARCH

ENV ARCH=${TARGETARCH}
ENV container=docker 
ENV K8S_VERSION=v1.31.0
ENV ETCD_VERSION=v3.5.16

WORKDIR /root

RUN apt update && \
    apt install wget systemd systemd-cron -y && \
    apt clean autoclean && \
    apt autoremove --yes

RUN wget -q --show-progress --https-only --timestamping \
"https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-${TARGETARCH}.tar.gz" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kube-apiserver" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kube-controller-manager" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kube-scheduler" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kubectl"

RUN chmod +x kubectl && mv ./kubectl /usr/local/bin/kubectl

COPY ca.conf .
COPY init.sh .
COPY add.sh .
COPY master.sh .

RUN chmod +x init.sh add.sh master.sh

STOPSIGNAL SIGRTMIN+3

ENTRYPOINT ["/sbin/init"]



