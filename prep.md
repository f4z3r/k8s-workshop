# Workshop Preparation

## VM Setup

We will use Ubuntu Focal to perform the workshop. In order to be able to have consistent
environments across all participants, we will use virtual machines.

To get started, download and install any virtualization software that you desire. A very common one
is [VirtualBox][0]. You can find many guides online on how to install it.

Then, download the Ubuntu Focal 20.04 TLS image from the [official website][1]. Perform an
installation of the virtual machine. Note that the install can be "minimal", no need to install
Office Tools, etc.

[0]: https://www.virtualbox.org/
[1]: https://ubuntu.com/download/desktop

### Install Required Software

Once the VM is installed and running, please update the software on the VM:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install lua5.3 -y
```

Then perform the following steps to install the required software.

#### Docker

Install `docker`:

```bash
sudo addgroup --system docker
sudo adduser $USER docker
newgrp docker
sudo snap install docker
```

And test the installation:

```bash
docker run archlinux echo "Welcome to the UCC workshop!!!"
```

This should download an image and print `Welcome to the UCC workshop!!!`.

#### Kubectl

Install `kubectl`:

```bash
sudo snap install kubectl --classic
```

#### K3D

Install `k3d`:

```bash
sudo apt install curl
curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
```

And test the installation by creating a `demo` cluster:

```bash
k3d cluster create demo
```

Try to access this via `kubectl`:

```bash
kubectl get nodes
```

which should return a single node such as:

```
ubuntu@ucc-demo:~$ kubectl get nodes
NAME                STATUS   ROLES                  AGE   VERSION
k3d-demo-server-0   Ready    control-plane,master   18s   v1.20.5+k3s1
```

Then delete the cluster:

```bash
k3d cluster stop demo
k3d cluster delete demo
```

You are now ready for the workshop!!
