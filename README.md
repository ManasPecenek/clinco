# clinco 
# Cluster in Container

-------------

## BEFORE WE START

Let us take a look at the Docker image used for nodes

The ubuntu based images "petschenek/ubuntu-systemd:master (581MB) and petschenek/ubuntu-systemd:worker (531MB)" have systemd installed in them. You can check the [Dockerfile for master](https://github.com/ManasPecenek/clinco/blob/main/master%20image/Dockerfile) and  [Dockerfile for worker](https://github.com/ManasPecenek/clinco/blob/main/worker%20image/Dockerfile)

In these Dockerfiles there are three important points:
1. We need to tell systemd that it is in Docker. `ENV container=docker`
2. We need to declare the stopsignal different than the default stopsignal of Docker which is SIGTERM whereas systemd exits on SIGRTMIN+3. `STOPSIGNAL SIGRTMIN+3`
3. We need to declare a volume for `/var/lib/containerd` in worker node image because the filesystem of pods that will be created in the cluster must be a normal filesystem. `VOLUME ["/var/lib/containerd"]`

--------------

## PREREQUISITES

* kubectl tool must be installed on your host where you installed Docker in the first place:

* `curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && chmod +x kubectl && mv ./kubectl /usr/local/bin/kubectl`

* And also `cfssl` and `cfssljson`must be installed on your host:

* `curl -LO https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssl && curl -LO https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssljson `
  
* `chmod +x cfssl cfssljson && sudo mv cfssl cfssljson /usr/local/bin/ `


## LET US START

## 1) Create a Docker bridge network

Since the default bridge network that docker uses by default cannot provide automatic DNS resolution between containers, we need to create a user defined one:

* `docker network create --driver=bridge --subnet=172.172.0.0/16 --gateway=172.172.172.172 --scope=local --attachable=false --ingress=false macaroni`


## 2) Create the cluster

Download the scripts:
* `git clone https://github.com/ManasPecenek/clinco.git && cd clinco && chmod +x initial-script.sh master.sh worker.sh `

Now run the script with how many worker nodes you want. For example "./initial-script.sh 3" will result in a 3-worker-node cluster:
* `./initial-script.sh <worker-node-count>`

Notes: During the docker run stage in the `initial-script.sh`, we need to mount /lib/modules to worker nodes as a read-only volume for containerd to be able to run `modprobe overlay`. Also we do not want to lose the certificates and scripts in `/root` folder, so we mount a volume at `/root` directory.

## 3) Check the cluster

* `docker ps`

<img width="1040" alt="Screen Shot 2021-11-23 at 21 21 03" src="https://user-images.githubusercontent.com/61777390/143082059-8725dc8a-c93d-4381-98ca-0c1ffbd85099.png">

* `kubectl cluster-info --kubeconfig admin.kubeconfig`

<img width="599" alt="Screen Shot 2021-11-23 at 21 21 36" src="https://user-images.githubusercontent.com/61777390/143082142-0a1a9d9c-a9bd-4c6d-a86f-b3095512af8f.png">

* `kubectl get nodes -o wide --kubeconfig admin.kubeconfig`

<img width="917" alt="Screen Shot 2021-11-23 at 21 22 13" src="https://user-images.githubusercontent.com/61777390/143082231-babd079e-48c9-48ca-b791-ec9258e1f33e.png">

* `kubectl create deploy nginx --image nginx --replicas 4 --kubeconfig admin.kubeconfig`

* `kubectl get pods -o wide --kubeconfig admin.kubeconfig `

<img width="869" alt="Screen Shot 2021-11-24 at 08 16 33" src="https://user-images.githubusercontent.com/61777390/143179047-e2ae0bb2-b033-4922-b477-0fce0e224b8f.png">



------------

## RESOURCES

* [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)


## Some Notes

* You do not have to take snapshots of your cluster, as soon as `/var/lib/docker/volumes/etcd` volume in your host machine persists, you will not lose any cluster data even if your nodes get deleted.

* To recover your cluster after the deletion of master node is via this command `docker run -dt --network macaroni --hostname master --name master -v master:/root -v etcd:/lib/etcd -v /sys/fs/cgroup:/sys/fs/cgroup:ro --ip=172.172.0.1 -p 6443:6443 -p 80:80 --privileged --user root petschenek/ubuntu-systemd && docker exec -it --privileged --user root master bash -c "./master.sh"`

* If one of the worker nodes, worker-1 for instance, gets deleted then this command `docker run -dt --network macaroni --hostname worker-1 --name worker-1 -v /lib/modules:/lib/modules:ro -v worker-1:/root -v /sys/fs/cgroup:/sys/fs/cgroup:ro --ip=172.172.0.2 --privileged --user root petschenek/ubuntu-systemd && docker exec -it --privileged --user root worker-1 bash -c "./worker.sh"` is what you need to run

* If you want to add additional worker nodes, all you need to do is run `./add_worker.sh <number>`. For example `./add_worker.sh 2` will add two additional nodes into your cluster

## Testing Disaster Recovery

1) First off all, `etcd` volume under `/var/lib/docker/volumes` SHOULD NOT get deleted, otherwise you will lose your cluster data. You can find the storage location of Docker for various systems below

<img width="698" alt="Screen Shot 2021-11-26 at 22 03 19" src="https://user-images.githubusercontent.com/61777390/143622017-7f0f6946-5025-4d40-ab99-756e9be18747.png">

2) Now just delete all of the containers via docker `rm -f $(docker ps -aq)`

3) Now create the cluster again with `./initial-script.sh <worker-node-count>`

4) You will see that the cluster state has been persisted







