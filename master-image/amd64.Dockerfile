FROM --platform=linux/amd64 ubuntu:22.04

ENV container=docker 
ENV K8S_VERSION=v1.26.1
ENV ETCD_VERSION=v3.5.7

WORKDIR /root

RUN apt update && apt upgrade -y && apt install wget systemd systemd-cron -y && apt clean -y

RUN wget -q --show-progress --https-only --timestamping \
"https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kube-apiserver" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kube-controller-manager" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kube-scheduler" \
"https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kubectl"

RUN wget "https://dl.k8s.io/release/$(wget -qO- https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

RUN chmod +x kubectl && mv ./kubectl /usr/local/bin/kubectl
RUN wget -o cfssl https://pkg.cfssl.org/R1.2/cfssl_darwin-amd64
RUN wget -o cfssljson https://pkg.cfssl.org/R1.2/cfssljson_darwin-amd64
RUN chmod +x cfssl cfssljson && mv cfssl cfssljson /usr/local/bin/

COPY ./init.sh .
COPY ./add.sh .
COPY ./amd64-master.sh .

RUN chmod +x init.sh add.sh  amd64-master.sh


RUN apt install libnss3-tools -y
RUN wget --content-disposition "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
RUN chmod +x mkcert-v*-linux-amd64
RUN mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert


STOPSIGNAL SIGRTMIN+3

ENTRYPOINT ["/sbin/init"]



