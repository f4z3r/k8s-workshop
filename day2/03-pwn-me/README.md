# Pwn Me

> This is a quite advanced multi-stage attack. Please make sure that you understand the following
> concepts before starting:
>
> - RBAC and ServiceAccounts.
> - The Kubernetes API and how to access it without kubectl.
> - Volume mounts.
> - Read up on static pods.


This scenario simulates what could happen if an application level security issue allowed RCE within
the container, and security best practices are not followed, or you simply get unlucky.

## Setup

> Ensure you have `jq` installed before setting up your cluster.

In order to setup the lab, perform the following:

```bash
# create the namespace in which our vulnerable app will be deployed in:
kubectl create ns pwn-me
# install the required information
helm install pwn-me deps/
# restrict your access to the cluster as you would have no access as an attacker
./handicap-me.sh
```

## The Flag

The goal of the attack is to pwn the cluster: i.e. you should get full admin rights, and do whatever
you want with the cluster.

## How to get started?

Well that is your job to figure out. You should assume that the RCE vulnerable app you get access to
is the container running within `vulnerable-app` in the `pwn-me` namespace.

Your setup should now be such that you are only allowed to perform the following call:

```bash
kubectl -n pwn-me exec -it vulnerable-app -- sh
```

And little else. Do not try to break the setup within your VM, as an attacker you would not have
access to this. Please perform all you actions within the container, simulating that you somehow got
access to the container via an application vulnerability.

Execute into the pod, and work from there.

## Cluster Reset

> This is in case you no longer want to try this exercise.

If you want to get admin rights again, execute the following:

```bash
mv ~/.kube/config.bak ~/.kube/config
```

To get restricted access again, only execute `./handicap-me.sh`.
