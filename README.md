# clinco 
# Cluster in Container

-------------

## BEFORE WE START

Let us take a look at the Docker image used for nodes

The ubuntu based image "petschenek/ubuntu-systemd (215MB)" has systemd installed in it. You can check the [Dockerfile](https://github.com/ManasPecenek/clinco/blob/main/Dockerfile)

In this Dockerfile there are three important points:
1. We need to tell systemd that it is in Docker. `ENV container=docker`
2. We need to declare a volume for "/var/lib/containerd" because the filesystem of pods that will be created in the cluster must be a normal filesystem. `VOLUME ["/var/lib/containerd"]`
3. We need to declare the stopsignal different than the default stopsignal of Docker which is SIGTERM whereas systemd exits on SIGRTMIN+3. `STOPSIGNAL SIGRTMIN+3`

--------------

## PREREQUISITES

* kubectl tool must be installed on your host where you installed Docker in the first place

* `curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && chmod +x kubectl && mv ./kubectl /usr/local/bin/kubectl`

* And also `cfssl` and `cfssljson`must be installed on your host

* `wget https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssl \
  && wget https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssljson `
  
* `chmod +x cfssl cfssljson && sudo mv cfssl cfssljson /usr/local/bin/ `


## LET US START

## 1) Create a Docker bridge network

Since the default bridge network that docker uses by default cannot provide automatic DNS resolution between containers, we need to create a user defined one

* `docker network create --driver=bridge --subnet=172.172.0.0/16 --gateway=172.172.172.172 --scope=local --attachable=false --ingress=false macaroni`


## 2) Create the cluster

* `git clone https://github.com/ManasPecenek/clinco.git && cd clinco`

* `chmod +x initial-script.sh master.sh worker.sh`

* `./initial-script.sh`

During the docker run stage in the `initial-script.sh`, we need to mount /lib/modules as a read-only volume for containerd to be able to run `modprobe overlay`. Also we do not want to lose the certificates and scripts in `/root` folder, so we mount a volume at `/root` directory.

## 3) Check the cluster

* `docker ps`

<img width="1192" alt="Screen Shot 2021-11-20 at 19 47 23" src="https://user-images.githubusercontent.com/61777390/142734398-5e19324f-4ac2-4213-ac0b-d16e9ef2a7d5.png">

* `kubectl cluster-info --kubeconfig admin.kubeconfig`

<img width="897" alt="Screen Shot 2021-11-20 at 19 33 15" src="https://user-images.githubusercontent.com/61777390/142733930-cdca326c-3c83-4ff6-ab21-461c7d0297d4.png">

* `kubectl get nodes -o wide --kubeconfig admin.kubeconfig`

<img width="1389" alt="Screen Shot 2021-11-20 at 19 34 30" src="https://user-images.githubusercontent.com/61777390/142733968-019ddaad-2366-4c5b-9448-2603e45b1c74.png">

* `kubectl run nginx --image nginx --port 80 --kubeconfig admin.kubeconfig`

* `kubectl get pods -o wide --kubeconfig admin.kubeconfig `

<img width="1073" alt="Screen Shot 2021-11-20 at 19 37 08" src="https://user-images.githubusercontent.com/61777390/142734060-675e8351-6ba0-4287-bf74-3bfcdaa04aee.png">


------------

## RESOURCES

* [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)


## Some Notes

* You do not have to take snapshots of your cluster, as soon as /var/lib/docker/volumes/etcd volume in your host machine persists, you will not lose any cluster data even if your master node gets deleted.

* To recover your cluster after the deletion of master node is via this command `docker run -dt --network macaroni --hostname master --name master -v master:/root -v etcd:/lib/etcd --ip=172.172.0.1 -p 6443:6443 -p 80:80 --privileged --user root petschenek/ubuntu-systemd && docker exec -it --privileged --user root master bash -c "./master.sh"`

* If worker node, for instance, gets deleted then this command `docker run -dt --network macaroni --hostname worker --name worker -v /lib/modules:/lib/modules:ro -v worker:/root --ip=172.172.0.2 --privileged --user root petschenek/ubuntu-systemd && docker exec -it --privileged --user root worker bash -c "./worker.sh"` is what you need to run

* If worker node stops, you need to remove it and then run it again with `docker rm -f worker && docker run -dt --network macaroni --hostname worker --name worker -v /lib/modules:/lib/modules:ro -v worker:/root --ip=172.172.0.2 --privileged --user root petschenek/ubuntu-systemd && docker exec -it --privileged --user root worker bash -c "./worker.sh"`



