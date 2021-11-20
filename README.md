# clinco 
# Cluster in Container


## BEFORE WE START

Let us take a look at the Docker image used for nodes

The ubuntu based image "petschenek/ubuntu-systemd" has systemd installed in it. You can check the Dockerfile here: https://github.com/ManasPecenek/ubuntu/blob/main/systemd/Dockerfile

Here there are three important points. First, we need to tell systemd that it is in Docker. Second, we need to declare a volume for "/var" because the filesystem of pods that will be created in the cluster must be a normal filesystem. And last, we need to declare the stopsignal different than the default stopsignal of Docker which is SIGTERM whereas systemd exits on SIGRTMIN+3


## LET US START

## 1) Create a Docker bridge network

Since the default bridge network that docker uses by default cannot provide automatic DNS resolution between containers, we need to create a user defined one

`docker network create --driver=bridge --subnet=172.172.0.0/16 --gateway=172.172.172.172 --scope=local --attachable=false --ingress=false macaroni`


## 2) Create the cluster

git clone https://github.com/ManasPecenek/clinco.git && cd clinco

[./initial-script.sh](https://github.com/ManasPecenek/clinco/blob/main/initial-script.sh)
