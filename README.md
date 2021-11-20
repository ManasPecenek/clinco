# clinco 
# Cluster in Container

## 1) Image used for containers

The ubuntu based image "petschenek/ubuntu-systemd" has systemd installed in it. You can check the Dockerfile here:

https://github.com/ManasPecenek/ubuntu/blob/main/systemd/Dockerfile

Here there are three important points. First, we need to tell systemd that it is in Docker. Second, we need to declare a volume for "/var" because the filesystem of pods that will be created in the cluster must be a normal filesystem. And last, we need to declare the stopsignal different than the default stopsignal of Docker which is SIGTERM whereas systemd exits on SIGRTMIN+3

## 2)
