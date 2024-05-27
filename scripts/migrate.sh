#! /bin/bash
CLUSTER_NAME=platform
#CLUSTER_NAME=staging
#CLUSTER_NAME=prod

export KARPENTER_NODE_ROLE="KarpenterNodeRole-${CLUSTER_NAME}"

function mkd() {
  mkdir ./overlays/${CLUSTER_NAME}/patches/nodepools
  mkdir ./overlays/${CLUSTER_NAME}/patches/nodepools/amd
  mkdir ./overlays/${CLUSTER_NAME}/patches/nodepools/arm
  mkdir ./overlays/${CLUSTER_NAME}/specific/nodepools
  mkdir ./overlays/${CLUSTER_NAME}/specific/nodepools/amd
  mkdir ./overlays/${CLUSTER_NAME}/specific/nodepools/arm
}

function crd() {
  wget https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.32.10/pkg/apis/crds/karpenter.sh_provisioners.yaml -P ./base/crds
  wget https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.32.10/pkg/apis/crds/karpenter.sh_machines.yaml -P ./base/crds
  wget https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.32.10/pkg/apis/crds/karpenter.k8s.aws_awsnodetemplates.yaml -P ./base/crds
  wget https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.32.10/pkg/apis/crds/karpenter.sh_nodepools.yaml -P ./base/crds
  wget https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.32.10/pkg/apis/crds/karpenter.sh_nodeclaims.yaml -P ./base/crds
  wget https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.32.10/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml -P ./base/crds
}

function ProvisionersConverting() {
  karpenter-convert -f ./overlays/${CLUSTER_NAME}/patches/provisioners/$1/$2.yaml | envsubst > ./overlays/${CLUSTER_NAME}/patches/nodepools/$1/$2.yaml
}

function SpecificProvisionersConverting() {
  karpenter-convert -f ./overlays/${CLUSTER_NAME}/specific/provisioners/$1/$2.yaml | envsubst > ./overlays/${CLUSTER_NAME}/specific/nodepools/$1/$2.yaml
}

function inArch() {
  arch=$1

  ProvisionersConverting ${arch} 'patch-cicd'
  ProvisionersConverting ${arch} 'patch-cron'
  ProvisionersConverting ${arch} 'patch-default'
  ProvisionersConverting ${arch} 'patch-monitoring'
  ProvisionersConverting ${arch} 'patch-service'
  ProvisionersConverting ${arch} 'patch-system-critical'

}

function gogo() {
  inArch 'amd'
  inArch 'arm'
}

#mkd
gogo