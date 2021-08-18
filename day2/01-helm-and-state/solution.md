# Solution

* [Creating the Namespace](#creating-the-namespace)
  * [Tips](#tips)
  * [Solution](#solution)
* [Installing Redis](#installing-redis)
  * [Tips](#tips)
  * [Solution](#solution)
* [Play with Redis](#play-with-redis)
  * [Tips](#tips)
  * [Solution](#solution)
* [Change Code](#change-code)
  * [Tips](#tips)
  * [Solution](#solution)
* [Build with Docker](#build-with-docker)
  * [Tips](#tips)
  * [Solution](#solution)
* [Push with Docker](#push-with-docker)
  * [Tips](#tips)
  * [Solution](#solution)
* [Deploy to Kubernetes](#deploy-to-kubernetes)
  * [Tips](#tips)
  * [Solution](#solution)
* [Expose Outside the Cluster](#expose-outside-the-cluster)
  * [Tips](#tips)
  * [Solution](#solution)
* [Scale the Application](#scale-the-application)
  * [Tips](#tips)
  * [Solution](#solution)
* [Configure Liveness and Readiness Probes](#configure-liveness-and-readiness-probes)
  * [Tips](#tips)
  * [Solution](#solution)

## Creating the Namespace

### Tips

<details>
  <summary>Tip</summary>

In order to create namespaces, you can use `kubectl create`. View `kubectl create -h` for more help.

</details>

### Solution

<details>
  <summary>Solution</summary>

In order to create the namespace, execute:

```bash
kubectl create namespace helm-and-state
```

</details>

## Installing Redis

### Tips

<details>
  <summary>Tip</summary>

Search for Redis Helm Charts. You should find several, such as:

- https://bitnami.com/stack/redis/helm
- https://bitnami.com/stack/redis-cluster/helm

> Make sure you install the helm chart in the correct namespace! If you follow the documentation
> found on the webpages, it might install it in another namespace than `helm-and-state`.

</details>

### Solution

<details>
  <summary>Solution Cluster</summary>


We will install a Redis Sharded cluster. For this we use the Helm chart provided by Bitnami:
https://bitnami.com/stack/redis-cluster/helm

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install -n helm-and-state jbe-redis bitnami/redis-cluster
```

This installs the Redis Chart with default configuration (3 shards and a single replica per master)
in the `helm-and-state` namespace.

You can inspect these via the dashboard again, or by running:

```
$ kubectl get pods -n helm-and-state
NAME                        READY   STATUS    RESTARTS   AGE
jbe-redis-redis-cluster-3   1/1     Running   0          5m39s
jbe-redis-redis-cluster-1   1/1     Running   0          5m39s
jbe-redis-redis-cluster-0   1/1     Running   0          5m39s
jbe-redis-redis-cluster-4   1/1     Running   0          5m39s
jbe-redis-redis-cluster-5   1/1     Running   0          5m39s
jbe-redis-redis-cluster-2   1/1     Running   0          5m39s
```

This also deployed services:

```
$ kubectl get service -n helm-and-state
NAME                               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)              AGE
jbe-redis-redis-cluster-headless   ClusterIP   None            <none>        6379/TCP,16379/TCP   6m25s
jbe-redis-redis-cluster            ClusterIP   10.43.156.155   <none>        6379/TCP             6m25s
```

We will not use the `jbe-redis-redis-cluster` service to talk to our Redis. This is because we need
to provide all instance addresses to the Redis client. If we had deployed a single Redis instance
deployed via a Kubernetes deployment, we would use the service instead.

> See the exposed port (6379) in the service listing output.

</details>

<details>
  <summary>Solution Single</summary>

We will install a Redis single instance (non-sharded master-slave setup). For this we use the Helm
chart provided by Bitnami: https://bitnami.com/stack/redis/helm

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install -n helm-and-state jbe-redis bitnami/redis
```

This installs the Redis Chart with default configuration (one master, 3 replicas) in the
`helm-and-state` namespace.

You can inspect these via the dashboard again, or by running:

```
$ kubectl get pods -n helm-and-state
NAME                   READY   STATUS    RESTARTS   AGE
jbe-redis-replicas-0   1/1     Running   0          97s
jbe-redis-master-0     1/1     Running   0          97s
jbe-redis-replicas-1   1/1     Running   0          65s
jbe-redis-replicas-2   1/1     Running   0          33s
```

This also deployed services:

```
$ kubectl get service -n helm-and-state
NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
jbe-redis-headless   ClusterIP   None            <none>        6379/TCP   2m28s
jbe-redis-replicas   ClusterIP   10.43.138.227   <none>        6379/TCP   2m28s
jbe-redis-master     ClusterIP   10.43.125.131   <none>        6379/TCP   2m28s
```

We will use the `jbe-redis-master` service to talk to our Redis. This will automatically forward
traffic to the master. Note that in this case we could also use the pod name, as the master was
deployed with a StatefulSet, but if this were a Deployment, which would also make more sense, the
pod name would contain a randomized section. Therefore the Service is a safer bet.

> See the exposed port (6379) in the service listing output.

</details>

## Play with Redis

### Tips

<details>
  <summary>Tip</summary>

Try opening a shell on a pod that is running Redis, and then executing `redis-cli -c` to connect to
Redis. Once you have this open session, play and have fun.

`redis-cli` doc: https://redis.io/topics/rediscli

</details>

### Solution

<details>
  <summary>Solution</summary>

You can for instance log into a pod and execute the `redis-cli` to try writing and reading data from
the cluster. We will use it as a Key/Value store only, but feel free to try as much as you want.

Doc: https://redis.io/documentation

For instance:

```
$ kubectl -n helm-and-state exec -it jbe-redis-redis-cluster-5 -- bash
I have no name!@jbe-redis-redis-cluster-5:/$ redis-cli -c
127.0.0.1:6379> set foo 100
-> Redirected to slot [12182] located at 10.42.2.9:6379
OK
10.42.2.9:6379> append foo xxx
(integer) 6
10.42.2.9:6379> get foo
"100xxx"
10.42.2.9:6379> 3 incr bar
-> Redirected to slot [5061] located at 10.42.1.8:6379
(integer) 1
(integer) 2
(integer) 3
```

I use the `redis-cli` flag `-c` to automatically redirect me to shards that are storing the data I
am accessing. If you do not use it, you will get an error and need to manually connect to the
correct shard. You can see in the Redis output when such redirects happen.

> The `-c` flag is not necessary when using a non-sharded setup. However, in such a case make sure
> you connect to the master.

</details>

## Change Code

### Tips

<details>
  <summary>Tip</summary>

Check the following documentation: https://redis.uptrace.dev/#connecting-to-redis-server

If you are using a Redis cluster, check the following documentation:
https://redis.uptrace.dev/cluster/#redis-cluster

In any case, you just need to use the appropriate client (both are already in the code) and modify
the connection string(s).

</details>

### Solution

<details>
  <summary>Solution Cluster</summary>

This is only meant to make you familiar with the application's behaviour. We could have just as well
made the addresses configurable. Here you only need to change the address with which you will reach
Redis. In reality, you would not hardcode this but provide such addresses via a configuration file
or environment variables.

Note that you will need to chose which client to use based on what helm chart you installed (single
instance or cluster).

In my case, I used a cluster and the pod names were:

```
$ kubectl get pods -n helm-and-state
NAME                        READY   STATUS    RESTARTS   AGE
jbe-redis-redis-cluster-3   1/1     Running   0          5m39s
jbe-redis-redis-cluster-1   1/1     Running   0          5m39s
jbe-redis-redis-cluster-0   1/1     Running   0          5m39s
jbe-redis-redis-cluster-4   1/1     Running   0          5m39s
jbe-redis-redis-cluster-5   1/1     Running   0          5m39s
jbe-redis-redis-cluster-2   1/1     Running   0          5m39s
```

These pods expose the port 6379 for Redis communication. This can be verified running:

```bash
kubectl -n helm-and-state get pod jbe-redis-redis-cluster-1 -o yaml
```

To get the YAML definition of a pod. In this configuration you should find something such as:

```yaml
...
    ports:
    - containerPort: 6379
      name: tcp-redis
      protocol: TCP
    - containerPort: 16379
      name: tcp-redis-bus
      protocol: TCP
...
```

The first port is the Redis port the container exposes in the Pod. It is the one we want. Therefore
my Redis addresses are:

- `jbe-redis-redis-cluster-0:6379`
- `jbe-redis-redis-cluster-1:6379`
- `jbe-redis-redis-cluster-2:6379`
- `jbe-redis-redis-cluster-3:6379`
- `jbe-redis-redis-cluster-4:6379`
- `jbe-redis-redis-cluster-5:6379`

I put those in the code as follows:

```go
rdb := redis.NewClusterClient(&redis.ClusterOptions{
    Addrs: []string{
        "jbe-redis-redis-cluster-0:6379",
        "jbe-redis-redis-cluster-1:6379",
        "jbe-redis-redis-cluster-2:6379",
        "jbe-redis-redis-cluster-3:6379",
        "jbe-redis-redis-cluster-4:6379",
        "jbe-redis-redis-cluster-5:6379",
    },
})
```

</details>

<details>
  <summary>Solution Single</summary>

Remember the Service `jbe-redis-master` which exposed port `6379`. We can therefore simply use the
address `jbe-redis-master:6379`:

```go
rdb := redis.NewClient(&redis.Options{
    Addr:     "jbe-redis-master:6379",
    Password: "",
    DB:       0,
})
```

And I commented out the block creating a client for a Redis cluster (lines 23-34).

</details>


## Build with Docker

### Tips

<details>
  <summary>Tip</summary>

Check `docker build -h` for help. You should only need the `-t` flag.

</details>

### Solution

<details>
  <summary>Solution</summary>

You can build your image by executing the following command in `day2/01-helm-and-state`:

```bash
docker build -t k3d-registry-pipeline-cluster.localhost.localhost:5000/helm-and-state:0.1.0 .
```

</details>

## Push with Docker

### Tips

<details>
  <summary>Tip</summary>

Use `docker push`.

</details>

### Solution

<details>
  <summary>Solution</summary>

You can push your image by executing the following command:

```bash
docker push k3d-registry-pipeline-cluster.localhost.localhost:5000/helm-and-state:0.1.0
```

</details>

## Deploy to Kubernetes

### Tips

<details>
  <summary>Tip 1</summary>

We want to use a Deployment because all our servers can be treated exactly the same.

Checkout the documentation: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/

</details>

<details>
  <summary>Tip 2</summary>

Use the following template and adapt the points listed below:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-http-api
  namespace: helm-and-state
  labels:
    app: redis-http-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis-http-api
  template:
    metadata:
      labels:
        app: redis-http-api
    spec:
      containers:
      - name: server
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

We need to adapt:

- the image to use (the one we just built).
- the container port to expose (check the code again if you don't remember which one the server
  binds to).

Then use `kubectl apply` with the `-f` flag to deploy it.

> Or check the help first: `kubectl apply -h`

</details>

### Solution

<details>
  <summary>Solution</summary>

</details>

## Expose Outside the Cluster

### Tips

<details>
  <summary>Tip</summary>

</details>

### Solution

<details>
  <summary>Solution</summary>

</details>

## Scale the Application

### Tips

<details>
  <summary>Tip</summary>

</details>

### Solution

<details>
  <summary>Solution</summary>

</details>

## Configure Liveness and Readiness Probes

### Tips

<details>
  <summary>Tip</summary>

</details>

### Solution

<details>
  <summary>Solution</summary>

</details>
