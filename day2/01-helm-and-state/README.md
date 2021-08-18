# Helm and State Management

As we saw yesterday, state should not be managed by your own applications, but should be
externalized to other services. In this scenario we will create a small stateful application, which
will manage its state via Redis.

> Before starting, ensure you have the cluster from the pipeline yesterday started.

Steps to follow:

1. Create a namespace in your cluster called `helm-and-state`.
2. Use `helm` to deploy a Redis instance. If you want, deploy a Redis cluster that shards across
   several instances.
3. Play around with Redis a little if you want.
4. Using the base code structure provided in this directory, adapt the places in the code marked by
   `TODO(@jakob):` flags. Make sure to understand the entire code, including the `/liveness` and
   `/readiness` endpoints.
5. Build the code with `docker` using the provided `Dockerfile`, calling the image
   `k3d-registry-pipeline-cluster.localhost.localhost:5000/helm-and-state:0.1.0`. Check out the
   `Dockerfile` for a reminder.
6. Push the image to your local registry.
7. Deploy your application to Kubernetes using a deployment.
8. Try to expose your application outside your cluster. Note that the ingress endpoint on your
   machine is `localhost:9080`.
9. Easily scale your application up and down since it should be fully stateless.
10. Configure liveness and readiness probes for your deployment so that Kubernetes can better track
    your application's health.
