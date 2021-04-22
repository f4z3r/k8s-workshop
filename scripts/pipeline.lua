#!/usr/bin/env lua

--[[
Author: Jakob Beckmann <jakob.beckmann@ipt.ch>
Description:
 Pipeline definition for UCC workshop to simulate a deployment of a SpringBoot application to a
 Kubernetes cluster via a pipeline.
Dependencies:
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
  return os.execute("kubectl version > /dev/null 2>&1")
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

function is_proxy_running()
  return os.execute("ps -C kubectl > /dev/null 2>&1")
end

function setup_dashboard()
  local sa_file = "./assets/sa.yaml"
  local crb_file = "./assets/crb.yaml"
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
  local cmd = "k3d cluster create %s -a 3 -s 1 --api-port 0.0.0.0:6550"
  local worked = os.execute(string.format(cmd, name))
  cmd = "docker run --name %s -d -p 5000:5000 registry:2"
  worked = worked and os.execute(string.format(cmd, registry))
  cmd = "docker network connect k3d-%s %s"
  worked = worked and os.execute(string.format(cmd, name, registry))
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
  elseif not is_cluster_running(cluster_name) then
    if not create_cluster(cluster_name, registry_name) then
      io.write("ERROR: failed to create cluster for pipeline\n")
      os.exit(127)
    end
  elseif not is_proxy_running() then
    if not setup_dashboard() then
      io.write("ERROR: failed to create cluster dashboard\n")
      os.exit(127)
    end
  end
end

function build_image(name, registry)
  local filename = "./dockerfile-pipeline"
  local del = write_file(filename, dockerfile)
  local cmd = "docker build -t %s.localhost:5000/%s:pipeline -f %s ./"
  local worked = os.execute(string.format(cmd, registry, name, filename))
  cmd = "docker push %s.localhost:5000/%s:pipeline"
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
end

main()
