# Challenges

* [Setup](#setup)
* [Challenges](#challenges)
  * [1. Dashboard Redis Setup](#1.-dashboard-redis-setup)
  * [2. Change Redis Scraping Interval](#2.-change-redis-scraping-interval)
  * [3. Modify the Alerting For the Our Prometheus](#3.-modify-the-alerting-for-the-our-prometheus)
  * [4. Define a Simple Alert for Redis](#4.-define-a-simple-alert-for-redis)
  * [5. Setup a Dashboard for MongoDB](#5.-setup-a-dashboard-for-mongodb)
  * [6. Manually Retrieve Metrics for MongoDB](#6.-manually-retrieve-metrics-for-mongodb)
  * [7. Define a ServiceMonitor for MongoDB](#7.-define-a-servicemonitor-for-mongodb)
  * [8. Define an Alert for MongoDB](#8.-define-an-alert-for-mongodb)

## Setup

We will start by installing a service which exposes metrics:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install -n monitoring redis-service bitnami/redis-cluster \
  --set "metrics.enabled=true" \
  --set "metrics.serviceMonitor.enabled=true"
helm install -n monitoring mongo-service bitnami/mongodb \
  --set "metrics.enabled=true"
```

## Challenges

### 1. Dashboard Redis Setup

Install a basic dashboard for Redis from the following URL onto your Grafana:

https://grafana.com/grafana/dashboards/14615

<details>
  <summary>Solution</summary>

Click onto Dashboards > Manage. Then click "Import", enter the ID `14615` and "Load". Once you reach
the next screen, enter `prometheus` as the data source and click "Import".

</details>

### 2. Change Redis Scraping Interval

The Redis metrics are scraped via a ServiceMonitor. This is a custom Kubernetes resource used by the
Prometheus operator to dynamically configure Prometheuses. Update the ServiceMonitor from the Redis
cluster to scrape every 10 seconds.

For a conceptual understanding, read up here: https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/user-guides/getting-started.md

<details>
  <summary>Tip</summary>

Have a look at the [Custom Resource Definition that defines the ServiceMonitor][sm-crd].

[sm-crd]: https://github.com/prometheus-operator/prometheus-operator/blob/master/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml

Look for `interval`.

</details>

<details>
  <summary>Solution</summary>

We need to adapt the interval on the endpoint that is defined in the ServiceMonitor.

Find the ServiceMonitor with:

```
$ kubectl -n monitoring get servicemonitors
NAME                          AGE
alertmanager                  3d5h
blackbox-exporter             3d5h
grafana                       3d5h
kube-state-metrics            3d5h
kube-apiserver                3d5h
coredns                       3d5h
kube-controller-manager       3d5h
kube-scheduler                3d5h
kubelet                       3d5h
node-exporter                 3d5h
prometheus-adapter            3d5h
prometheus-operator           3d5h
prometheus-k8s                3d5h
redis-service-redis-cluster   20m
```

You can probably guess that the one we want to change is the `redis-service-redis-cluster` one.

Obtain the YAML of it:

```bash
kubectl -n monitoring get servicemonitor redis-service-redis-cluster -o yaml > /tmp/sm.yaml
```

Then add the line in the `endpoints` section:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  annotations:
    meta.helm.sh/release-name: redis-service
    meta.helm.sh/release-namespace: monitoring
  labels:
    app.kubernetes.io/instance: redis-service
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis-cluster
    helm.sh/chart: redis-cluster-6.3.6
  name: redis-service-redis-cluster
  namespace: monitoring
spec:
  endpoints:
  - port: metrics
    # add the following line
    interval: 10s
  namespaceSelector:
    matchNames:
    - monitoring
  selector:
    matchLabels:
      app.kubernetes.io/component: metrics
      app.kubernetes.io/instance: redis-service
      app.kubernetes.io/name: redis-cluster
```

And apply again:

```bash
kubectl apply -f /tmp/sm.yaml
```

</details>

### 3. Modify the Alerting For the Our Prometheus

Our Prometheus (`prometheus-k8s`), has some alerts defined for it. These alerts are meant to provide
early warning when something is wrong with the Prometheus. With the Prometheus Operator, these alert
rules can be defined directly via the Kubernetes API, no need to change any configuration within the
Prometheus or Alert Manager!

Change the `PrometheusErrorSendingAlertsToAnyAlertmanager` alert to trigger after 10 minutes instead
of the currently configured 15.

<details>
  <summary>Tip</summary>

The Custom Resource type you are interested in is the `PrometheusRules`.

Check out its [Custom Resource Definition][pr-crd].

[pr-crd]: https://github.com/prometheus-operator/prometheus-operator/blob/master/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml

</details>

<details>
  <summary>Solution</summary>

Since the alerts are configurable via the Kubernetes API through extensions, we can list them to see
which one it is:

```
$ kubectl get crds
NAME                                        CREATED AT
addons.k3s.cattle.io                        2021-08-18T16:54:44Z
helmcharts.helm.cattle.io                   2021-08-18T16:54:44Z
helmchartconfigs.helm.cattle.io             2021-08-18T16:54:44Z
tlsoptions.traefik.containo.us              2021-08-18T16:55:29Z
middlewares.traefik.containo.us             2021-08-18T16:55:29Z
traefikservices.traefik.containo.us         2021-08-18T16:55:29Z
ingressroutes.traefik.containo.us           2021-08-18T16:55:29Z
ingressrouteudps.traefik.containo.us        2021-08-18T16:55:29Z
serverstransports.traefik.containo.us       2021-08-18T16:55:29Z
tlsstores.traefik.containo.us               2021-08-18T16:55:29Z
ingressroutetcps.traefik.containo.us        2021-08-18T16:55:29Z
alertmanagerconfigs.monitoring.coreos.com   2021-08-29T15:01:57Z
alertmanagers.monitoring.coreos.com         2021-08-29T15:01:57Z
podmonitors.monitoring.coreos.com           2021-08-29T15:01:57Z
probes.monitoring.coreos.com                2021-08-29T15:01:57Z
prometheuses.monitoring.coreos.com          2021-08-29T15:01:57Z
prometheusrules.monitoring.coreos.com       2021-08-29T15:01:57Z
servicemonitors.monitoring.coreos.com       2021-08-29T15:01:57Z
thanosrulers.monitoring.coreos.com          2021-08-29T15:01:57Z
```

It has to be one from `monitoring.coreos.com` since it is defined by the Prometheus operator. It is
not `prometheuses`, neither `servicemonitors` nor `podmonitors`. If you Google the others, or by
looking at sample resources on your cluster, you will find that we are interested in
`prometheusrules`.

```
$ kubectl -n monitoring get prometheusrules
NAME                              AGE
alertmanager-main-rules           3d5h
kube-prometheus-rules             3d5h
kube-state-metrics-rules          3d5h
kubernetes-monitoring-rules       3d5h
node-exporter-rules               3d5h
prometheus-operator-rules         3d5h
prometheus-k8s-prometheus-rules   3d5h
```

The rules we want is `prometheus-k8s-prometheus-rules`:

```bash
kubectl -n monitoring get prometheusrule prometheus-k8s-prometheus-rules -o yaml > /tmp/pr.yaml
```

In there you can search for the `PrometheusErrorSendingAlertsToAnyAlertmanager` alert. In its YAML
block, you will find a `for` key. That key defines how long the expression must evaluate to `true`
for, until the alert it triggered. Change its value to `10m` and apply the YAML to the cluster.

</details>

### 4. Define a Simple Alert for Redis

Define an alert that triggers when Redis is not up for more than 1 minute. Call the alert
`RedisDown`.

Test that the alert is working.

<details>
  <summary>Tip</summary>

Use a PrometheusRule resource and the `redis_up` metric.

</details>

<details>
  <summary>Solution</summary>

We will create a new PrometheusRule resource:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: redis-rules
  namespace: monitoring
spec:
  groups:
  - name: redis
    rules:
    ...
```

You can get the basic structure for the PrometheusRule either from looking at the CRD, or by simply
getting an existing one in the cluster and adapting it. I defined the group as `redis` since this
file will contain Redis alerts.

Now onto the alert. You can use Grafana to explore the Redis metrics, or Google what metrics the
`redis-exporter:1.26.0-debian-10-r5` image exposes. Either way, we are interested in the `redis_up`
metric. This metric returns `1` when the Redis instance is reachable, and `0` when it is not.

Therefore the expression we want to check is:

```promql
redis_up == 0
```

This makes our alert:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: redis-rules
  namespace: monitoring
spec:
  groups:
  - name: redis
    rules:
    - alert: RedisDown
      expr: redis_up == 0
      for: 1m
      annotations:
        description: Redis down ({{ $labels.instance }}).
        summary: The Redis instance {{ $labels.instance }} is down.
      labels:
        severity: critical
```

> Note that the annotations and labels are not required. I added them since it tends to be nice to
> have a little more information in an alert.

Apply this configuration with `kubectl apply -f`.

Onto testing. We will need to take down the Redis instance without taking down the metrics exporter
for it. Therefore we cannot just kill a pod. By opening a shell in a Redis pod, we can see that the
Redis server runs as PID 1:

```
I have no name!@redis-service-redis-cluster-0:/$ ps auxww
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
1001           1  0.1  0.0  58612  8192 ?        Ssl  17:25   0:02 redis-server 0.0.0.0:6379 [cluster]
1001        5227  0.0  0.0   3872  3104 pts/0    Ss   17:47   0:00 bash
1001        5251  0.0  0.0   7644  2680 pts/0    R+   17:48   0:00 ps auxww
```

This is likely to be stable, as it means it is the entrypoint for the container. You can try killing
it directly, in the shell (`kill 1`). Unfortunately, Kubernetes self-healing will bring the
container back up wayyyyy faster than in one minute. So we will need to create a loop that
continuously kills the process:

```
while true; do
  kubectl -n monitoring exec redis-service-redis-cluster-0 -c redis-service-redis-cluster -- kill 1
  sleep 1;
done
```

This will return errors as it often cannot connect to the container while it is restarting. But you
should see that the pod is no longer ready. You can see the effect in Grafana in the "Explore" tab,
checking for the `redis_up` metric. You should see that a value as dropped to 0.

Now go onto the Alert Manager URL (`http://alert.localhost:9080`). There you should see your alert
appearing after a minute has passed.

> Typically Alert Manager will be configured so that it send an Email or an SMS to responsible
> people when critical alerts are triggered. This is not the case here because it is not an "Alert
> Manager Tutorial". However, that would be the beauty of it.

Kill the loop with a `^C` (Control-C) signal. Now note that the pod might not start straight away:

```
$ kubectl -n monitoring get pods
...
redis-service-redis-cluster-0            1/2     CrashLoopBackOff   7          21h
...
```

This is because Kubernetes will (by default) back off from restarting containers that continuously
crash. The idea is not to waste resources on pods/containers that seem fully broken. It is important
that Kubernetes does this so that the API cannot be overloaded by deploying buggy images (would be
equivalent to a DoS attack).

After the pod has fully restarted (might take some time, depending on how long you were killing it
for), the alert in Alert Manager should disappear.

</details>

### 5. Setup a Dashboard for MongoDB

Install a basic dashboard for Redis from the following URL onto your Grafana:

https://grafana.com/grafana/dashboards/2583

The dashboard will be empty, why?

<details>
  <summary>Solution</summary>

Click onto Dashboards > Manage. Then click "Import", enter the ID `2583` and "Load". Once you reach
the next screen, enter `prometheus` as the data source and click "Import".

The reason the dashboard is empty is because we have not installed a ServiceMonitor for the deployed
MongoDB instance, so the metrics are not scraped by Prometheus and thus not available to Grafana.

</details>

### 6. Manually Retrieve Metrics for MongoDB

Try to get metrics for MongoDB without going via Prometheus, Grafana, or Alert Manager. Get them
directly from where-ever they are provided.

<details>
  <summary>Tip</summary>

MongoDB follows the standard _sidecar_ pattern. The sidecar pattern is when a pod contains several
containers, the main one performing the main work we desire, and several so called "sidecars" which
either support the main container in its work, or provide information about it. Investigate the
containers of the MongoDB pod, and go on from there.

</details>

<details>
  <summary>Solution</summary>

The MongoDB pod follows the sidecar pattern, with the metrics exporter running as a separate
container in the pod, providing metrics about the MongoDB instance running in the main container.
First find the MongoDB pod:

```
$ kubectl -n monitoring get pods
NAME                                     READY   STATUS    RESTARTS   AGE
...
mongo-service-mongodb-6495568667-zvj4q   2/2     Running   2          21h
...
```

With the pod name, you can describe it to find more information about it:

```
$ kubectl -n monitoring describe pod mongo-service-mongodb-6495568667-zvj4q
Name:         mongo-service-mongodb-6495568667-zvj4q
Namespace:    monitoring
...
Containers:
  mongodb:
    Image:          docker.io/bitnami/mongodb:4.4.8-debian-10-r24
    Image ID:       docker.io/bitnami/mongodb@sha256:57e4abfe050b0546ccdfeb37320d9f2017fea9108a8a310bc29850b0e5516f95
    ...
  metrics:
    Image:         docker.io/bitnami/mongodb-exporter:0.11.2-debian-10-r260
    Image ID:      docker.io/bitnami/mongodb-exporter@sha256:194066daf943bf03bd8ffa637e8c5250e7d0c41a4ce6015502fae4a2fd1e48ee
    Port:          9216/TCP
    ...
```

You can see there are two containers, one of which called metrics, which exposes the port 9216.
Interesting... Let us open a shell in said container and try to call that endpoint:

```
$ kubectl -n monitoring exec -it mongo-service-mongodb-6495568667-zvj4q -c metrics -- bash
I have no name!@mongo-service-mongodb-6495568667-zvj4q:/opt/bitnami/mongodb-exporter$ curl localhost:9216
<html>
<head>
        <title>MongoDB exporter</title>
</head>
<body>
        <h1>MongoDB exporter</h1>
        <p><a href="/metrics">Metrics</a></p>
</body>
</html>
```

Ok, we seem to have reached what we want, but got no metrics. Lets try the path returned in the
"Metrics" link (`/metrics`):

```
I have no name!@mongo-service-mongodb-6495568667-zvj4q:/opt/bitnami/mongodb-exporter$ curl localhost:9216/metrics
# HELP go_gc_duration_seconds A summary of the pause duration of garbage collection cycles.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 2.3638e-05
go_gc_duration_seconds{quantile="0.25"} 3.8077e-05
go_gc_duration_seconds{quantile="0.5"} 6.448e-05
go_gc_duration_seconds{quantile="0.75"} 0.000116003
go_gc_duration_seconds{quantile="1"} 0.000269253
go_gc_duration_seconds_sum 0.0015824
go_gc_duration_seconds_count 19
# HELP go_goroutines Number of goroutines that currently exist.
# TYPE go_goroutines gauge
...
```

Done, `#success`.

</details>

### 7. Define a ServiceMonitor for MongoDB

Create a ServiceMonitor to configure Prometheus to scrape the MongoDB service every 5s.

<details>
  <summary>Tip</summary>

Base yourself on other ServiceMonitors (for instance the one from Redis), and make sure you
configure the label selectors to match labels of the MongoDB service.

</details>

<details>
  <summary>Solution</summary>

We will base ourselves on the ServiceMonitor from Redis:

```bash
kubectl -n monitoring get servicemonitor redis-service-redis-cluster -o yaml > /tmp/sm.yaml
```

This gives:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: redis-service-redis-cluster
  namespace: monitoring
spec:
  endpoints:
  - interval: 10s
    port: metrics
  namespaceSelector:
    matchNames:
    - monitoring
  selector:
    matchLabels:
      app.kubernetes.io/component: metrics
      app.kubernetes.io/instance: redis-service
      app.kubernetes.io/name: redis-cluster
```

Now we need to make sure that the port provided in the endpoint is correct, adapt the scraping
interval, and update the label selector to use the service from MongoDB.

Let us check the service from MongoDB:

```
$ kubectl -n monitoring get service
NAME                                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
...
mongo-service-mongodb-metrics          ClusterIP   10.43.62.72     <none>        9216/TCP                     32h
mongo-service-mongodb                  ClusterIP   10.43.36.88     <none>        27017/TCP                    32h
...
```

You can see that there are two services, one of which has `metrics` in the name and exposes the port
we used in the last challenge to obtain the metrics. We will use this one. Unfortunately we have to
use the port name, and not number, in the ServiceMonitor. We can find this in the Service
definition.

Let us retrieve the labels of the service, and the name of the port:

```
$ kubectl -n monitoring get service mongo-service-mongodb-metrics -o yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    meta.helm.sh/release-name: mongo-service
    meta.helm.sh/release-namespace: monitoring
    prometheus.io/path: /metrics
    prometheus.io/port: "9216"
    prometheus.io/scrape: "true"
  creationTimestamp: "2021-09-01T20:29:44Z"
  labels:
    app.kubernetes.io/component: metrics
    app.kubernetes.io/instance: mongo-service
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: mongodb
    helm.sh/chart: mongodb-10.23.13
  name: mongo-service-mongodb-metrics
  namespace: monitoring
  resourceVersion: "68139"
  ...

  ...
    ports:
  - name: http-metrics
    port: 9216
    protocol: TCP
    targetPort: metrics

```

Lets use the following labels:

```yaml
app.kubernetes.io/component: metrics
app.kubernetes.io/instance: mongo-service
app.kubernetes.io/name: mongodb
```

As they are the most likely to uniquely determine the service. This makes our ServiceMonitor:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mongodb-monitor
  namespace: monitoring
spec:
  endpoints:
  - interval: 5s
    port: http-metrics
  namespaceSelector:
    matchNames:
    - monitoring
  selector:
    matchLabels:
      app.kubernetes.io/component: metrics
      app.kubernetes.io/instance: mongo-service
      app.kubernetes.io/name: mongodb
```

Apply the ServiceMonitor with `kubectl apply -f` and check that MongoDB appears as a scraping target
in Prometheus after some small time. After it has been listed as a target in Prometheus, you can
start exploring metrics in Grafana. You should also see data appear on the Dashboard you imported in
a previous challenge, since now the metrics are available.

</details>

### 8. Define an Alert for MongoDB

Create an alert to trigger immediately when the MongoDB service no longer serves metrics (the
exporter is not responsive). Typically people write alerts based on metric conditions, but forget to
write alerts for the scenario where there are no more metrics from a service at all.

<details>
  <summary>Tip 1</summary>

You should use metrics from Prometheus itself provides regarding targets. This is not strictly
necessary but it is more elegant.

</details>

<details>
  <summary>Tip 2</summary>

You will need to specify a PromQL filter to only consider the MongoDB metrics.

</details>

<details>
  <summary>Tip 3</summary>

You will need to use the `absent` function from PromQL to trigger when some metric is missing.

</details>

<details>
  <summary>Solution</summary>

While you could check for the presence of any metrics served by MongoDB, this is not very stable, as
exporters might choose to stop serving some metrics that either make no sense for the current state
of the cluster, or because they have no changed for some time (in case of rates). We will use the
builtin `up` metric from Prometheus, that provides information on whether scraping targets are
responding.

To filter it for the MongoDB service, we will use the following PromQL query:

```promql
absent(up{service="mongo-service-mongodb-metrics"})
```

> Note the use of the `absent` function to trigger only when the metric is not available.

Then we can create a PrometheusRule object just like in challenge 4, and set the `for:` to `0m` so
that it triggers directly:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mongodb-rules
  namespace: monitoring
spec:
  groups:
  - name: mongodb
    rules:
    - alert: MongoDBMetricsMissing
      expr: absent(up{service="mongo-service-mongodb-metrics"})
      for: 0m
      annotations:
        description: MongoDB metrics are missing ({{ $labels.pod }}).
        summary: The Redis metrics for pod {{ $labels.pod }} are not being served.
      labels:
        severity: critical
```

Once you have applied this PrometheusRule, you can test it by repeatedly killing the MongoDB
container, or simply scaling the Deployment down to 0.

The alert should trigger immediately in Alert Manager.

Then scale the Deployment back to 1 and watch the alert disappear.

> Note that either might not be fully immediate, since you only scrape metrics every 5 seconds.
> Therefore it might take up to 5 seconds to notice both the fact that the metrics are missing, and
> that they might have reappeared. It is important to keep these dependencies in mind when designing
> your alerts, as scraping intervals can have massive impacts on your response time in more extreme
> scenarios. Typical scraping times are between 10 and 30 seconds, but if you use Prometheus
> federation with a large number of metrics, you might not be able to scrape more often than every
> couple of minutes.

</details>
