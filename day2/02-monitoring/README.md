# Monitoring and Operators

> This is quite a heavy scenario. Make sure you give your VM enough CPU and RAM to make this work.
> Ideally I would suggest at least 16GiB of RAM and 4 vCPUs.

> This scenario is less about Kubernetes, and much more on monitoring Kubernetes with Prometheus,
> Grafana, and Alert Manager. If you know all these technologies, this scenario might be boring for
> you, other than seeing how easy it is to set up a monitoring stack on Kubernetes, and learning a
> bit about Custom Resource Definitions, and Kubernetes API extensions.

> Challenges can be found under [`challenges.md`][challenges]. Make sure you have completed the
> setup explained here before proceeding.

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
  * [Prometheus Adapter](#prometheus-adapter)
  * [Blackbox Exporter](#blackbox-exporter)
  * [`kube-state-metrics`](#`kube-state-metrics`)
  * [Prometheus Operator](#prometheus-operator)
  * [Prometheus Instances](#prometheus-instances)
  * [Alert Manager](#alert-manager)
  * [Grafana](#grafana)
  * [Node Exporters](#node-exporters)
* [Explore Prometheus](#explore-prometheus)
* [Explore Grafana](#explore-grafana)
  * [Import a Dashboard](#import-a-dashboard)
  * [Explore Metrics](#explore-metrics)
* [Explore Alert Manager](#explore-alert-manager)
* [API Extensions](#api-extensions)
  * [Custom Resource Definitions](#custom-resource-definitions)
  * [Custom Resources](#custom-resources)
  * [Operators](#operators)
* [Challenges](#challenges)

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

Let us first expose the Prometheus outside the cluster for easier access:

```bash
kubectl apply -f assets/prom-ingress.yaml
```

Then navigate to `http://prom.localhost:9080/` in any browser. If this fails, then close your
browser, execute the following and try again:

```bash
sudo echo -e "127.0.0.1\tprom.localhost" > /etc/hosts
```

Then click on Status > Targets and you should see a list of targets that the Prometheus is scraping.
All targets should be `UP`. If not, wait a little and refresh the page.

Finally try to check if you can query some metrics by clicking on "Graph" and entering the following
query:

```
kube_deployment_status_replicas_ready{namespace="kube-system"}
```

This should show that all deployments in the `kube-system` namespace have a single replica ready.
You can check that this is consistent with the state of your cluster:

```
$ kubectl -n kube-system get deployments
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
coredns                  1/1     1            1           10d
metrics-server           1/1     1            1           10d
local-path-provisioner   1/1     1            1           10d
traefik                  1/1     1            1           10d
```

Feel free to explore a little more if you don't know Prometheus yet!

## Explore Grafana

Expose Grafana outside your cluster:

```bash
kubectl apply -f assets/grafana-ingress.yaml
```

Then navigate to `http://grafana.localhost:9080/` in any browser. If this fails, then close your
browser, execute the following and try again:

```bash
sudo echo -e "127.0.0.1\tgrafana.localhost" > /etc/hosts
```

You should land on a login page. You can login with `admin` and `admin` as the username and
password. It will prompt you to provide a new password; you can continue with `admin` if you want.

### Import a Dashboard

We will import a very basic Kubernetes dashboard so you can see the capabilities of Grafana. Hover
over the third icon on the left side and click on "Manage". From there click on "Import" and enter
315 in the first text field asking for a URL or an ID. Then click on "Load". This might take a short
time, don't stress. Once a new page appears, enter `prometheus` as the default data source in the
last drop-down menu. Then press "Import".

You should land on a dashboard that provides basic overview of the cluster resources. Note that the
hardware metrics (CPU and Memory) probably strongly differ from your expectation. This is simply
because of the very high level of virtualization of our setup.

You can repeat the process for dashboard ID `13838` to get another dashboard with more information
about Kubernetes itself.

### Explore Metrics

Then go on the "Explore" tab (fourth on the left side) and enter `prometheus` as the data source at
the very top of the screen.

Now you can graph your cluster resources. For instances, enter the following query into the metrics
field:

```
rate(container_cpu_usage_seconds_total{namespace="monitoring", container="alertmanager"}[3m])
```

A nice graph should appear to show you the change rage (over 3 minutes) of the CPU usage of all
`alertmanager` containers running the `monitoring` namespace!

Feel free to explore some more.

## Explore Alert Manager

Expose the Alert Manager outside the cluster:

```bash
kubectl apply -f assets/alert-ingress.yaml
```

Then navigate to `http://alert.localhost:9080/` in any browser. If this fails, then close your
browser, execute the following and try again:

```bash
sudo echo -e "127.0.0.1\talert.localhost" > /etc/hosts
```

You might (and in all likelihood will) see a couple alerts already triggered. This is due to our
setup being "non-conventional" and therefore already the base alerts from Alert Manager are
triggered.

There is little to explore in Alert Manager other than the alerts that are triggered. We will create
our own alerts soon, which should then appear there.

If you want, feel free to explore.

## API Extensions

The main point of this scenario is to get you familiar with Kubernetes API extensions by the means
of monitoring. API extensions are composed of three major elements:

- Custom Resource Definitions,
- Custom Resources,
- Operators.

### Custom Resource Definitions

Custom Resource Definitions (or CRDs) allow to define how a Kubernetes API extension is going to
look like. We will not look at how to define them as it is out of scope for this scenario, but they
essentially define the structure of your YAML files for the Custom Resources. For instance,
somewhere in the Kubernetes API, there is a configuration that defines what are legal fields in the
Deployment YAML configuration. Custom Resource Definitions do the same, but for user-defined
resources.

To see what API extensions (CRDs) are installed on your cluster:

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

Now we could for instance look at the `prometheuses.monitoring.coreos.com` resources in the cluster:

```
$ kubectl -n monitoring get prometheuses
NAME   VERSION   REPLICAS   AGE
k8s    2.29.1    2          3h6m
```

This shows the `k8s` Prometheus definition that is used to configure the deployment of the
Prometheus we just accessed.

### Custom Resources

Custom Resources are instances of CRDs. In other words, they are a user-defined resource that has
the structure defined within a CRD. The `k8s` Prometheus instance is an example of it. You can get
its YAML configuration if you are interested in it, and see what is configured in this case:

```
$ kubectl -n monitoring get prometheus k8s -o yaml
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  creationTimestamp: "2021-08-29T15:05:00Z"
  generation: 1
  labels:
    app.kubernetes.io/component: prometheus
    ...
```

Note the `apiVersion` which is a custom version defined by the provider of the Prometheus CRD, and
the `kind` which defines what resource kind this resource defines. In this case it is a `Prometheus`
configuration. Note that the `monitoring.coreos.com` provider defines much more than just the
`Prometheus` resource kind (`PrometheusRules`, etc).

### Operators

While defining CRDs and Custom Resources is all well and nice, the Kubernetes API yet only knows
their structure, not what to do with them. This is where operators come into play. Operators are
software components that register to the Kubernetes API and tell it that they can handle the
`Prometheus` resource for instance. The Kubernetes API server will then notify the operator whenever
something happens with a `Prometheus` resource. The operator can then take actions with whatever
logic it desires. Typically operators connect back to the Kubernetes API to perform their
operations. For instance in the `Prometheus` case, the operator will create Deployments, ConfigMaps,
Secrets, Services, etc according to the definition with in the `Prometheus` custom resource.

However, operators are free to do whatever other action if they desire. In theory an operator could
provision the `Prometheus` on a completely different cluster, or even on VMs in AWS by connecting to
that API if it wanted. That is the beauty of the operators: they are free to implement any logic
that is desired. That makes them extremely powerful, and a heavily used feature of Kubernetes in
production environments.

## Challenges

Now turn to [`challenges.md`][challenges] to get some challenges on how to monitor your Kubernetes
cluster and learn how to perform PromQL queries to check the state of the cluster, as well as
defining proper alerts.

[challenges]: ./challenges.md
