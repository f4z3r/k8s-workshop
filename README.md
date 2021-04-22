# UCC Workshop

* [Preparation](#preparation)
* [Workshop Overview](#workshop-overview)
  * [Docker](#docker)
  * [Pipeline](#pipeline)
  * [Kubernetes](#kubernetes)

---

## Preparation

Please follow the instructions described in [`prep.md`][0] before the workshop in order to have the
environment up and running and be ready on the day of the workshop.

[0]: ./prep.md

## Workshop Overview

In case you have not ready, please clone this repository to the VM:

```bash
git clone https://github.com/jakobbeckmann/ucc-workshop.git
```

And initialize the git submodules to obtain our demo application:

```bash
git submodule update --init --checkout
```

### Docker

You should find a [Dockerfile][1] in the project root. This Dockerfile is used to build the Docker
image containing our demo application. It essentially describes the steps that are required to
obtain the image on which the containers that run the application will be based on.

Have a look at the [Dockerfile][1] and try to understand what it is doing. You can then build the
Docker image by running:

```bash
# in project root
docker build -t ucc-demo:0.1.0 ./
```

This generates an image named `ucc-demo` with tag (a way to version images) `0.1.0`. The directory
in which to find the Dockerfile should be `./`, as provided by the last argument to the command.

Once the image is built, you can run a container locally using:

```bash
docker run --rm -p 8080:8080 ucc-demo:0.1.0
```

This will launch a container based on the `ucc-demo:0.1.0` image and bind the port `8080` from the
container to the host port `8080`. Therefore, any API exposed within the container on port `8080`
should be available via the browser on `localhost:8080`. As our demo application does indeed expose
an endpoint on said port, open your browser and see if you can get a response from the SpringBoot
application running inside the container (try to access `localhost:8080/customers/1` and check if
Hans Zimmer appears).

> The `--rm` flag is simply used to automatically delete the container once it is stopped. Otherwise
> the container would still be lying around on our machine once it exited.

To stop the container, simply press `Ctrl-c` in the terminal session where you launched it.

[1]: ./Dockerfile

### Pipeline


### Kubernetes
