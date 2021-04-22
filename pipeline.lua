#!/usr/bin/env lua

--[[
Author: Jakob Beckmann <jakob.beckmann@ipt.ch>
Description:
 Pipeline definition for UCC workshop to simulate a deployment of a SpringBoot application to a
 Kubernetes cluster via a pipeline. This performs the following:
  - Check that all required tools are installed.
  - Deploy a local Kubernetes cluster with 3 agent and 1 server node.
  - Create a local docker registry which is attached to the Kubernetes cluster network.
  - Deploy the standard Kubernetes dashboard to have a graphical overview of the cluster.
  - Create a ServiceAccount and ClusterRoleBinding to give admin rights to the user when accessing
    the dashboard.
  - Build a docker image of a custom application, and push it to the shared local registry.
  - Deploy the docker image as an application with:
    - A Deployment for the actual image.
    - A Secret to show how to inject environment variables.
    - A ConfigMap to show how to inject configuration.
    - A Service to forward traffic to the deployed services.
    - A Ingress to allow external traffic.
Dependencies:
 - Lua 5.3
External Dependencies:
 - kubectl
 - k3d
 - docker
]]--

local cluster_name = "pipeline-cluster"
local registry_name = "registry-pipeline-cluster"

local dashboard_link = "https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml"
local dashboard_sa = [[
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
]]

local dashboard_crb = [[
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
]]

local k8s_ns = "demo"
local k8s_deployment = [[
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: sb-demo
  name: sb-demo-deploy
  namespace: demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: sb-demo
  template:
    metadata:
      labels:
        app: sb-demo
    spec:
      containers:
      - image: k3d-registry-pipeline-cluster.localhost:5000/pipeline-cluster:pipeline
        imagePullPolicy: Always
        env:
        - name: JDBC_URL
          valueFrom:
            secretKeyRef:
              name: sb-demo-db-creds
              key: db-url
        - name: JDBC_USER
          valueFrom:
            secretKeyRef:
              name: sb-demo-db-creds
              key: db-user
        - name: JDBC_PASSWORD
          valueFrom:
            secretKeyRef:
              name: sb-demo-db-creds
              key: db-password
        name: sb-demo
        ports:
        - containerPort: 8080
          protocol: TCP
          name: http
        volumeMounts:
        - name: config-volume
          mountPath: /app/application.properties
          subPath: application.properties
      volumes:
        - name: config-volume
          configMap:
            name: sb-demo-cm
]]
local k8s_service = [[
apiVersion: v1
kind: Service
metadata:
  labels:
    app: sb-demo
  name: sb-demo-svc
  namespace: demo
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: sb-demo
  type: ClusterIP
]]
local k8s_ingress = [[
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sb-demo
  namespace: demo
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: sb-demo-svc
            port:
              number: 8080
]]
local k8s_secret = [[
apiVersion: v1
data:
  db-url: amRiYzpvcmFjbGU6dGhpbjpAbXlvcmFjbGUuZGIuc2VydmVyOjE1MjE6bXlfc2lk
  db-user: amFrb2I=
  db-password: c3VwZXJzZWNyZXQ=
kind: Secret
metadata:
  name: sb-demo-db-creds
  namespace: demo
type: Opaque
]]

local dockerfile = [[
# Build image
FROM maven:3.8.1-jdk-8 AS maven

WORKDIR /app

COPY ./app/pom.xml ./pom.xml
RUN mvn dependency:go-offline -B

COPY ./app/src ./src
RUN mvn package


# Runtime image
FROM openjdk:8-jre

WORKDIR /app

RUN useradd -U spring
USER spring:spring

COPY --from=maven /app/target/sb-next-level-0.0.1-SNAPSHOT.jar ./sb-next-level-0.0.1-SNAPSHOT.jar

CMD ["java", "-jar", "./sb-next-level-0.0.1-SNAPSHOT.jar"]
]]


function get_arg()
  if arg[1] == nil or arg[1] == "prep" or arg[1] == "token" then
    return arg[1]
  end
  io.write(string.format("ERROR: invalid argument: %s\n", arg[1]))
  os.exit(1)
end

function write_file(name, contents)
  local fh = io.open(name, "w")
  fh:write(contents)
  fh:close()
  return function() return os.execute("rm "..name) end
end

function run(cmd)
  local fh = io.popen(cmd)
  local out = fh:read("a")
  fh:close()
  return out
end

function run_lines(cmd)
  local fh = io.popen(cmd)
  return fh:lines()
