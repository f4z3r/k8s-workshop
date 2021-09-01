# Challenges

* [Setup](#setup)
* [Challenges](#challenges)
  * [1. Dashboard Redis Setup](#1.-dashboard-redis-setup)
  * [2. Change Redis Scraping Interval](#2.-change-redis-scraping-interval)
  * [3. Modify the Alerting For the Our Prometheus](#3.-modify-the-alerting-for-the-our-prometheus)
  * [4. Define an Alert for Redis](#4.-define-an-alert-for-redis)
  * [5. Setup a Dashboard for MongoDB](#5.-setup-a-dashboard-for-mongodb)
  * [6. Define a ServiceMonitor for MongoDB](#6.-define-a-servicemonitor-for-mongodb)
  * [7. Define an Alert for MongoDB](#7.-define-an-alert-for-mongodb)

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

### 4. Define an Alert for Redis

### 5. Setup a Dashboard for MongoDB

### 6. Define a ServiceMonitor for MongoDB

### 7. Define an Alert for MongoDB

https://grafana.com/grafana/dashboards/2583
