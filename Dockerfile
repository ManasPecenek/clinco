FROM ubuntu:21.10

ENV container=docker 

WORKDIR /root

VOLUME ["/var"]

RUN apt update -y && apt upgrade -y && apt install -y wget systemd systemd-cron sudo && apt clean -y

STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]
