# Draft: Full GCP IaC Architecture Migration

## Requirements (confirmed)
- **예산**: 30만 원 (1주일 운영)
- **플랫폼**: GCP (K8s 없이)
- **기간**: 1주일 시연 (하지만 Full IaC 선택으로 2주 권장)
- **핵심 시나리오**: Service A 부하 시연 (JMeter → Circuit Breaker → Redis 캐시)

## Technical Decisions (사용자 확정)
- **VM**: e2-standard-4 (16GB/4vCPU) 유지
- **LB**: Cloud Armor + HTTPS Load Balancer
- **Redis**: Memorystore for Redis (1GB Basic)
- **PostgreSQL**: Cloud SQL (db-custom-2-8192) ← 신규 추가
- **IaC**: Terraform + Ansible ← 신규 추가
- **Cache 구현**: Spring Cache + Caffeine (2-Tier)
- **모니터링**: Prometheus + Cloud Monitoring 통합
- **Git 브랜치**: feature/gcp-full-iac

## 비용 영향 (1주일 기준)
- Compute Engine (e2-standard-4): ~$30
- Memorystore 1GB Basic: ~$8
- Cloud SQL (db-custom-2-8192): ~$25
- Cloud Armor: ~$1.25
- HTTPS Load Balancer: ~$4.50
- Cloud NAT: ~$7.50
- Storage + Network: ~$5
- **총계**: ~$81/주 (~₩118,000) - 예산 내 수용 가능

## Scope Boundaries
**INCLUDE**:
- Terraform: VPC, VM, Cloud SQL, Memorystore, Cloud Armor, LB
- Ansible: Docker, Ops Agent, 애플리케이션 배포
- Spring Cache + Caffein 설정
- 레거시 파일/디렉토리 정리
- CI/CD 워크플로우 수정
- 백업 전략 (Cloud SQL 자동 백업)

**EXCLUDE**:
- Kubernetes 도입
- HA 구성 (Cloud SQL, Memorystore)
- Service B Redis 통합
- 비즈니스 로직 변경

## Timeline (Revised - 2주 권장)
- **Week 1**: Terraform + Ansible + Cloud SQL + Memorystore
- **Week 2**: 애플리케이션 수정 + CI/CD + 검증

## Open Questions (해결됨)
- ~~Cloud SQL 사용 여부~~ → **사용 확정**
- ~~Terraform + Ansible 사용 여부~~ → **사용 확정**
- ~~1주일 vs 2주~~ → 사용자가 Full IaC 선택, 2주 권장
