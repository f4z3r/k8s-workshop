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

We will use the `jbe-redis-redis-cluster-headless` service to talk to our Redis instances. The
reason is that we cannot access the pods directly, so we need to go over a service. However, the
normal service will load-balance across all our instances. What we actually want is to individually
talk to single instances. These can be reached using `<pod>.<headless-service>:<port>` from another
pod in the same namespace.

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
  <summary>Tip 1</summary>

Check the following documentation: https://redis.uptrace.dev/#connecting-to-redis-server

If you are using a Redis cluster, check the following documentation:
https://redis.uptrace.dev/cluster/#redis-cluster

In any case, you just need to use the appropriate client (both are already in the code) and modify
the connection string(s).

</details>

  <summary>Tip 2 (Secrets)</summary>

Check the following documentation: https://kubernetes.io/docs/concepts/configuration/secret/

Note that Kubernetes Secrets have their data base64 encoded. You can decode such data with the
following command:

```bash
echo -n "<data>" | base64 --decode
```

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

Remember how we need to address these pods via a headless service (see section above). Therefore the
addresses we use are the following:

- `jbe-redis-redis-cluster-0.jbe-redis-redis-cluster-headless:6379`
- `jbe-redis-redis-cluster-1.jbe-redis-redis-cluster-headless:6379`
- `jbe-redis-redis-cluster-2.jbe-redis-redis-cluster-headless:6379`
- `jbe-redis-redis-cluster-3.jbe-redis-redis-cluster-headless:6379`
- `jbe-redis-redis-cluster-4.jbe-redis-redis-cluster-headless:6379`
- `jbe-redis-redis-cluster-5.jbe-redis-redis-cluster-headless:6379`

Moreover, I need to find the password to connect to the cluster. This can be done by listing the
Secret Kubernetes resources in the namespace:

```
$ kubectl -n helm-and-state get secrets
NAME                              TYPE                                  DATA   AGE
default-token-n8h2g               kubernetes.io/service-account-token   3      17h
jbe-redis-redis-cluster           Opaque                                1      17h
sh.helm.release.v1.jbe-redis.v1   helm.sh/release.v1                    1      17h
```

The secret I am interested in is the `jbe-redis-redis-cluster` one. Now I will get the data from it:

```
$ kubectl -n helm-and-state get secret jbe-redis-redis-cluster -o yaml
apiVersion: v1
data:
  redis-password: SnU1TmxlV0EzMg==
kind: Secret
metadata:
  annotations:
    meta.helm.sh/release-name: jbe-redis
    meta.helm.sh/release-namespace: helm-and-state
  creationTimestamp: "2021-08-18T17:18:26Z"
  labels:
    app.kubernetes.io/instance: jbe-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis-cluster
    helm.sh/chart: redis-cluster-6.3.3
  name: jbe-redis-redis-cluster
  namespace: helm-and-state
  resourceVersion: "2694"
  uid: 5b2450dc-21a9-4952-b772-ae1a9f6ff4a6
type: Opaque
```

The data we are interested in is in `.data.redis-password`. Note that this is base64 encoded, so we
need to decode it:

```
$ echo -n "SnU1TmxlV0EzMg==" | base64 --decode
Ju5NleWA32
```

This is the secret I want.

I put those in the code as follows:

```go
rdb := redis.NewClusterClient(&redis.ClusterOptions{
    Addrs: []string{
        "jbe-redis-redis-cluster-0.jbe-redis-redis-cluster-headless:6379",
        "jbe-redis-redis-cluster-1.jbe-redis-redis-cluster-headless:6379",
        "jbe-redis-redis-cluster-2.jbe-redis-redis-cluster-headless:6379",
        "jbe-redis-redis-cluster-3.jbe-redis-redis-cluster-headless:6379",
        "jbe-redis-redis-cluster-4.jbe-redis-redis-cluster-headless:6379",
        "jbe-redis-redis-cluster-5.jbe-redis-redis-cluster-headless:6379",
    },
    Password: "Ju5NleWA32",
})
```

</details>

<details>
  <summary>Solution Single</summary>

Remember the Service `jbe-redis-master` which exposed port `6379`. We can therefore simply use the
address `jbe-redis-master:6379`.

