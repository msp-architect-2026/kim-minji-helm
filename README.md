<h1 align="center">kim-minji-helm</h1>

<p align="center">
  웨이퍼 결함 탐지 시스템의 <strong>Kubernetes Helm Chart</strong> 레포지토리입니다.
</p>


<p align="center">
<img src="https://img.shields.io/badge/Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white"/>
<img src="https://img.shields.io/badge/k3s-FFC61C?style=for-the-badge&logo=kubernetes&logoColor=black"/>
<img src="https://img.shields.io/badge/ArgoCD-FE5D26?style=for-the-badge&logo=argo&logoColor=white"/>
<img src="https://img.shields.io/badge/SealedSecrets-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
</p>



## ▍개요

frontend, backend, ai-serving, mysql, minio 각 서비스의 **Kubernetes 배포 구성을 Helm Chart로 정의**합니다.

GitLab CI 파이프라인이 빌드 후 이 레포의 `values.yaml`에 이미지 태그를 자동 업데이트하면, ArgoCD가 변경을 감지해 k3s 클러스터에 자동 배포하는 **GitOps 파이프라인의 중심 레포**입니다.

<br>

## ▍관련 레포지토리

| Repository | 설명 |
|------------|------|
| [kim-minji-wiki](https://github.com/msp-architect-2026/kim-minji-wiki) | 프로젝트 메인 (Wiki, 칸반보드) |
| [kim-minji-infra](https://github.com/msp-architect-2026/kim-minji-infra) | k3s 클러스터 및 GitOps 인프라 |
| [kim-minji-backend](https://github.com/msp-architect-2026/kim-minji-backend) | Spring Boot API 서버 |
| [kim-minji-frontend](https://github.com/msp-architect-2026/kim-minji-frontend) | React 웹 대시보드 |
| [kim-minji-ai](https://github.com/msp-architect-2026/kim-minji-ai) | FastAPI AI 추론 서비스 |

## ▍레포 구조

```
kim-minji-helm/
├── frontend/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── configmap.yaml      # nginx SPA fallback 설정
├── backend/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── secret.yaml         # SealedSecret
│       └── servicemonitor.yaml # Prometheus 메트릭 수집
├── ai-serving/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── hpa.yaml            # HPA (CPU 70%, max 4)
│       └── servicemonitor.yaml # Prometheus 메트릭 수집
├── mysql/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── statefulset.yaml
│       ├── service.yaml
│       ├── pvc.yaml
│       └── secret.yaml
└── minio/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── statefulset.yaml
        ├── service.yaml
        ├── pvc.yaml
        └── secret.yaml         # SealedSecret
```

<br>

## ▍프로파일 (dev / full)

| 파일 | 용도 |
|------|------|
| `values.yaml` | 공통 기본값. CI(`update-helm.sh`)가 이미지 `tag`를 갱신하는 유일한 파일 |
| `values-dev.yaml` | 노드 1~2대만 켠 개발 환경: replica 1, ai-serving 메모리 limit 1Gi·HPA max 2, ai2 선호 |
| `values-full.yaml` | 3노드 To-Be: frontend·backend replica 2, ai-serving ai2 고정 |

- ArgoCD ApplicationSet(kim-minji-infra `argocd/`)이 클러스터 `env` 라벨로 `values-<env>.yaml`을 고릅니다. 라벨이 없으면 dev입니다.
- 프로파일 파일이 없는 차트는 `values.yaml`만 씁니다.
- `update-helm.sh`가 `tag:` 문자열을 sed로 치환하므로 프로파일 파일에는 이미지 태그를 넣지 않습니다.

<br>

## ▍각 Chart 스펙 요약

### frontend

| 항목 | 값 |
|------|----|
| 네임스페이스 | `application` |
| replicaCount | dev 1 / full 2 |
| CPU requests / limits | 100m / 300m |
| Memory requests / limits | 128Mi / 256Mi |
| Probe | liveness / readiness TCP 포트 확인 |
| 특이사항 | nginx SPA fallback, Ingress 비활성화 (별도 infra chart 관리) |

### backend

| 항목 | 값 |
|------|----|
| 네임스페이스 | `application` |
| replicaCount | dev 1 / full 2 |
| CPU requests / limits | 250m / 1000m |
| Memory requests / limits | 512Mi / 1Gi |
| Readiness Probe | `/actuator/health`, initialDelay 10s |
| Liveness Probe | `/actuator/health`, initialDelay 20s |
| Secret | SealedSecret (`backend-secret`) |
| ServiceMonitor | `/actuator/prometheus`, 30s interval |
| dnsConfig | `ndots: 2` (FQDN 서비스 주소를 search domain 확장 없이 조회) |

### ai-serving

| 항목 | 값 |
|------|----|
| 네임스페이스 | `ai-serving` |
| replicaCount | 1 (HPA dev 최대 2개 / full 최대 4개) |
| CPU requests / limits | dev 250m / 1000m · full 500m / 1500m |
| Memory requests / limits | dev 512Mi / 1Gi · full 1Gi / 3Gi |
| 노드 배치 | full: `k3s-ai2` 고정(nodeSelector) · dev: `k3s-ai2` 선호(preferred affinity) |
| tolerations | `dedicated=ai-serving:PreferNoSchedule` (k3s-ai2 taint) |
| HPA | minReplicas 1 / maxReplicas dev 2 · full 4 / CPU 70% 기준 |
| Readiness Probe | `/health`, initialDelay 60s, period 10s, failureThreshold 12 |
| Liveness Probe | `/health`, initialDelay 120s, period 30s, failureThreshold 6 |
| ServiceMonitor | `/metrics`, 30s interval |
| dnsConfig | `ndots: 2` (FQDN 서비스 주소를 search domain 확장 없이 조회) |

### mysql

| 항목 | 값 |
|------|----|
| 네임스페이스 | `storage` |
| image | `mysql:8.0` |
| nodeSelector | 없음 (PV nodeAffinity를 따름) |
| PVC | 10Gi, ReadWriteOnce (local-path-provisioner) |
| CPU requests / limits | 200m / 1000m |
| Memory requests / limits | 512Mi / 1Gi |
| Secret | `mysql-secret` |

### minio

| 항목 | 값 |
|------|----|
| 네임스페이스 | `storage` |
| image | `minio/minio:RELEASE.2024-01-16T16-07-38Z` |
| nodeSelector | 없음 (PV nodeAffinity를 따름) |
| PVC | 10Gi, ReadWriteOnce |
| CPU requests / limits | 200m / 600m |
| Memory requests / limits | 256Mi / 512Mi |
| apiPort / consolePort | 9000 / 9001 |
| Secret | SealedSecret (`minio-secret`: accessKey, secretKey) |
| Probe | `/minio/health/live`, `/minio/health/ready` |

<br>

## ▍이미지 태그 자동 업데이트 흐름

```
GitLab CI (빌드 완료)
└─ update-helm.sh 실행
   └─ git clone kim-minji-helm
      └─ sed로 values.yaml tag 값 → CI_COMMIT_SHORT_SHA 교체
         └─ git commit & push
            └─ ArgoCD 3분 내 감지
               └─ Helm chart 렌더링 → k3s apply → Synced + Healthy
```

SHA 태그로 정확한 롤백 추적이 가능하며, latest 태그도 함께 push합니다.  
`HELM_REPO_TOKEN`을 각 서비스 레포 CI/CD Variables에 등록하여 이 레포에 push 권한을 부여합니다.

<br>

## ▍ArgoCD syncPolicy

```yaml
# frontend, backend, ai-serving, mysql, minio 공통
syncPolicy:
  automated: {}           # auto-sync만 활성화
  syncOptions:
    - CreateNamespace=true
```

Git push → 자동 배포는 되지만, 수동 변경은 자동 복구하지 않습니다.  
인프라 리소스(`prune: true`, `selfHeal: true`)와 달리 앱 리소스는 더 유연하게 운영합니다.

<br>

## ▍Sealed Secrets (backend-secret)

민감 정보는 Sealed Secrets controller로 암호화해 Git에 저장합니다.

```
암호화된 항목:
├─ SPRING_DATASOURCE_URL
├─ SPRING_DATASOURCE_USERNAME
├─ SPRING_DATASOURCE_PASSWORD
├─ MINIO_ENDPOINT
├─ MINIO_ACCESS_KEY
├─ MINIO_SECRET_KEY
└─ MINIO_BUCKET
```

- Git에는 `SealedSecret` 리소스(암호문)만 저장
- 클러스터 내 Sealed Secrets controller가 복호화 → `Secret` 생성
- ArgoCD GitOps로 배포 및 복호화 동작 검증 완료

<br>

## ▍mysql SealedSecret 생성

`mysql/templates/secret.yaml`은 `values.yaml`의 `sealedSecret.encryptedData`로 SealedSecret을 렌더링합니다.  
4개 키 중 하나라도 비어 있으면 렌더링이 실패하므로 평문 Secret이 배포될 수 없습니다.

MySQL 데이터 디렉터리는 이미 초기화되어 있으므로 **현재 클러스터에 있는 값 그대로** 암호화해야 합니다. 클러스터 노드에서 실행합니다.

```bash
NS=storage; NAME=mysql-secret
for k in MYSQL_ROOT_PASSWORD MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD; do
  v=$(kubectl -n $NS get secret $NAME -o jsonpath="{.data.$k}" | base64 -d)
  printf '    %s: %s\n' "$k" "$(printf '%s' "$v" | kubeseal --raw --namespace $NS --name $NAME --from-file=/dev/stdin)"
done
```

출력된 4줄을 `mysql/values.yaml`의 `sealedSecret.encryptedData: {}`에서 `{}`를 지운 뒤 그 아래에 붙여 넣습니다.  
controller가 `kube-system/sealed-secrets-controller`가 아니면 `kubeseal`에 `--controller-namespace`, `--controller-name`을 추가합니다.

기존 `mysql-secret`은 ArgoCD가 만든 일반 Secret이라 controller가 덮어쓰지 않습니다. 첫 배포 전에 한 번 소유권을 넘겨 줍니다.

```bash
kubectl -n storage annotate secret mysql-secret sealedsecrets.bitnami.com/managed=true
```

적용 순서는 **annotate → 암호문 values 커밋 → ArgoCD sync**입니다. annotate 전에 sync되면 controller가 `already exists and is not managed by SealedSecret` 오류를 내고 기존 Secret을 그대로 둡니다(데이터 손실 없음).  
전환 후 `mysql-secret`은 SealedSecret이 소유하므로, SealedSecret이나 mysql 앱을 cascade 삭제하면 Secret도 함께 지워져 MySQL Pod 재시작이 실패합니다.

<br>

## ▍minio SealedSecret 생성

`minio/templates/secret.yaml`은 `values.yaml`의 `sealedSecret.encryptedData`(`accessKey`, `secretKey`)로 SealedSecret을 렌더링합니다. 값이 비어 있으면 렌더링이 실패합니다.

MinIO 데이터는 이미 현재 루트 계정으로 초기화되어 있으므로 **클러스터에 있는 `minio-secret` 값 그대로** 암호화합니다. 클러스터 노드에서 실행합니다.

```bash
NS=storage; NAME=minio-secret
for k in accessKey secretKey; do
  v=$(kubectl -n $NS get secret $NAME -o jsonpath="{.data.$k}" | base64 -d)
  printf '    %s: %s\n' "$k" "$(printf '%s' "$v" | kubeseal --raw --namespace $NS --name $NAME --from-file=/dev/stdin)"
done
```

출력된 2줄을 `minio/values.yaml`의 `sealedSecret.encryptedData: {}`에서 `{}`를 지운 뒤 그 아래에 붙여 넣습니다.  
기존 `minio-secret`은 수동으로 만든 Secret이라 controller가 덮어쓰지 않습니다. 첫 배포 전에 소유권을 넘깁니다.

```bash
kubectl -n storage annotate secret minio-secret sealedsecrets.bitnami.com/managed=true
```

적용 순서와 주의사항은 mysql과 같습니다 (annotate → 암호문 커밋 → ArgoCD sync, SealedSecret cascade 삭제 시 Secret도 삭제).

<br>

## ▍GitLab Registry 연동

모든 앱 Deployment에 `imagePullSecrets: gitlab-registry-secret`을 설정합니다.

CoreDNS custom 설정(`gitlab.local → 192.168.0.157`)으로 클러스터 내부에서 GitLab Registry(`gitlab.local:5050`) 이미지 pull을 지원합니다.

<br>

## ▍네임스페이스 구성

| 네임스페이스 | Chart |
|-------------|-------|
| `application` | frontend, backend |
| `ai-serving` | ai-serving |
| `storage` | mysql, minio |

스토리지 네임스페이스의 mysql/minio는 ClusterIP 서비스로만 접근 가능하며 외부로 노출되지 않습니다.

<br>

## ▍정적 검증

```bash
scripts/validate.sh          # dev, full 모두
scripts/validate.sh dev      # 특정 프로파일만
```

- 클러스터 접속 없이 차트별로 `helm lint`, `helm template`, `kubeconform`, `yamllint`를 실행합니다. 대상은 `scripts/releases.txt`에 등록합니다.
- 차트의 `ci/test-values.yaml`은 검증 전용 더미 값(SealedSecret 암호문 자리 등)이며 배포에는 쓰지 않습니다.
- 클러스터 작업 순서는 [kim-minji-infra `docs/RUNBOOK.md`](https://github.com/msp-architect-2026/kim-minji-infra/blob/develop/docs/RUNBOOK.md)를 따릅니다.
