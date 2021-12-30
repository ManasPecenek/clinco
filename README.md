# clinco - Cluster in Container

![clinco](https://user-images.githubusercontent.com/61777390/144721867-9fe2d85c-eaa3-4579-ba07-13ca7d23380f.png)

-------------

## BEFORE WE START

Let us take a look at the Docker images used for nodes

The ubuntu based images "[petschenek/ubuntu-systemd:master](https://hub.docker.com/repository/docker/petschenek/ubuntu-systemd) (compressed size 229MB) and [petschenek/ubuntu-systemd:worker](https://hub.docker.com/repository/docker/petschenek/ubuntu-systemd) (compressed size 232MB)" have systemd installed in them. You can check the [Dockerfile for master](https://github.com/ManasPecenek/clinco/blob/main/master%20image/Dockerfile) and  [Dockerfile for worker](https://github.com/ManasPecenek/clinco/blob/main/worker%20image/Dockerfile)

In these Dockerfiles there are three important points:
1. We need to tell systemd that it is in Docker. `ENV container=docker`
2. We need to declare the stopsignal different than the default stopsignal of Docker which is SIGTERM whereas systemd exits on SIGRTMIN+3. `STOPSIGNAL SIGRTMIN+3`
3. We need to declare a volume for `/var/lib/containerd` in worker node image because the filesystem of pods that will be created in the cluster must be a normal filesystem. `VOLUME ["/var/lib/containerd"]`

--------------

## LET'S START

## 1) Create a cluster

Download the scripts:
* `git clone --depth=1 https://github.com/ManasPecenek/clinco.git && cd clinco && chmod +x initial-script.sh add-worker.sh`

Now run the script with how many worker nodes you want. For example "./initial-script.sh 3" will result in a 3-worker-node cluster:
* `./initial-script.sh <worker-node-count>`

## 2) Check the cluster

* `docker ps`

<img width="1134" alt="Screen Shot 2021-12-04 at 16 03 55" src="https://user-images.githubusercontent.com/61777390/144710457-e0ee8d93-918e-486e-8aa6-a661fb3d93f9.png">

* `kubectl cluster-info --kubeconfig admin.kubeconfig`

<img width="599" alt="Screen Shot 2021-11-23 at 21 21 36" src="https://user-images.githubusercontent.com/61777390/143082142-0a1a9d9c-a9bd-4c6d-a86f-b3095512af8f.png">

* `kubectl get nodes -o wide --kubeconfig admin.kubeconfig`

<img width="1292" alt="Screen Shot 2021-12-04 at 16 08 14" src="https://user-images.githubusercontent.com/61777390/144710612-b25cf1dd-b9fa-4a63-858f-28db0f0e9af8.png">


* `kubectl create deploy nginx --image nginx --replicas 4 --kubeconfig admin.kubeconfig`

* `kubectl get pods -o wide --kubeconfig admin.kubeconfig `

<img width="1188" alt="Screen Shot 2021-12-04 at 16 08 42" src="https://user-images.githubusercontent.com/61777390/144710630-0788920e-1dcf-485f-bdad-09e6eb4964b7.png">

## 3) Add additional worker nodes

If you want to add additional worker nodes, all you need to do is run `./add-worker.sh <number>`. For example `./add-worker.sh 2` will add two additional nodes into your cluster

------------

## RESOURCES

* [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)


## Some Notes

* You do not have to take snapshots of your cluster, as soon as `/var/lib/docker/volumes/etcd` volume in your host machine persists, you will not lose any cluster data even if your nodes get deleted.

* To recover your cluster after the deletion of master node is via this command `docker run -dt --network clinco --hostname master --name master -v master:/root -v etcd:/lib/etcd -v /sys/fs/cgroup:/sys/fs/cgroup:ro --ip=172.172.0.1 -p 6443:6443 -p 80:80 --privileged --user root petschenek/ubuntu-systemd:master && docker exec -it --privileged --user root master bash -c "./master.sh"`

* If one of the worker nodes, worker-3 for instance, gets deleted then this command `j=3 && docker run -dt --network clinco --hostname worker-$j --name worker-$j -v /lib/modules:/lib/modules:ro -v worker-$j:/root -v /sys/fs/cgroup:/sys/fs/cgroup:ro --ip=172.172.0.$j --privileged --user root petschenek/ubuntu-systemd:worker && docker exec -it --privileged --user root worker-$j bash -c "./worker.sh"` is what you need to run


## Testing Disaster Recovery

1) First off all, `etcd` volume under `/var/lib/docker/volumes` SHOULD NOT get deleted, otherwise you will lose your cluster data. You can find the storage location of Docker for various systems below

<img width="698" alt="Screen Shot 2021-11-26 at 22 03 19" src="https://user-images.githubusercontent.com/61777390/143622017-7f0f6946-5025-4d40-ab99-756e9be18747.png">

2) Now just delete all of the containers via `docker rm -f $(docker ps -aq)`

3) Now create the cluster again with `./initial-script.sh <worker-node-count>`

4) You will see that the cluster state has been persisted







