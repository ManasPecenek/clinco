# clinco - Cluster in Container

![clinco](https://user-images.githubusercontent.com/61777390/144721867-9fe2d85c-eaa3-4579-ba07-13ca7d23380f.png)

-------------

## BEFORE WE START

Let us take a look at the Docker images used for nodes

The ubuntu based images "[petschenek/ubuntu-systemd:master](https://hub.docker.com/repository/docker/petschenek/ubuntu-systemd) (compressed size 229MB) and [petschenek/ubuntu-systemd:worker](https://hub.docker.com/repository/docker/petschenek/ubuntu-systemd) (compressed size 232MB)" have systemd installed in them. You can check the [Dockerfile for master](https://github.com/ManasPecenek/clinco/blob/main/master%20image/Dockerfile) and  [Dockerfile for worker](https://github.com/ManasPecenek/clinco/blob/main/worker%20image/Dockerfile)

In these Dockerfiles there are three important points:
1. We need to tell systemd that it is in Docker. `ENV container=docker`
2. We need to declare the stopsignal different than the default stopsignal of Docker which is SIGTERM whereas systemd exits on SIGRTMIN+3. `STOPSIGNAL SIGRTMIN+3`
3. We need to declare a volume for `/var/lib/containerd` in worker node image because the filesystem of pods that will be created in the cluster must be a normal filesystem. When you run Docker in Docker, the outer Docker runs on top of a normal filesystem (EXT4, BTRFS etc), but the inner Docker runs on top of a copy-on-write system (AUFS, BTRFS etc). Since you cannot run AUFS on top of AUFS, you need to use `VOLUME ["/var/lib/containerd"]` in the Dockerfile or specify `-v /var/lib/containerd` during container creation.

--------------

## LET'S START

## 1) Create a cluster

Download the scripts:
* `git clone --depth=1 https://github.com/ManasPecenek/clinco.git && cd clinco && chmod +x initial-script.sh add-worker.sh && alias startCluster="bash initial-script.sh" addNode="bash add-worker.sh"`

Now run the script with how many worker nodes you want. For example "startCluster -n 3" will result in a 3-worker-node cluster:
* `startCluster -n <worker-node-count>`

If you do not specify worker node count, it will be "1" by default.

You can also specify a volume name for etcd in order to restore your cluster later on.

* `startCluster -n <worker-node-count> -v <volume-name>`

If you do not specify a volume name, it will be a random number.

You can check the etcd-volumes via `docker volume ls`

## 2) Check the cluster via Installing OPA Gatekeeper

* `docker ps`

<img width="1134" alt="Screen Shot 2021-12-04 at 16 03 55" src="https://user-images.githubusercontent.com/61777390/144710457-e0ee8d93-918e-486e-8aa6-a661fb3d93f9.png">

* `kubectl cluster-info` Note: If you cannot connect to the cluster by default, just run "export KUBECONFIG=./admin.kubeconfig" in the same directory.

<img width="722" alt="Screen Shot 2022-01-21 at 18 34 28" src="https://user-images.githubusercontent.com/61777390/150554773-a9ddc3d5-66a3-4d6b-ae07-02de87ffd65a.png">

* `kubectl get nodes -o wide`

<img width="903" alt="Screen Shot 2022-01-21 at 18 35 10" src="https://user-images.githubusercontent.com/61777390/150554858-68bf07f5-68cd-4d71-8c56-99761096d6bb.png">

* `kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.7/deploy/gatekeeper.yaml`

* `kubectl get pods -o wide -n gatekeeper-system`

<img width="1002" alt="Screen Shot 2022-01-21 at 18 45 42" src="https://user-images.githubusercontent.com/61777390/150556540-dfbf41ce-2718-4c20-a421-b0526ab5f638.png">


## 3) Add additional worker nodes

If you want to add additional worker nodes, all you need to do is run `addNode -n <number>`. For example `addNode -n 2` will add two additional nodes into your cluster. If you do not specify a number and run only `addNode`, it will add only 1 node to your cluster.

------------

## RESOURCES

* [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)


## Some Notes

* You do not have to take snapshots of your cluster, as soon as `/var/lib/docker/volumes/etcd` volume in your host machine persists, you will not lose any cluster data even if your nodes get deleted.


## Testing Disaster Recovery

1) First off all, `etcd-xxxx` volume under `/var/lib/docker/volumes` SHOULD NOT get deleted, otherwise you will lose your cluster data. You can find the storage location of Docker for various systems below

<img width="698" alt="Screen Shot 2021-11-26 at 22 03 19" src="https://user-images.githubusercontent.com/61777390/143622017-7f0f6946-5025-4d40-ab99-756e9be18747.png">

2) Now just delete all of the containers via `docker rm -f $(docker ps -aq)`

3) Now create the cluster again with `startCluster -v <xxxx-part-of-the-etcd-volume> -n <any-number>`

4) You will see that the cluster state has been persisted


