#! /bin/bash

#platform
CLUSTER_NAME=lyon-cluster-platform
CLUSTER_BY=platform
DEFAULT_POLICY=EKSPlatformNodePolicy

#staging
#CLUSTER_NAME=lyon-cluster-staging
#CLUSTER_BY=staging
#DEFAULT_POLICY=EKSStagingNodePolicy

#production
#CLUSTER_NAME=lyon-cluster-production
#CLUSTER_BY=production
#DEFAULT_POLICY=EKSProductionNodePolicy

CLUSTER_DEFAULT=lyon-cluster

AWS_PARTITION="aws" # if you are not using standard partitions, you may need to configure to aws-cn / aws-us-gov
AWS_REGION="$(aws configure list | grep region | tr -s " " | cut -d" " -f3)"
OIDC_ENDPOINT="$(aws eks describe-cluster --name ${CLUSTER_NAME} \
    --query "cluster.identity.oidc.issuer" --output text)"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' \
    --output text)


function CreateIAMRole() {
  echo 'CREATE IAM Role'
  echo '{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Principal": {
                  "Service": "ec2.amazonaws.com"
              },
              "Action": "sts:AssumeRole"
          }
      ]
  }' > node-trust-policy.json

  # Now attach the required policies to the role
  aws iam create-role --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
      --assume-role-policy-document file://node-trust-policy.json

  aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
      --policy-arn arn:${AWS_PARTITION}:iam::aws:policy/AmazonEKSWorkerNodePolicy

  aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
      --policy-arn arn:${AWS_PARTITION}:iam::aws:policy/AmazonEKS_CNI_Policy

  aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
      --policy-arn arn:${AWS_PARTITION}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

  aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
      --policy-arn arn:${AWS_PARTITION}:iam::aws:policy/AmazonSSMManagedInstanceCore

  # lyon added policies
  aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
      --policy-arn arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:policy/node-${CLUSTER_BY}-route53-policy
  aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
      --policy-arn arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:policy/node-${CLUSTER_BY}-alb-ingress-controller-policy
  aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
      --policy-arn arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:policy/${DEFAULT_POLICY}

  # Attach the IAM role to an EC2 instance profile.
  aws iam create-instance-profile \
      --instance-profile-name "KarpenterNodeInstanceProfile-${CLUSTER_NAME}"

  aws iam add-role-to-instance-profile \
      --instance-profile-name "KarpenterNodeInstanceProfile-${CLUSTER_NAME}" \
      --role-name "KarpenterNodeRole-${CLUSTER_NAME}"
}

function CreateControllerPolicy() {
  echo 'CREATE Controller Policy'
  echo '{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Principal": {
                  "Federated": "arn:'${AWS_PARTITION}':iam::'${AWS_ACCOUNT_ID}':oidc-provider/'${OIDC_ENDPOINT#*//}'"
              },
              "Action": "sts:AssumeRoleWithWebIdentity",
              "Condition": {
                  "StringEquals": {
                      "'${OIDC_ENDPOINT#*//}':aud": "sts.amazonaws.com",
                      "'${OIDC_ENDPOINT#*//}':sub": "system:serviceaccount:karpenter:karpenter"
                  }
              }
          }
      ]
  }' > controller-trust-policy.json
  aws iam create-role --role-name KarpenterControllerRole-${CLUSTER_NAME} \
      --assume-role-policy-document file://controller-trust-policy.json

  echo '{
       "Statement": [
           {
               "Action": [
                   "ssm:GetParameter",
                   "ec2:DescribeImages",
                   "ec2:RunInstances",
                   "ec2:DescribeSubnets",
                   "ec2:DescribeSecurityGroups",
                   "ec2:DescribeLaunchTemplates",
                   "ec2:DescribeInstances",
                   "ec2:DescribeInstanceTypes",
                   "ec2:DescribeInstanceTypeOfferings",
                   "ec2:DescribeAvailabilityZones",
                   "ec2:DeleteLaunchTemplate",
                   "ec2:CreateTags",
                   "ec2:CreateLaunchTemplate",
                   "ec2:CreateFleet",
                   "ec2:DescribeSpotPriceHistory",
                   "pricing:GetProducts"
               ],
               "Effect": "Allow",
               "Resource": "*",
               "Sid": "Karpenter"
           },
           {
               "Action": "ec2:TerminateInstances",
               "Condition": {
                   "StringLike": {
                       "ec2:ResourceTag/karpenter.sh/provisioner-name": "*"
                   }
               },
               "Effect": "Allow",
               "Resource": "*",
               "Sid": "ConditionalEC2Termination"
           },
           {
               "Effect": "Allow",
               "Action": "iam:PassRole",
               "Resource": "arn:'${AWS_PARTITION}':iam::'${AWS_ACCOUNT_ID}':role/KarpenterNodeRole-'${CLUSTER_NAME}'",
               "Sid": "PassNodeIAMRole"
           },
           {
               "Effect": "Allow",
               "Action": "eks:DescribeCluster",
               "Resource": "arn:'${AWS_PARTITION}':eks:'${AWS_REGION}':'${AWS_ACCOUNT_ID}':cluster/'${CLUSTER_NAME}'",
               "Sid": "EKSClusterEndpointLookup"
           }
       ],
       "Version": "2012-10-17"
   }' > controller-policy.json
  aws iam put-role-policy --role-name KarpenterControllerRole-${CLUSTER_NAME} \
      --policy-name KarpenterControllerPolicy-${CLUSTER_NAME} \
      --policy-document file://controller-policy.json
}

function AddTagSGAndSubnetByCluster() {
  echo 'ADD Tag SecurityGroups And Subnet By Cluster'
  # add subnet tag
  # tag - karpenter.sh/discovery=lyon-cluster
  for NODEGROUP in $(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} \
      --query 'nodegroups' --output text); do aws ec2 create-tags \
          --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_DEFAULT}" \
          --resources $(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} \
          --nodegroup-name $NODEGROUP --query 'nodegroup.subnets' --output text )
  done


  # add sg tag
  SECURITY_GROUPS=$(aws eks describe-cluster \
      --name ${CLUSTER_NAME} --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)

  aws ec2 create-tags \
      --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}" \
      --resources ${SECURITY_GROUPS}
}

CreateIAMRole
CreateControllerPolicy
AddTagSGAndSubnetByCluster