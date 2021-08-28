# Full Attack Vector

This document show the entire attack vector from A to Z, without showing how individual steps are
achieved. This is supposed to help advance with the attack without requiring to do too much
exploration.


## TLDR

The attack vector looks as follows:

- RCE through application level vulnerability.
- ServiceAccount privilege exploitation to create pod that mounts host file system.
- Due to exec privileges missing, use a SSH daemon in target pod to gain access.
- If not landing on control-plane node, try to schedule the pod on control plane via affinty.
  - Achieved via exploration on agent node. Control-plane hostname is easily guessed.
- Use master Kubernetes configuration on control-plane to pwn cluster.
  - From here we could install a backdoor via static manifests to get persistent access.
  - From here we would also clean up our traces, such as:
    - deleting created resources during attack,
    - deleting audit logs,
    - modify installation to hide our future activity.
- Provide our vulnerable application cluster-admin rights to have simpler access.

## Overview

The idea is to try to escape onto a master node in order to get privileged access to the Kubernetes
API. This privileged access then enables us to perform any actions required post-exploitation to for
instance take over the cluster. Taking over a cluster can have several advantages:

- Enable the setup of a backdoor to permit persistent access.
- Hijacking of cluster resources for personal gain, such as for crypto mining.
- Trade secret discovery (industrial espionage).
- Destruction of existing workloads to disrupt services of the legitimate cluster owner.
- ...

The problem we have, is that escaping onto a master node cannot be easily done from within the Pod
in which we discovered our RCE vulnerability. Note it might still be possible via a 0-day in the
virtualization software used by the cluster (`containerd`), but this makes it much less likely and
much more complex as an attack. Therefore we instead try to move laterally within the cluster and
create resources that might help us with an escape.


## Lateral Movement

Moving laterally within the cluster means hopping from node to node, or container to container. In
our case, since we landed in a container, we want to move laterally into another container. This is
typically difficult to perform. However, when investigating the privileges of the container we
landed in, you should find you are able to create containers. This should allow you to create
containers that are intentionally vulnerable and hop onto those.

> Note that you might think this is not possible in enterprise scenarios, as the cluster is only
> allowed to pull images from trusted container registries. While it is true that this makes it a
> _little_ but more complex, it does not stop us at all. Any enterprise has an image that contains a
> Java runtime environment or a Python interpreter. You can then simply mount your JARs or Python
> scripts into the image and overwrite entrypoints and arguments. This would allow you to run
> arbitrary software, while at the cost of a little bit more effort.

## Vertical Movement

Vertical movement refers to moving from a container to a node, or vice-versa. In our case it means
the latter, as we are within a container and want to land on a control plane node. There are several
container escape techniques that are commonly known. The simplest of them all is by mounting the
entire host file system into the container, and `chroot`ing into it. Note that this is not exactly
the same as opening a shell on the node itself, as stuff like the environment is not automatically
taken over, but such things can easily be manually adapted. Once you have performed the `chroot`,
you would typically go into exploration phase:

- What is on the host?
- What network level access does it have (is it contained in a different network zone)?
- Is there sensitive information that it can reveal (certificates, passwords, important
  configuration, etc)?
- Is its IP whitelisted somewhere for privileged access?
- Can the node provide more information about the cluster it holds to perform more advanced attacks
  within the cluster?
- ...


## Node Exploitation

Once you are on the node and have found all the information you need/desire, it is time to take that
information and turn it into something useful. Specifically, you want to own the cluster it runs.
Typically Kubernetes Control-Plane nodes have very privileged access to the Kubernetes API since
they require it on boot. Moreover, as the nodes themselves host a replication of the API controller,
it is guaranteed you can access the API without having to pass through a network (no firewall
issues, etc).

You can use this privileged access to perform your next steps of exploitation, or post-exploitation
chaos.

In our case, you would essentially be done as you might be cluster-admin with the access from the
node, but try to either setup a backdoor in the cluster, or at least provide you cluster-admin
rights directly in the pod that contained the RCE. That way you would need less effort for the next
access.

Generally control-plane nodes also contain the configuration and data for Kubernetes security. This
includes audit logs, potential node hardening software, etc. This might be your moment to hide your
activity on the cluster, so that your hack is invisible to the cluster admins. Note that until this
point, if the admins are continuously monitoring the cluster, your hack might have been detected
(clusters tend to be continuously monitored in larger organizations, but not with people that
understand what everything means 24/7). Therefore, if you would manage to perform such an attack
within a couple of hours (ideally during either development spikes, or during night), and then
correctly hide your work, I would consider it extremely unlikely that the hack is detected.
Moreover, the larger the cluster (the more audit activity happens on the cluster, and the more
varied that activity is), the less likely a detection.
