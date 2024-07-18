#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# jq feature gate
if ! command jq --version > /dev/null 2>&1; then
  echo "Please install jq before continuing."
fi

# idempotence check
if [ -f ${HOME}/.kube/config.bak ]; then
  echo "You already ran this script, aborting."
  exit 1
fi

# create backup of kubeconfig
cp ${HOME}/.kube/config ${HOME}/.kube/config.bak

# create new user
secret=$(kubectl -n pwn-me get sa user-sa -o json | jq -r .secrets[].name)
user_token=$(kubectl get secret $secret -o json | jq -r '.data["token"]' | base64 -d)
kubectl get secret $secret -o json | jq -r '.data["ca.crt"]' | base64 -d > ca.crt
c=$(kubectl config current-context)
name=$(kubectl config get-contexts $c | awk '{print $3}' | tail -n 1)
endpoint=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"$name\")].cluster.server}")

kubectl config set-cluster cluster-attack \
   --embed-certs=true \
   --server=$endpoint \
   --certificate-authority=./ca.crt

rm ./ca.crt

kubectl config set-credentials user-attack --token=$user_token

kubectl config set-context context-attack \
   --cluster=cluster-attack \
   --user=user-attack \
   --namespace=pwn-me

 kubectl config use-context context-attack