end

function is_docker_running()
  local out = run("systemctl status docker")
  local match = out:match("Active: (%w+)")
  return match == "active"
end

function is_k3d_installed()
  return os.execute("k3d --version > /dev/null 2>&1")
end

function is_kubectl_installed()
  return os.execute("kubectl -h > /dev/null 2>&1")
end

function is_cluster_running(name)
  local out = run_lines("k3d cluster list")
  local found = false
  for line in out do
    if line:sub(0, #name) == name then
      found = true
      for current, total in line:gmatch("(%d)/(%d)") do
        if current ~= total then
          return false
        end
      end
    end
  end
  return found
end

function is_dashboard_deployed()
  return os.execute("kubectl get ns/kubernetes-dashboard > /dev/null 2>&1")
end

function setup_dashboard()
  local sa_file = os.tmpname()
  local crb_file = os.tmpname()
  local cmd = "kubectl apply -f %s"
  local worked = os.execute(string.format(cmd, dashboard_link))
  local del_sa = write_file(sa_file, dashboard_sa)
  worked = worked and os.execute(string.format(cmd, sa_file))
  worked = worked and del_sa()
  local del_crb = write_file(crb_file, dashboard_crb)
  worked = worked and os.execute(string.format(cmd, crb_file))
  worked = worked and del_crb()
  return worked
end

function create_cluster(name, registry)
  local cmd = "k3d registry create %s.localhost --port 5000"
  local worked = os.execute(string.format(cmd, registry))
  cmd = 'k3d cluster create %s -a 3 -s 1 --api-port 0.0.0.0:6550 -p "9080:80@loadbalancer" --registry-use k3d-%s.localhost:5000'
  worked = worked and os.execute(string.format(cmd, name, registry))
  worked = worked and os.execute("sleep 10s")
  worked = worked and os.execute("kubectl create ns "..k8s_ns)
  return worked
end

function pre_checks()
  if not is_docker_running() then
    io.write("ERROR: docker does not seem to be running\n")
    os.exit(127)
  elseif not is_kubectl_installed() then
    io.write("ERROR: kubectl does not seem to be installed\n")
    os.exit(127)
  elseif not is_k3d_installed() then
    io.write("ERROR: k3d does not seem to be installed\n")
    os.exit(127)
  end

  if not is_cluster_running(cluster_name) then
    if not create_cluster(cluster_name, registry_name) then
      io.write("ERROR: failed to create cluster for pipeline\n")
      os.exit(127)
    end
  end

  if not is_dashboard_deployed() then
    if not setup_dashboard() then
      io.write("ERROR: failed to create cluster dashboard\n")
      os.exit(127)
    end
  end
end

function build_image(name, registry)
  local filename = "./dockerfile-pipeline"
  local del = write_file(filename, dockerfile)
  local cmd = "docker build -t k3d-%s.localhost:5000/%s:pipeline -f %s ./"
  local worked = os.execute(string.format(cmd, registry, name, filename))
  cmd = "docker push k3d-%s.localhost:5000/%s:pipeline"
  worked = worked and os.execute(string.format(cmd, registry, name))
  worked = worked and del()
  return worked
end

function print_sa_token()
  local cmd = 'kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}"'
  local secret_name = run(cmd)
  cmd = 'kubectl -n kubernetes-dashboard get secret %s -o go-template="{{.data.token | base64decode}}"'
  local token = run(string.format(cmd, secret_name))
  io.write(token, "\n")
end

function kube_apply_contents(contents)
  local filename = os.tmpname()
  local del_file = write_file(filename, contents)
  local worked = os.execute("kubectl apply -f "..filename)
  worked = worked and del_file()
  return worked
end

function create_configmap()
  local cmd = 'kubectl apply -f ./configmap.yaml'
  return os.execute(cmd)
end

function deploy()
  local worked = kube_apply_contents(k8s_service)
  worked = worked and kube_apply_contents(k8s_secret)
  worked = worked and create_configmap()
  worked = worked and kube_apply_contents(k8s_deployment)
  worked = worked and kube_apply_contents(k8s_ingress)
  return worked
end

function main()
  pre_checks()
  if get_arg() == "prep" then
    return
  elseif get_arg() == "token" then
    print_sa_token()
    return
  end
  if not build_image(cluster_name, registry_name) then
    io.write("ERROR: failed to create build image\n")
    os.exit(124)
  end
  if not deploy() then
    io.write("ERROR: deployment failed\n")
    os.exit(124)
  end
end

main()
