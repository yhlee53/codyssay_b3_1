# 리소스 정리 체크리스트

## 1. 실습 종료 전 확인사항

아래 항목은 과금 방지를 위해 반드시 체크해야 합니다.

### EC2
- [ ] EC2 인스턴스 종료 완료
- [ ] 인스턴스 상태가 `terminated` 확인
- [ ] 부팅 볼륨(EBS) 연결 여부 확인

### EBS
- [ ] 사용 중인 EBS 볼륨 확인
- [ ] 미사용 볼륨까지 삭제
- [ ] 삭제 완료 여부 확인

### Elastic IP
- [ ] Elastic IP 할당 여부 확인
- [ ] 할당된 EIP가 있으면 Release 완료
- [ ] `disassociated` 또는 `released` 상태 확인

### Internet Gateway
- [ ] VPC에서 IGW 연결 해제
- [ ] IGW 삭제 완료

### Route Table / Subnet / VPC
- [ ] Public Route Table 정리
- [ ] Subnet 삭제 완료
- [ ] VPC 삭제 완료

### 추가 리소스
- [ ] NAT Gateway 삭제 (생성했다면)
- [ ] ELB/ALB 삭제 (생성했다면)
- [ ] RDS 삭제 (생성했다면)
- [ ] Security Group 정리
- [ ] Key Pair 보관 여부 점검 및 필요 시 삭제

### 과금 확인
- [ ] Billing Dashboard에서 과금 발생 항목 없음 확인
- [ ] 잔여 리소스 조회 완료

---

## 2. 정리 순서 권장안

1. EC2 인스턴스 종료
2. EBS 및 Elastic IP 해제
3. Internet Gateway 연결 해제 및 삭제
4. Subnet 및 Route Table 삭제
5. VPC 삭제
6. Billing Dashboard 확인

이 순서를 지키는 이유는 의존성이 높은 리소스를 먼저 정리해 안전하게 전체 구조를 정리하기 위해서입니다.

---

## 3. 최종 확인 문구

아래 문구를 기준으로 정리 완료 여부를 기록할 수 있습니다.

> 실습 종료 후 모든 리소스를 정리하였으며, EC2, EBS, Elastic IP, Internet Gateway, VPC 삭제 상태를 확인했고 과금 항목이 남지 않았음을 확인하였다.

---

## 4. 체크리스트 기록 예시

- EC2: 종료 완료
- EBS: 삭제 완료
- Elastic IP: Release 완료
- Internet Gateway: Detach & Delete 완료
- VPC: 삭제 완료
- Billing: 과금 없음 확인

