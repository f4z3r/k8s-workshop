# Pwn Me

> Full attack vector to get a better idea of the general attack can be found under
[`full-attack-vector.md`][attack-vector].

[attack-vector]: ./full-attack-vector.md

> Solution and tips can be found under [`solution.md`][solution].

[solution]: ./solution.md

> This is a quite advanced multi-stage attack. Please make sure that you understand the following
> concepts before starting:
>
> - RBAC and ServiceAccounts.
> - The Kubernetes API and how to access it without kubectl.
> - Volume mounts.
> - Read up on static pods (this will not be used in the attack, but would be used for persistent
>   access).


This scenario simulates what could happen if an application level security issue allowed RCE (remote
code execution) within the container, and security best practices are not followed, or you simply
get unlucky.

Note that the same attack would be possible with a powerful SSRF (server-side request forgery)
attack, but it would require much more coding and be more involved, therefore we will not get into
the details of it.

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
is the container running within the `vulnerable-app` pod in the `pwn-me` namespace.

Your setup should now be such that you are only allowed to perform the following call:

```bash
kubectl -n pwn-me exec -it vulnerable-app -- sh
```

Nearly no other `kubectl` commands will work from your VM. Do not try to break the setup within your
VM, as an attacker you would not have access to this. Please perform all you actions within the
container, simulating that you somehow got access to the container via an application vulnerability.

Execute into the pod, and work from there.

## Cluster Reset

> This is in case you no longer want to try this exercise!

If you want to get admin rights again, execute the following within your VM:

```bash
mv ~/.kube/config.bak ~/.kube/config
```

To get restricted access again, only execute `./handicap-me.sh`.