Moreover, I need to find the password to connect to the instance. This can be done by listing the
Secret Kubernetes resources in the namespace:

```
$ kubectl -n helm-and-state get secrets
NAME                              TYPE                                  DATA   AGE
default-token-n8h2g               kubernetes.io/service-account-token   3      17h
jbe-redis-redis-cluster           Opaque                                1      17h
sh.helm.release.v1.jbe-redis.v1   helm.sh/release.v1                    1      17h
```

The secret I am interested in is the `jbe-redis-redis-cluster` one. Now I will get the data from it:

```
$ kubectl -n helm-and-state get secret jbe-redis-redis-cluster -o yaml
apiVersion: v1
data:
  redis-password: SnU1TmxlV0EzMg==
kind: Secret
metadata:
  annotations:
    meta.helm.sh/release-name: jbe-redis
    meta.helm.sh/release-namespace: helm-and-state
  creationTimestamp: "2021-08-18T17:18:26Z"
  labels:
    app.kubernetes.io/instance: jbe-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis-cluster
    helm.sh/chart: redis-cluster-6.3.3
  name: jbe-redis-redis-cluster
  namespace: helm-and-state
  resourceVersion: "2694"
  uid: 5b2450dc-21a9-4952-b772-ae1a9f6ff4a6
type: Opaque
```

The data we are interested in is in `.data.redis-password`. Note that this is base64 encoded, so we
need to decode it:

```
$ echo -n "SnU1TmxlV0EzMg==" | base64 --decode
Ju5NleWA32
```

This is the secret I want.

```go
rdb := redis.NewClient(&redis.Options{
    Addr:     "jbe-redis-master:6379",
    Password: "Ju5NleWA32",
    DB:       0,
})
```

And I commented out the block creating a client for a Redis cluster (lines 23-34).

Moreover, the handler for the readiness probe, I commented out the block from line 68 to 70, and
uncommented line 66.

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

Use the following deployment:

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
        image: k3d-registry-pipeline-cluster.localhost:5000/helm-and-state:0.1.0
        ports:
        - containerPort: 8080
```

Note that we use a single replica within the deployment for now. You could easily use more than one.
Moreover, we added the correct image that we pushed in the step before, and exposed the container
port 8080, as it is the port the server application binds to (you can verify this in the code).
Finally, note that we are deploying this to the same namespace in which we have our Redis cluster
(`helm-and-state`).

Once you have created this file (for instance under `/tmp/deploy.yaml`, you can apply it to your
cluster with `kubectl`.

```bash
kubectl apply -f /tmp/deploy.yaml
```

</details>

## Expose Outside the Cluster

### Tips

<details>
  <summary>Tip 1</summary>

You will need to resources to expose the application outside the cluster. A service and an ingress.

Service documentation: https://kubernetes.io/docs/concepts/services-networking/service/

Ingress documentation: https://kubernetes.io/docs/concepts/services-networking/ingress/

> Note that we do not use an NGINX ingress as is shown in the documentation. We use a Traefik
> ingress controller. This should not affect you, but any NGINX specific annotations within the
> ingress declarations will have no effect.

</details>

<details>
  <summary>Tip 2</summary>

When declaring your service, you will need to define where your traffic gets routed to. This is done
via label selectors. You will need to specify the labels that are on your pods. If you check my
solution from above, this is the `app: redis-http-api` label that I specified under
`.spec.template.metadata.labels` in the deployment.

</details>

<details>
  <summary>Tip 3</summary>

When declaring your ingress, you will need to specify to which service to route the traffic, and
which hostname to use as an access point. In theory you can leave the hostname out of the
configuration, which means all traffic will be routed to the service you specified. However, in a
realistic scenario you would have many ingresses exposing many applications, each under a different
hostname. The hostname we want to expose under is `helm-and-state.localhost`.

</details>


### Solution

<details>
  <summary>Solution</summary>

Let us first define the service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-http-api-svc
  namespace: helm-and-state
spec:
  selector:
    app: redis-http-api
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
```

We define in the label selector the labels that we declared in our deployment. Therefore the traffic
will be forwarded to any pod within the deployment. Moreover, we specified the container port to
which to route the traffic (`targetPort: 8080`) and which port the service should listen to (we also
used `8080` here for consistency).

