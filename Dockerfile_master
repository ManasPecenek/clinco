FROM ubuntu:21.10

ENV container=docker 

WORKDIR /root

RUN apt update -y && apt upgrade -y && apt install -y wget systemd systemd-cron sudo nginx && apt clean -y

RUN wget -q --show-progress --https-only --timestamping \
"https://github.com/etcd-io/etcd/releases/download/v3.4.15/etcd-v3.4.15-linux-amd64.tar.gz" \
"https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-apiserver" \
"https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-controller-manager" \
"https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-scheduler" \
"https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubectl"

STOPSIGNAL SIGRTMIN+3

ENTRYPOINT ["/sbin/init"]



