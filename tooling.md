# Tooling

If you are interesting in cool tooling for Kubernetes, this will list a couple of useful tools, what
they are useful for, and where to find more information about them.


## K9s

My hands-down most favourite tool for Kubernetes. It provides an interactive dashboard within your
terminal so you can monitor and manage your cluster from there. One of its nicest features is how
easily it allows you to execute into a container for debugging. It is very customizable and simply a
super amazing tool!

It integrates with other tools like Xray and pulses, but I have to admin that I rarely use these.

Homepage: https://k9scli.io/


## Stern

Stern is a log aggregator for Kubernetes. It allows you to pull logs from Kubernetes containers in a
much more fine-grained manner than `kubectl`. I personally don't use it much as `k9s` provides very
good log support as well, with searchable logs.

Homepage: https://github.com/stern/stern


## Helm

Helm is the "Kubernetes package manager". You will have to use it in quite a few examples. It should
already be installed on your VM.

Homepage: https://helm.sh/


## Kubectx

Kubectx and Kubens are tools to manage your Kubernetes contexts and namespaces. This is mostly
useful so you don't always need to add the `-n` flag to all your `kubectl` commands, and when you
work with several clusters at the same time. I use them a lot on a daily basis.

Homepage: https://github.com/ahmetb/kubectx