We can now check if the service works:

```
# apply the service
$ kubectl apply -f /tmp/service.yaml     # assuming that is where we stored the definition
# check if the service works by exec-ing into a pod that contains curl (redis)
$ kubectl -n helm-and-state exec -it jbe-redis-redis-cluster-1 -- sh
$ curl redis-http-api-svc:8080/liveness
live!
$ curl redis-http-api-svc:8080/readiness
ready!
$ curl redis-http-api-svc:8080/hello
key 'hello' does not exist
$ curl -X PUT -d 'world' redis-http-api-svc:8080/hello
set hello to value world
$ curl redis-http-api-svc:8080/hello
hello=world
```

> Note that if here the `/liveness` or `/readiness` endpoints do not return HTTP code 200, it means
> you made a mistake somewhere in the coding part. If this is the case, go back, find your error,
> build, push, and try again. Note that you should do a version bump on the Docker image every time
> you make a change. You will therefore also need to change your deployment to use your new image!

Now the service is exposed inside the cluster for other applications. However we cannot access it
outside the cluster. For this we will need an ingress resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: http-redis-api-ingress
  namespace: helm-and-state
spec:
  rules:
    - host: helm-and-state.localhost
      http:
        paths:
          - path: /
        pathType: Prefix
        backend:
          service:
            name: redis-http-api-svc
            port:
              number: 8080
```

Note that I deployed the Ingress resource inside the same namespace as the Service resource, and
reference the service under `.spec.rules[].http.backend.service.name`. Moreover, I provided the host
to be `helm-and-state.localhost`. We provide no port here, as the port is dictated by where the
ingress controller is listening, over which we have no control (this is `9080` in our case, JBE set
this up when the cluster was created). Finally, I provide the port I want to connect to on the
Service. This is `8080` as we used `8080` as well in the Service definition (under
`.spec.ports[].port`).

Once you have applied this, you can simply open your browser in the VM and navigate to
`helm-and-state:9080/hello` and you should see the response of your app.

Nice, we have developed and deployed a fully functional cloud native application, installed its
infrastructure level dependencies and exposed it outside our cluster! Most companies need entire
teams to just to this! You rock! Congratulations!

</details>


## Scale the Application

### Tips

<details>
  <summary>Tip</summary>

Use either `kubectl scale -h` or change directly in your deployment file and reapply it to your
cluster.

</details>

### Solution

<details>
  <summary>Solution</summary>

We will use the `kubectl scale` command. You could also change the `replica` field inside your
deployment configuration and run `kubectl apply -f <file>` again.

```bash
kubectl -n helm-and-state scale deployment redis-http-api --replicas=3
```

Check that the replicas are indeed running:

```
$ kubectl -n helm-and-state get pods
NAME                              READY   STATUS    RESTARTS   AGE
jbe-redis-redis-cluster-3         1/1     Running   2          18h
jbe-redis-redis-cluster-5         1/1     Running   2          18h
jbe-redis-redis-cluster-0         1/1     Running   2          18h
jbe-redis-redis-cluster-2         1/1     Running   2          18h
jbe-redis-redis-cluster-4         1/1     Running   2          18h
jbe-redis-redis-cluster-1         1/1     Running   2          18h
redis-http-api-6bddc8f65f-98p5r   1/1     Running   0          16m
redis-http-api-6bddc8f65f-brl2m   1/1     Running   0          67s
redis-http-api-6bddc8f65f-bhq47   1/1     Running   0          67s
```

As we can see, we now have 3 replicas. The really cool thing is: if any of these crashes, we don't
care! Our service will still be available as Kubernetes will automatically route traffic to the
healthy ones, so "client" will never notice. Moreover, Kubernetes will restart any failed replica so
that we already try to have 3 healthy instances. You could also scale to even more replicas without
an issue (other than your VM might die if you scale to something too big).

Note however that this super easy scaling with high availability and performance scaling included
comes at a cost. We need to develop our application in the correct way. If you tried to do this with
a stateful application for instance, or with an application that takes ages to start and be ready to
serve request, none of this would work.

</details>

## Configure Liveness and Readiness Probes

### Tips

<details>
  <summary>Tip</summary>

Check the following page:
https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/

</details>

### Solution

<details>
  <summary>Solution</summary>

Add the following block to your deployment:

```yaml
livenessProbe:
  httpGet:
    path: /liveness
    port: 8080
  initialDelaySeconds: 1
  periodSeconds: 5
