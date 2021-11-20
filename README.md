# clinco 
# Cluster in Container


## BEFORE WE START

Let us take a look at the Docker image used for nodes

The ubuntu based image "petschenek/ubuntu-systemd" has systemd installed in it. You can check the Dockerfile here: https://github.com/ManasPecenek/ubuntu/blob/main/systemd/Dockerfile

In this Dockerfile there are three important points:
1. We need to tell systemd that it is in Docker. 
2. We need to declare a volume for "/var" because the filesystem of pods that will be created in the cluster must be a normal filesystem.
3. We need to declare the stopsignal different than the default stopsignal of Docker which is SIGTERM whereas systemd exits on SIGRTMIN+3

--------------

## LET US START

## 1) Create a Docker bridge network

##### Since the default bridge network that docker uses by default cannot provide automatic DNS resolution between containers, we need to create a user defined one

* `docker network create --driver=bridge --subnet=172.172.0.0/16 --gateway=172.172.172.172 --scope=local --attachable=false --ingress=false macaroni`


## 2) Create the cluster

* `git clone https://github.com/ManasPecenek/clinco.git && cd clinco`

* `chmod +x initial-script.sh master.sh worker.sh`

* `./initial-script.sh`

* During the docker run stage, we need to mount /lib/modules as a read-only volume for containerd to be able to run `modprobe overlay`. Also we do not want to lose the certificates and scripts in /root folder, so we mount a volume at /root directory.

------------

## RESOURCES

* [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)


## Some additional Advantages of clinco

* You do not need to take ETCD snapshots of your cluster, the data of your cluster is automatically saved. For example, in case of your worker node gets deleted you do not lose anything. When you create a new worker node, the cluster will be up and running again with the same state before the deletion of the worker node


* If worker node, for instance, gets deleted then this command `docker run -dt --network macaroni --hostname worker --name worker -v /lib/modules:/lib/modules:ro -v worker:/root --ip=172.172.0.2 --privileged --user root petschenek/ubuntu-systemd && docker exec -it --privileged --user root worker bash -c "worker.sh"` is what you need to run

* If worker node stops, you need to remove it and then run it again with `docker rm -f worker && docker run -dt --network macaroni --hostname worker --name worker -v /lib/modules:/lib/modules:ro -v worker:/root --ip=172.172.0.2 --privileged --user root petschenek/ubuntu-systemd && docker exec -it --privileged --user root worker bash -c "worker.sh`



