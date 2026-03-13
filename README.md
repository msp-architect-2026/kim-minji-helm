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
        └── secret.yaml
```

<br>

## ▍각 Chart 스펙 요약

### frontend

| 항목 | 값 |
|------|----|
| 네임스페이스 | `application` |
| replicaCount | 1 |
| CPU requests / limits | 100m / 300m |
| Memory requests / limits | 128Mi / 256Mi |
| Probe | liveness / readiness TCP 포트 확인 |
| 특이사항 | nginx SPA fallback, Ingress 비활성화 (별도 infra chart 관리) |

### backend

| 항목 | 값 |
|------|----|
| 네임스페이스 | `application` |
| replicaCount | 1 |
| CPU requests / limits | 250m / 1000m |
| Memory requests / limits | 512Mi / 1Gi |
| Readiness Probe | `/actuator/health`, initialDelay 10s |
| Liveness Probe | `/actuator/health`, initialDelay 20s |
| Secret | SealedSecret (`backend-secret`) |
| ServiceMonitor | `/actuator/prometheus`, 30s interval |

### ai-serving

| 항목 | 값 |
|------|----|
| 네임스페이스 | `ai-serving` |
| replicaCount | 1 (HPA 최대 4개) |
| CPU requests / limits | 500m / 1500m |
| Memory requests / limits | 1Gi / 3Gi |
| nodeSelector | `kubernetes.io/hostname: k3s-ai2` |
| HPA | minReplicas 1 / maxReplicas 4 / CPU 70% 기준 |
| Readiness Probe | `/health`, initialDelay 60s, period 10s, failureThreshold 12 |
| Liveness Probe | `/health`, initialDelay 120s, period 30s, failureThreshold 6 |
| ServiceMonitor | `/metrics`, 30s interval |

### mysql

| 항목 | 값 |
|------|----|
| 네임스페이스 | `storage` |
| image | `mysql:8.0` |
| nodeSelector | `k3s-w1` 고정 |
| PVC | 10Gi, ReadWriteOnce (local-path-provisioner) |
| CPU requests / limits | 200m / 1000m |
| Memory requests / limits | 512Mi / 1Gi |
| Secret | `mysql-secret` |

### minio

| 항목 | 값 |
|------|----|
| 네임스페이스 | `storage` |
| image | `minio/minio:RELEASE.2024-01-16T16-07-38Z` |
| nodeSelector | `k3s-w1` 고정 |
| PVC | 10Gi, ReadWriteOnce |
| CPU requests / limits | 200m / 600m |
| Memory requests / limits | 256Mi / 512Mi |
| apiPort / consolePort | 9000 / 9001 |
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