readinessProbe:
  httpGet:
    path: /readiness
    port: 8080
  initialDelaySeconds: 1
  periodSeconds: 3
```

> Note that the initial delay and period can be set to something else. I like to run readiness
> probes relatively often, as they determine whether traffic will be routed to a pod. If my pod is
> not ready to serve requests (for instance because it loses connection to Redis), I want to know
> this as quickly as possible and stop routing traffic to that pod. Hence why I run it more often
> than liveness. Liveness probes are meant to know if the server is running, even if it is not ready
> to serve requests. With this probe, Kubernetes checks every 5 seconds, if my server is responsive,
> and will kill it and start a new one if there is an issue. Note that it might stop sending it
> traffic before killing it because the readiness probe fails before the liveness probe fails.

Now I will get my deployment:

```bash
kubectl -n helm-and-state get deployment redis-http-api -o yaml > /tmp/deploy.yaml
```

There I change it to:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  [redacted]
spec:
  [redacted]
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: redis-http-api
    spec:
      containers:
      - image: k3d-registry-pipeline-cluster.localhost:5000/helm-and-state:0.1.0
        imagePullPolicy: IfNotPresent
        name: server
        livenessProbe:
          httpGet:
            path: /liveness
            port: 8080
          initialDelaySeconds: 1
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /readiness
            port: 8080
          initialDelaySeconds: 1
          periodSeconds: 3
        ports:
        - containerPort: 8080
          protocol: TCP
        [redacted]
status:
  [redacted]
```

And apply it to the cluster:

```bash
kubectl apply -f /tmp/deploy.yaml
```

This will restart your containers using a rolling-update to have the new probes configured.

If you want to try out and see them work, try killing your Redis cluster (you can for instance do
this by scaling it down). Once Redis becomes unavailable, our application's readiness probe should
fail and mark the pods as not ready. Therefore traffic will not be fowarded to them anymore.

In my case:

```
# scale down my Redis cluster
$ kubectl -n helm-and-state scale statefulset jbe-redis-redis-cluster --replicas=0
# wait a little then get pods
$ kubectl -n helm-and-state get pods | xsel -bi
NAME                              READY   STATUS    RESTARTS   AGE
redis-http-api-5f895499fb-gl5jj   0/1     Running   0          3m46s
redis-http-api-5f895499fb-2ckts   0/1     Running   0          3m43s
redis-http-api-5f895499fb-txprs   0/1     Running   0          3m47s
```

> Note that the way to need to scale down your cluster depends on whether you deployed a cluster or
> a single replicated instance. In the case of a single replicated instance you will need to scale
> down the master StatefulSet.

> See the `0/1` in the `READY` column of the pods.

Then try to reach the service via your browser. You should see a `Service Unavailable` problem. That
is because all our pods are not ready to serve requests. If this was only the case for a single one
(instead of all three), we could have gotten a response.

Now scale back up and see how your pods are ready again:

```
# scale up my Redis cluster
$ kubectl -n helm-and-state scale statefulset jbe-redis-redis-cluster --replicas=6
# wait a little then get pods
$ kubectl -n helm-and-state get pods | xsel -bi
NAME                              READY   STATUS    RESTARTS   AGE
jbe-redis-redis-cluster-0         1/1     Running   0          101s
jbe-redis-redis-cluster-1         1/1     Running   0          101s
jbe-redis-redis-cluster-4         1/1     Running   0          101s
jbe-redis-redis-cluster-3         1/1     Running   0          101s
jbe-redis-redis-cluster-5         1/1     Running   0          101s
jbe-redis-redis-cluster-2         1/1     Running   0          101s
redis-http-api-5f895499fb-2ckts   1/1     Running   0          6m21s
redis-http-api-5f895499fb-gl5jj   1/1     Running   0          6m24s
redis-http-api-5f895499fb-txprs   1/1     Running   0          6m25s
```

Everything is healthy again, and ready to serve requests.

</details>
