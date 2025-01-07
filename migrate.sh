#! /bin/bash
CLUSTER_NAME=dev

function inspect() {
  kustomize build ./overlays/${CLUSTER_NAME} --enable-helm --load-restrictor=LoadRestrictionsNone > lyon-${CLUSTER_NAME}.yaml
}

function crd() {
  kubectl apply -k ./base/crds
}

function deleteManifest() {
  kubectl delete -f ./base/configmaps.yaml
  kubectl delete -f ./base/secret.yaml
  kubectl delete -f ./base/webhook.yaml
}

function apply() {
  kustomize build ./overlays/platform --enable-helm --load-restrictor=LoadRestrictionsNone | kubectl apply -f -
}

inspect

crd
deleteManifest
apply
