# Karpenter

Karpenter Docs

- [Documentation](https://karpenter.sh/docs/)
- [GitHub](https://github.com/aws/karpenter)

### Releases
```text
2025-01-07: 0.36.2
2024-08-19: v0.33.6
2024-08-12: v0.32.10 by terraform
2024-05-27: v0.32.10
2024-01-30: v0.31.4
2023-09-22: v0.30.0
2023-08-29: v0.29.2
```

Karpenter는 적시에 적절한 노드로 Kubernetes 인프라를 단순화합니다.

Karpenter는 클러스터의 애플리케이션을 처리하는 데 적합한 컴퓨팅 리소스만 자동으로 시작합니다. Kubernetes 클러스터를 위한 빠르고 간단한 컴퓨팅 프로비저닝으로 클라우드를 최대한 활용할 수 있도록 설계되었습니다.

### **애플리케이션 가용성 향상**

Karpenter는 애플리케이션 로드, 일정 및 리소스 요구 사항의 변화에 신속하고 자동으로 대응하여 사용 가능한 다양한 컴퓨팅 리소스 용량에 새로운 워크로드를 배치합니다.

### **컴퓨팅 비용 절감**

Karpenter는 활용도가 낮은 노드를 제거하고 값비싼 노드를 저렴한 대안으로 교체하고 워크로드를 보다 효율적인 컴퓨팅 리소스로 통합할 수 있는 기회를 찾아 클러스터 컴퓨팅 비용을 낮춥니다.

### **운영 오버헤드 최소화**

Karpenter는 쉽게 사용자 정의할 수 있는 단일 선언적 리소스에 독자적인 기본값 세트와 함께 제공됩니다 **`NodePool`**.

## **작동 방식**

![kerpenter how to works](karpenter-how-to-works.png)

Karpenter는 예약되지 않은 포드의 총 리소스 요청을 관찰하고 예약 대기 시간과 인프라 비용을 최소화하기 위해 노드를 시작하고 종료하는 결정을 내립니다.

---
### [upgrading to v0.32.0+](https://karpenter.sh/v0.32/upgrading/v1beta1-migration/)

alpha 매니페스트를 beta 매니페스트로 변환하는데 도움이 되는 도구 설치
```bash
$ go install github.com/aws/karpenter/tools/karpenter-convert/cmd/karpenter-convert@release-v0.32.x
```
Convert to EC2NodeClass
```bash
$ karpenter-convert -f awsnodetemplate.yaml | envsubst > ec2nodeclass.yaml
```
Convert to NodePool
```bash
$ karpenter-convert -f provisioner.yaml > nodepool.yaml
```

Roll over nodes: Add the following taint to the old Provisioner: karpenter.sh/legacy=true:NoSchedule

```bash
# provisioners
$ kubectl get machines
> No resources found

# nodepools
$ kubectl get nodeclaims
```
---

## **structures**
- base
  - ec2nodeclasses
  - nodepools
- init-provisioning
  - (CAS에서 Karpenter로 migration시 안정적인 Pod 전환을 위한 항목)
- over-provisioning
  - (서비스의 고가용성 확보 및 업타임 속도 개선을 위한 항목)
    - ex. pod uptime 60~70s -> 10~15s
- overlays
  - envs(dev, staging)
    - patches
      - common ...
      - nodepools/
    - specific
      - add custom
- terraform
  - (karpenter installation)

#### karpenter kustomize의 nodepools는 다음의 목적성을 가진 NodeGroups에 대해 정의합니다.
  - cicd
  - cron
  - default
  - monitoring
  - service
  - system-critical

## **~~role binding~~**
- terraform 사용으로 추가 설정이 필요하지 않습니다.

## **pre-settings**
클러스터별 노드의 활용에 따른 NodePool spec을 정의해주어야 합니다.
관련 내용은 karpenter/overlays/platform/patches/nodepools에서 확인 할 수 있습니다.
- ex. 
```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: Never
  template:
    metadata: {}
    spec:
      nodeClassRef:
        name: lyon-cluster
      requirements:
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: [ "m" ]
        - key: karpenter.k8s.aws/instance-cpu
          operator: In
          values: [ "2", "4" ]
        - key: karpenter.k8s.aws/instance-hypervisor
          operator: In
          values: [ "nitro" ]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: [ "2" ]
        - key: kubernetes.io/arch
          operator: In
          values: [ "amd64", "arm64" ]
        - key: karpenter.sh/capacity-type
          operator: In
          values: [ "on-demand", "spot" ]
        - key: eks.amazonaws.com/nodegroup
          operator: In
          values: [ "default" ]
      taints:
        - effect: NoSchedule
          key: system-type
          value: default
```

## **installation**
```bash
terraform init
AWS_PROFILE={{YOUR_AWS_PROFILE}} terraform apply -auto-approve
```

## **get started**
```bash
kubectl apply -k platform
```

## **migration**
v0.33.6 to 0.36.2
```bash
./migrate.sh
```