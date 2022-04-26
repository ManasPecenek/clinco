FROM --platform=linux/amd64 ubuntu:21.10

ENV container=docker 

WORKDIR /root

RUN apt update -y && apt upgrade -y && apt install -y wget systemd systemd-cron sudo nginx && apt clean -y

RUN wget -q --show-progress --https-only --timestamping \
"https://github.com/etcd-io/etcd/releases/download/v3.5.1/etcd-v3.5.1-linux-amd64.tar.gz" \
"https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-apiserver" \
"https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-controller-manager" \
"https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-scheduler" \
"https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubectl"

RUN wget "https://dl.k8s.io/release/$(wget -qO- https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
&& chmod +x kubectl && mv ./kubectl /usr/local/bin/kubectl \
&& wget https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssl \
&& wget https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssljson \
&& chmod +x cfssl cfssljson && sudo mv cfssl cfssljson /usr/local/bin/

COPY ./init.sh .
COPY ./add.sh .
COPY ./master.sh .

RUN chmod +x init.sh add.sh master.sh

STOPSIGNAL SIGRTMIN+3

ENTRYPOINT ["/sbin/init"]



