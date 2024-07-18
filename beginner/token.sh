#!/usr/bin/env sh

set -euo pipefail

secret=$(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}")
token=$(kubectl -n kubernetes-dashboard get secret $secret -o go-template="{{.data.token | base64decode}}")
echo "$token"
