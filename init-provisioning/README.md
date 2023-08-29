## HPA, Deployments replicas Controlling
- Only Local

#### Obj. Node Drain 발생 시 PDB maxUnavailable 적용된 항목들의 최소 pod 확보를 위한 임시 replica 확장

- PDB maxUnavailable=1이면서 HPA의 Desired, Min replicas가 1인 항목들을 조회하고 임시 확장한다.
  - HPA 확장 이후 Deployments의 replicas가 1인 항목들을 조회하고 임시 확장한다.


### Control Step
0. 로컬 환경의 kubernetes use-context 확인 (platform, staging, production)
   - namespace 확인

1. min-replica가 1인 HPA 수집
```bash
go run get-hpa.go
```

2. patch-hpa.go Toggle 값 확인
```go
// result, err := PatchHPAs(namespace, clientset, hpa.Name, hpa.MinReplicas, hpa.MaxReplicas)
result, err := PatchHPAs(namespace, clientset, hpa.Name, hpa.MinReplicas+1, hpa.MaxReplicas+1)
```

3. HPA 확장 (+1)
```bash
go run patch-hpa.go
```

4. HPA 확장 후 replica가 1인 Deployment 수집
```bash
go run get-deployments.go
```

5. patch-deployments.go Toggle 값 확인
```go
// result, err := PatchDeployment(namespace, clientset, deploy.Name, deploy.Replicas)
result, err := PatchDeployment(namespace, clientset, deploy.Name, deploy.Replicas+1)
```

6. Deployments replicas 확장 (+1)
```bash
go run patch-deployments.go
```

7. 작업(ex. karpenter migration) 후 Toggle 변경
patch-deployments.go
```go
result, err := PatchDeployment(namespace, clientset, deploy.Name, deploy.Replicas)
// result, err := PatchDeployment(namespace, clientset, deploy.Name, deploy.Replicas+1)
```
patch-hpa.go
```go
result, err := PatchHPAs(namespace, clientset, hpa.Name, hpa.MinReplicas, hpa.MaxReplicas)
// result, err := PatchHPAs(namespace, clientset, hpa.Name, hpa.MinReplicas+1, hpa.MaxReplicas+1)
```

8. Deployments replicas 복원 (+0)
```bash
go run patch-deployments.go
```

9. HPA 복원 (+0)
```bash
go run patch-hpa.go
```