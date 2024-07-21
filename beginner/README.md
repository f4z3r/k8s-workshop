# IPT Kubernetes Workshop - Beginner

<!--toc:start-->
- [IPT Kubernetes Workshop - Beginner](#ipt-kubernetes-workshop-beginner)
  - [Preparation](#preparation)
  - [Workshop Overview](#workshop-overview)
    - [Docker](#docker)
    - [Infrastructure](#infrastructure)
    - [Kubernetes](#kubernetes)
      - [Resilience](#resilience)
      - [Logging](#logging)
      - [Debugging](#debugging)
      - [Configuration](#configuration)
<!--toc:end-->

---

## Preparation

Please follow the instructions described in [`prep.md`][0] before the workshop in order to have the
environment up and running and be ready on the day of the workshop.

[0]: ../prep.md

## Workshop Overview

In case you have not already, please clone this repository to the VM:

```bash
git clone https://github.com/f4z3r/k8s-workshop.git
```

And initialize the git submodules to obtain our demo application:

```bash
cd k8s-workshop
git submodule update --init --checkout
cd beginner
```

### Docker

You should find a [Dockerfile][1] in the project root. This Dockerfile is used to build the Docker
image containing our demo application. It essentially describes the steps that are required to
obtain the image on which the containers that run the application will be based on.

Have a look at the [Dockerfile][1] and try to understand what it is doing. You can then build the
Docker image by running:

```bash
# in project root
docker build -t cc-demo:0.1.0 ./
```

This generates an image named `cc-demo` with tag (a way to version images) `0.1.0`. The directory
in which to find the Dockerfile should be `./`, as provided by the last argument to the command.

Once the image is built, you can run a container locally using:

```bash
docker run --rm -p 8080:8080 \
  --name cc-container \
  -e JDBC_URL=jdbc:oracle:thin:@myoracle.db.server:1521:my_sid \
  -e JDBC_USER=jakob \
  -e JDBC_PASSWORD=supersecret \
  cc-demo:0.1.0
```

This will launch a container based on the `cc-demo:0.1.0` image and bind the port `8080` from the
container to the host port `8080`. Therefore, any API exposed within the container on port `8080`
should be available via the browser on `localhost:8080`. As our demo application does indeed expose
an endpoint on said port, open your browser and see if you can get a response from the SpringBoot
application running inside the container (try to access `localhost:8080/customers/1` and check if
Hans Zimmer appears).

> The `--rm` flag is simply used to automatically delete the container once it is stopped. Otherwise
> the container would still be lying around on our machine once it exited.

We can now also execute commands inside the docker container with commands such as (you can run this
from within another terminal):

```bash
docker exec cc-container echo "Hello from within the docker container!"
```

To stop the container, simply press `Ctrl-c` in the terminal session where you launched it.

[1]: ./Dockerfile

### Infrastructure

First, validate that nothing is running on ports:

- 5000
- 6550
- 9080

with `ss -tlnp`.

Then, prepare the infrastructure by running:

```bash
k3d registry create erfa.localhost --port 5000
k3d cluster create erfa -a 3 -s 1 -i rancher/k3s:v1.21.7-k3s1 --api-port 0.0.0.0:6550 -p 9080:80@loadbalancer --registry-use k3d-erfa.localhost:5000
# wait for cluster to come online
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
kubectl apply -f ./manifests/dash/
```

Once this is done, launch a proxy using:

```bash
kubectl proxy > /dev/null &
```

This allows you to access a Kubernetes dashboard under:

```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/.
```

Once you are on this page, you will be required to log in. Select the "token" option and paste the
token returned from the following command into the text field:

```bash
bash ./token.sh
```

Play around with the dashboard and investigate the interesting information it can provide you. Note
that we have not yet deployed any application.

### Kubernetes

We will now deploy our application to see how easily a SpringBoot application can be run and how
resilient it is:

```bash
# build and push the docker image to a shared registry
docker build -t k3d-erfa.localhost:5000/sb-demo:0.1.0 -f ./erfa-dockerfile ./
docker push k3d-erfa.localhost:5000/sb-demo:0.1.0
# deploy everything into our cluster
kubectl create ns demo
kubectl apply -f ./manifests/app/
```

Once the command above has completed, the application will be deployed with three replicas on our
cluster. Networking is configured already so you can access the API via the following endpoint:

```
sb-demo.localhost:9080/customers/1
```

> If you get an issue here (something other than a default 404 page, and not the desired JSON), try
> adding the following line to your `/etc/hosts` file:
>
>     127.0.0.1   sb-demo.localhost

After everything is deployed, it should also be visible on the Kubernetes dashboard. Note that all
objects relating to our application are placed in the `demo` namespace within the cluster.

#### Resilience

Get all pods that run our application using:

```bash
kubectl -n demo get pods
```

This should result in something such as:

```
NAME                              READY   STATUS    RESTARTS   AGE
sb-demo-deploy-7d8b8f4fdd-2mjz9   1/1     Running   0          13s
sb-demo-deploy-7d8b8f4fdd-zlsnx   1/1     Running   0          13s
sb-demo-deploy-7d8b8f4fdd-llsmz   1/1     Running   0          13s
```

To showcase resilience, we will delete one of the pods to simulate a crash. In order to do this,
copy the name of one of the pods and enter the following command:

```bash
kubectl -n demo delete pod/sb-demo-deploy-7d8b8f4fdd-zlsnx
```

Due to how Kubernetes manages its resources, it will notice that there are less pods than desired
(whether it was deleted or actually crashed does not matter to Kubernetes), and it will create
another one instantly. To see this, run the `get pods` command again:

```
NAME                              READY   STATUS    RESTARTS   AGE
sb-demo-deploy-7d8b8f4fdd-2mjz9   1/1     Running   0          3m5s
sb-demo-deploy-7d8b8f4fdd-llsmz   1/1     Running   0          3m5s
sb-demo-deploy-7d8b8f4fdd-h6rh2   1/1     Running   0          4s
```

Note that during the (very short) downtime of the pod, the API was still fully available since
Kubernetes would have directed traffic only to the pods that are ready.

#### Logging

In order to read logs of one of the applications, use the following command on one of the pods:

```bash
kubectl -n demo logs pod/sb-demo-deploy-79b8db5d74-nm4cr
```

Optionally add the `-f` flag to follow logs.

#### Debugging

We can execute commands in our pods in order to perform some simple debugging. This is done as
follows:

```bash
kubectl -n demo exec pod/sb-demo-deploy-79b8db5d74-nm4cr -- cat /app/config/application.properties
```

> Note that this can only be used to execute programs that actually exist within the container. In
> this case `cat` is in the container and can therefore be executed. However, it happens very often
> that there are nearly no programs within the container other than the application being run, in
> which case such a `cat` would fail.

This can also be used to start an interactive shell:

```bash
kubectl -n demo exec -it pod/sb-demo-deploy-79b8db5d74-nm4cr -- bash
```

#### Configuration

Our deployment configures several things in that are external to the containers being run:

- A (dummy) configuration file mounted at `/app/config/application.properties`.
- A (dummy) JDBC connection URL stored in an environment variable `JDBC_URL`.
- A (dummy) JDBC user stored in an environment variable `JDBC_USER`.
- A (dummy) JDBC password stored in an environment variable `JDBC_PASSWORD`.

The JDBC information not stored here in the repository as it would provide a security risk to store
credentials in control version systems. However, you can view and edit the information about it
stored in Kubernetes:

```bash
kubectl -n demo get secret/sb-demo-db-creds -o yaml
```

> Note that the information from the secret is base64 encoded, so you would need to decode it before
> being able to read it.

The dummy configuration file is however being deployed as part of the setup before. It can be found
under [`./manifests/app/configmap.yaml`][configmap]. Note that this is a Kubernetes object, but it
only contains the configuration for a SpringBoot application. The contents are then mounted inside
the containers as we saw with the first command we executed within a pod.

Kubernetes manages these resources dynamically, therefore you can change any value inside the
[`./manifests/app/configmap.yaml`][configmap] and redeploy with:

```bash
kubectl apply -f ./manifests/app/
```

> Note that it might take some time before the changes can be observed. Kubernetes is not
> instantaneous when performing ConfigMap updates. For those interested: this is done on `kubelet`
> sync periods, which are typically every minute.

Once this is done, you will be able to observe the change inside the containers by running the
following again:

```bash
kubectl -n demo exec pod/sb-demo-deploy-79b8db5d74-nm4cr -- cat /app/config/application.properties
```

Note that the pods were not restarted to get the configuration updated!

[configmap]: ./manifests/app/configmap.yaml
