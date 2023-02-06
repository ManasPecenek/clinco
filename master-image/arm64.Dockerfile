FROM --platform=linux/arm64 ubuntu:22.04

ENV container=docker 
ENV K8S_VERSION=v1.26.1
ENV ETCD_VERSION=v3.5.7

WORKDIR /root

RUN apt update && apt upgrade -y && apt install wget systemd systemd-cron -y && apt clean -y

RUN wget -q --show-progress --https-only --timestamping \
"https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-arm64.tar.gz" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/arm64/kube-apiserver" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/arm64/kube-controller-manager" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/arm64/kube-scheduler" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/arm64/kubectl"

RUN wget "https://dl.k8s.io/release/$(wget -qO- https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl" \
&& chmod +x kubectl && mv ./kubectl /usr/local/bin/kubectl \
&& wget https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssl \
&& wget https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssljson \
&& chmod +x cfssl cfssljson && mv cfssl cfssljson /usr/local/bin/

COPY ./init.sh .
COPY ./add.sh .
COPY ./arm64-master.sh .

RUN chmod +x init.sh add.sh arm64-master.sh

STOPSIGNAL SIGRTMIN+3

ENTRYPOINT ["/sbin/init"]



