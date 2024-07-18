# Workshop Preparation

In order to participate in this workshop you should be able to provision a local Kubernetes cluster
and interact with it. In order to do this, you will need the following tools installed and working
correctly:

- `git`
- `docker`
- `k3d`
- `kubectl`
- `helm`

You can either install these tools on your setup, or install a VM and install them in there.

## VM Setup

We will use Ubuntu Focal to perform the workshop. In order to be able to have consistent
environments across all participants, we will use virtual machines.

To get started, download and install any virtualization software that you desire. A very common one
is [VirtualBox][0]. You can find many guides online on how to install it.

Then, download the Ubuntu Focal 20.04 TLS image from the [official website][1]. Perform an
installation of the virtual machine. Note that the install can be "minimal", no need to install
Office Tools, etc.

> Please do not make the VM too small. A decent amount of software will run inside it. I recommend
> at least 2 vCPUs and 8GiB of RAM minimum. Moreover, please provide the VM with 30GiB+ of storage.
> We will be running a lot of software within this VM, so we need the resources for it.

[0]: https://www.virtualbox.org/
[1]: https://ubuntu.com/download/desktop

> Since nearly everything we will run will be inside docker, you can also install the tools locally
> on another Linux distribution you might be using. If you decide to do this, please make sure that
> you install quite recent versions of the tools described below.

### Install Required Software

Once the VM is installed and running, please update the software on the VM:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install git -y
```

Then perform the following steps to install the required software.

#### Docker

> Docker is the runtime engine that will both build and run our software.

Install `docker`:

```bash
sudo addgroup --system docker
sudo adduser $USER docker
newgrp docker
sudo snap install docker
```

And test the installation:

```bash
docker run archlinux echo "Get stoked for Climb and Code!!!"
```

This should download an image and print `Get stoked for Climb and Code!!!`.

#### Kubectl

> Kubectl is the client application that we will use to interact with Kubernetes.

Install `kubectl`:

```bash
sudo snap install kubectl --classic
```

#### Helm

> Helm is similar to a package manager to install more complex configurations on Kubernetes.

Install `helm`:

```bash
sudo snap install helm --classic
```

#### K3D

> K3d is the software we will use to run a local Kubernetes cluster inside our VMs. This is to
> "fake" a cluster with several nodes on our systems.

Install `k3d`:

```bash
sudo apt install curl
curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
```

And test the installation by creating a demo cluster:

```bash
k3d cluster create demo -i rancher/k3s:v1.21.7-k3s1
```

Try to access this via `kubectl`:

```bash
kubectl get nodes
```

which should return a single node such as:

```
ubuntu@ipt-demo:~$ kubectl get nodes
NAME                STATUS   ROLES                  AGE   VERSION
k3d-demo-server-0   Ready    control-plane,master   18s   v1.20.7+k3s1
```

Check that `helm` finds some releases that are installed by default in our cluster setup.

```
ubuntu@ipt-demo:~$ helm list -A
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
traefik         kube-system     1               2021-06-06 15:46:19.258668874 +0000 UTC deployed        traefik-9.18.2          2.4.8
traefik-crd     kube-system     1               2021-06-06 15:46:18.759570934 +0000 UTC deployed        traefik-crd-9.18.2
```

Finally, also check whether the ingress load-balancers work properly:

```bash
kubectl get pods -A -l app=svclb-traefik
```

See below a sample output when it is failing, with a crash loop.

```
NAMESPACE     NAME                  READY   STATUS             RESTARTS   AGE
kube-system   svclb-traefik-5gzbj   0/2     CrashLoopBackOff   8          100s
```

If it fails, try to run:

```bash
sudo modprobe ip_tables
```

And either delete the failed pods to redeploy them, or delete the entire cluster (see below) and
redeploy it. It should then work.

If everything works, delete the cluster, as we will create a new cluster during the workshop:

```bash
k3d cluster stop demo
k3d cluster delete demo
```

You are now ready for the workshop!!
