# Monitoring and Operators

> This is quite a heavy scenario. Make sure you give your VM enough CPU and RAM to make this work.
> Ideally I would suggest at least 16GiB of RAM and 4 vCPUs.

> Solution and tips can be found under [`solution.md`][solution].

[solution]: ./solution.md

Cluster monitoring is a very important part of operating software on Kubernetes. Both applications
and the cluster itself should be monitored at all times, such that abnormal behaviour is detected
early and the relevant people are informed before services are disrupted. During this scenario we
will install cluster monitoring as well as monitor a few services. Moreover we will set up alerting
to ensure that we are informed when something goes wrong.

Moreover, we will combine this to get a little understanding of Kubernetes operators. Operators are
software components that allow to extend the Kubernetes API to handle custom resource types. This
can be extremely useful to handle more complex deployments.

Further reading:

- [Prometheus][prometheus]
- [Grafana][grafana]
- [Alert Manager][alert-manager]
- [Operators][operators]

[prometheus]: https://prometheus.io/docs/introduction/overview/
[grafana]: https://grafana.com/
[alert-manager]: https://www.prometheus.io/docs/alerting/latest/alertmanager/
[operators]: https://kubernetes.io/docs/concepts/extend-kubernetes/operator/

---

* [Overview](#overview)
* [Installing the Entire Setup](#installing-the-entire-setup)
* [Investigation](#investigation)

## Overview

We will:

- Install a setup to provide metrics for the cluster.
- Install Prometheus to gather data about the cluster (via an operators).
- Install Grafana to visualize our cluster state.
- Set up a sample service to be monitored by Prometheus.
- Set up alerting for the cluster and the service via Alert Manager.

Note that this tutorial will be slightly different in that it will be mostly guided on how to
install the components. At the end you will get a set of challenges to solve in Prometheus and
Grafana in order to make sure you understand how to monitor your cluster appropriately.

If you want to, feel free to try to get a full setup of the components without using this tutorial.
There should be decent online documentation on how it can be done.

## Installing the Entire Setup

We will install the Prometheus operator as part of `kube-prometheus`. This will setup:

- `kube-state-metrics`,
- Kubernetes node exporters,
- the operator,
- a Prometheus,
- Grafana,
- alerting,
- rules.

For now, don't worry if you do not know what all this means. For the installation, we will clone the
GitHub repository:

```bash
git clone https://github.com/prometheus-operator/kube-prometheus.git
```

Then install everything:

```bash
cd kube-prometheus
kubectl create -f manifests/setup
until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
kubectl create -f manifests/
```

Now wait a little. This will start a lot of containers in the `monitoring` namespace. Note that the
`node-exporter` pods will probably fail. If this is the case use the following command:

```bash
kubectl -n monitoring edit ds/node-exporter
```

and remove the lines containing `mountPropagation` in the `volumeMounts` section (there should be
two lines). After this save and close the file, which should update the DaemonSet and the pods
should come up.

## Investigation

Let us inspect what was installed:

```
$ kubectl -n monitoring get pods
NAME                                   READY   STATUS    RESTARTS   AGE
prometheus-adapter-5b8db7955f-jjrsm    1/1     Running   0          10m
blackbox-exporter-6798fb5bb4-mdsvv     3/3     Running   0          10m
kube-state-metrics-bdb774b4d-rb8fz     3/3     Running   0          10m
prometheus-operator-5685494db7-fj2r5   2/2     Running   0          10m
prometheus-k8s-1                       2/2     Running   0          9m9s
alertmanager-main-0                    2/2     Running   0          9m10s
alertmanager-main-2                    2/2     Running   0          9m10s
prometheus-k8s-0                       2/2     Running   0          9m9s
alertmanager-main-1                    2/2     Running   0          9m10s
prometheus-adapter-5b8db7955f-xzr2d    1/1     Running   0          10m
grafana-7b4c48d8b5-bvxt2               1/1     Running   0          10m
node-exporter-8jj79                    2/2     Running   0          3m46s
node-exporter-nkntq                    2/2     Running   0          3m46s
node-exporter-xmxnq                    2/2     Running   0          3m46s
node-exporter-jcjqf                    2/2     Running   0          3m35s
```

You can see several components:

- a Prometheus adapter (with 2 replicas),
- a blackbox exporter,
- `kube-state-metrics`,
- the Prometheus operator,
- a Prometheus instance (with 2 replicas),
- an Alert Manager instance (with 3 replicas),
- a Grafana instance,
- 4 node exporters.

### Prometheus Adapter

We will not go in depth for this component. Only know that it allows to get Kubernetes metrics
from the API directly. This is an experimental feature of Kubernetes. These two replicas will help
us scrape resources from the Kubernetes API to get information on the deployed pods, etc.

### Blackbox Exporter

The blackbox exporter performs Blackbox endpoint probing within the cluster. This allows to perform
HTTP, HTTPS, DNS, TCP, and IMCP probes to configured endpoints within and outside your cluster. This
can be very useful to detect network and connectivity issues, as well as security issues in the
network isolation. It then exposes these as metrics for the Prometheus to scrape.

### `kube-state-metrics`

This is a metrics exporter that checks the state of the cluster via the Kubernetes API and provides
the state via metrics to Prometheus. It is complementary to the Prometheus adapters. It is
present since the Kubernetes did not export metrics directly via the API until recently. This allows
to scape metrics also on older versions of the Kubernetes API.

### Prometheus Operator

This is an operator that allows to perform several actions:

- Easily deploy Prometheus instances within your cluster.
- Enable scraping configuration of endpoints directly via the Kubernetes API (see for instance
  [ServiceMonitors][service-monitors]).
- Define alerting rules to configure alerts directly over the Kubernetes API.

[service-monitors]: https://www.infracloud.io/blogs/monitoring-kubernetes-prometheus/

The operator is a software component that talks directly with Kubernetes and Prometheus instances to
configure the Prometheuses as defined by the Kubernetes API.

### Prometheus Instances

Prometheus is a software component that can scrape HTTP and HTTPS endpoints to gather metrics that
these endpoints provide. It can then aggregate the metrics and serve them via a query language
called PromQL.

### Alert Manager

Alert Manager can be connected to a Prometheus instance and alert based on a set of rules when
metrics do not conform to desired states.

### Grafana

Grafana can use metrics from Prometheus to allow visualizing data nicely. It provides exploratory
functions to graph simple PromQL metrics, but also provides full dashboards.

### Node Exporters

Node exporters gather information about Linux machines to export metrics on their current state. In
our case we have a 4 node cluster (1 master and 3 workers) and thus have 4 node exporters to get the
machine statistics of these nodes. Note that the metrics provided by these exporters will be quite
fake in our case, since all 4 nodes are fully virtualized and not proper (virtual) machines at all.

## Explore Prometheus

```bash
kubectl apply -f assets/prom-ingress.yaml
```

```
http://prom.localhost:9080/
```

## Explore Grafana

```bash
kubectl apply -f assets/grafana-ingress.yaml
```

```
http://grafana.localhost:9080/
```

## Explore Alert Manager

```bash
kubectl apply -f assets/alert-ingress.yaml
```

```
http://alert.localhost:9080/
```
