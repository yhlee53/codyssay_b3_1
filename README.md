# AWS 클라우드 웹 서비스 배포 프로젝트

## 1. 프로젝트 개요

이 프로젝트는 EC2 인스턴스를 Public Subnet에 배치하고, VPC, Internet Gateway, Route Table, Security Group, IAM 정책을 구성하여 인터넷에 노출되는 웹 서비스를 안정적으로 운영하는 실습을 수행한 결과물입니다.

핵심 목표는 단순히 웹 애플리케이션을 실행하는 것이 아니라, 실제 클라우드 운영에서 필수적인 네트워크 격리, 최소 권한 보안, 외부 접근 경로 설계, 문제 해결 능력을 학습하는 것입니다.

- 리전: ap-northeast-2 (서울)
- 네트워크 구조: VPC + Public Subnet + Internet Gateway + Route Table
- 애플리케이션: Nginx 웹 서버
- 접근 방식: 외부 HTTP 요청을 Public EC2로 전달
- 보안 원칙: SSH는 본인 IP만 허용, HTTP는 80 포트만 공개
- IAM: 실습 작업에 필요한 최소 범위의 권한만 사용

---

## 2. 아키텍처 구성

### 2-1. 네트워크 설계

- VPC: 10.0.0.0/16
- Public Subnet: 10.0.1.0/24
- Internet Gateway: VPC에 연결
- Route Table: 0.0.0.0/0 -> Internet Gateway
- EC2 인스턴스: Public Subnet에 배치
- Security Group: 외부 접속 제어

### 2-2. 실행 흐름

사용자의 웹 브라우저 또는 외부 HTTP 요청이 다음 경로를 거쳐 EC2의 Nginx 서버로 도달합니다.

1. 인터넷에서 Public IP로 요청 전송
2. Internet Gateway가 VPC 내부로 트래픽 전달
3. Route Table의 기본 경로(0.0.0.0/0)로 Public Subnet으로 라우팅
4. EC2 인스턴스의 Security Group에서 80번 포트 허용 여부 검증
5. Nginx가 요청 처리 후 응답 반환

이 구조를 통해 단일 서버가 단순히 실행되는 것 이상으로, 네트워크 경계와 보안 정책이 실제 운영 환경에 가깝게 구현됩니다.

---

## 3. 구성 상세

### 3-1. VPC
VPC는 클라우드 네트워크를 논리적으로 분리하는 기본 단위입니다. 이 프로젝트에서는 하나의 VPC를 생성하여 서비스 범위를 명확하게 구분하고, 서브넷과 보안 정책을 적용하는 기준으로 사용했습니다.

### 3-2. Public Subnet
Public Subnet에는 외부 인터넷과 직접 통신이 필요한 인스턴스를 배치합니다. EC2 웹 서버는 이 서브넷에 올려 Public IP를 통해 외부 요청을 받을 수 있도록 구성했습니다.

### 3-3. Internet Gateway
Internet Gateway는 VPC와 인터넷 사이의 게이트웨이 역할을 수행합니다. 이 리소스가 연결되어 있어야 외부에서 VPC 내부로 들어오는 트래픽이 허용됩니다.

### 3-4. Route Table
Route Table에서 0.0.0.0/0 → Internet Gateway 경로를 설정해 인터넷 트래픽이 VPC 내부로 전달되도록 구성했습니다. 이것이 있어야 Public Subnet 내 인스턴스가 외부 네트워크와 통신할 수 있습니다.

### 3-5. EC2 인스턴스
- 인스턴스 유형: t3.micro 또는 t2.micro (프리티어/실습용)
- OS: Ubuntu 22.04 LTS
- 포트 공개: 80/TCP
- SSH: 본인 IP에서만 허용
- 웹 서버: Nginx 설치 및 실행

### 3-6. Security Group
보안 그룹은 EC2에 대한 네트워크 접근 제어를 담당합니다.

- Inbound 80/TCP: 0.0.0.0/0 허용
- Inbound 22/TCP: 본인 IP 또는 지정된 관리 IP 대역만 허용
- 전체 포트 허용(0-65535, 0.0.0.0/0)은 사용하지 않았으며, 최소한의 포트만 열어 운영 안전성을 확보했습니다.

이렇게 구성함으로써 불필요한 포트 노출을 줄이고, 보안상 취약한 상태를 피할 수 있습니다.

### 3-7. IAM 최소 권한 원칙
실습에 사용된 IAM 사용자 또는 역할은 EC2/VPC/SG 생성 및 조회에 필요한 범위만 허용하도록 제한했습니다.

- 허용 대상: EC2 생성/조회, VPC 생성/조회, Subnet, Route Table, Security Group, Tag, Attachment 관련 작업
- 비허용 대상: 실습과 무관한 S3, RDS, 관리자권한 등
- 관리자 권한(AdministratorAccess) 사용하지 않음

최소 권한 원칙은 실수로 전체 권한을 부여할 경우 발생하는 인프라 오남용, 보안 사고, 비용 낭비를 방지하기 위한 필수 원칙입니다.

---

## 4. 배포 및 실행 절차

아래는 AWS 콘솔 기준으로 실제로 서비스를 배포하는 절차를 정리한 상세 가이드입니다. CLI 예시도 함께 포함해 실습을 반복할 때 사용할 수 있도록 구성했습니다.

### 4-1. 사전 준비

1. AWS 콘솔 접속
   - 루트 계정 대신 별도 IAM 사용자로 로그인
   - 리전 선택: `Asia Pacific (Seoul) ap-northeast-2`
2. 실습용 IAM 사용자 생성
   - IAM > Users > Create user
   - 사용자 이름 예시: `cloud-lab-user`
   - AWS Management Console access 및 Programmatic access 선택
   - 권한은 최소 범위로 부여
     - 예: EC2 FullAccess, VPC FullAccess, IAMReadOnlyAccess 등
     - 실습 필요가 아닌 `AdministratorAccess`는 부여하지 않음
3. Key Pair 생성
   - EC2 > Key pairs > Create key pair
   - 이름 예시: `cloud-lab-key`
   - `.pem` 파일을 로컬에 저장하고 권한 설정 적용

```bash
chmod 400 cloud-lab-key.pem
```

### 4-2. VPC 생성

AWS 콘솔 메뉴 경로:
- VPC > Your VPCs > Create VPC

설정 예시:
- Name tag: `lab-vpc`
- IPv4 CIDR block: `10.0.0.0/16`
- Tenancy: Default

생성 후 VPC ID를 기록합니다. vpc-0a082d99085060c21

### 4-3. Public Subnet 생성

AWS 콘솔 메뉴 경로:
- VPC > Subnets > Create subnet

설정 예시:
- VPC: `lab-vpc`
- Subnet name: `public-subnet`
- Availability Zone: `ap-northeast-2a`
- IPv4 CIDR: `10.0.1.0/24`

다음 항목을 확인합니다.
- 서브넷이 VPC에 연결되어 있는지
- CIDR 범위가 겹치지 않는지

### 4-4. Internet Gateway 생성 및 연결

AWS 콘솔 메뉴 경로:
- VPC > Internet gateways > Create internet gateway

설정 예시:
- Name tag: `lab-igw`

생성 후 다음 절차를 수행합니다.
1. 생성된 IGW 선택
2. Actions > Attach to VPC
3. 연결할 VPC 선택: `lab-vpc`

이 단계가 완료되어야 인터넷과 VPC 사이의 연결 경로가 활성화됩니다.

### 4-5. Route Table 생성 및 기본 경로 추가

AWS 콘솔 메뉴 경로:
- VPC > Route Tables > Create route table

설정 예시:
- Name: `public-route-table`
- VPC: `lab-vpc`

다음으로 Route 추가:
- Destination: `0.0.0.0/0`
- Target: Internet Gateway (`lab-igw`)

그리고 Public Subnet을 해당 Route Table에 연결합니다.
- Subnet associations > Edit subnet associations
- `public-subnet` 선택

추가로 확인해야 하는 핵심 점은 다음입니다.
- 0.0.0.0/0 경로가 존재하는지
- Public Subnet이 연결된 route table이 맞는지

### 4-6. Security Group 생성

AWS 콘솔 메뉴 경로:
- EC2 > Security Groups > Create security group

설정 예시:
- Name: `web-sg`
- Description: `Public web access only`
- VPC: `lab-vpc`

인바운드 규칙:
- HTTP: `80` / `0.0.0.0/0`
- SSH: `22` / 본인 IP 또는 지정된 관리망

주의 사항:
- `0.0.0.0/0` 전체 포트 허용 규칙은 추가하지 않음
- 운영용으로 SSH는 반드시 본인 IP로 제한

아웃바운드 규칙:
- 기본 설정인 `0.0.0.0/0` 허용으로 두는 것이 일반적

### 4-7. EC2 인스턴스 생성

AWS 콘솔 메뉴 경로:
- EC2 > Instances > Launch instance

설정 예시:
- Name: `web-server`
- Amazon Machine Image (AMI): Ubuntu Server LTS
- Instance type: `t3.micro` 또는 `t2.micro`
- Key pair: `cloud-lab-key`
- Network settings:
  - VPC: `lab-vpc`
  - Subnet: `public-subnet`
  - Auto-assign public IP: Enable
  - Security group: `web-sg`
- Storage: 8~10 GiB

생성 후 인스턴스 ID와 Public IPv4 주소를 기록합니다.
i-0905b4c5862cef000
54.206.116.166

### 4-8. EC2 접속 및 웹 서버 설치

SSH 접속 명령 예시:

```bash
ssh -i cloud-lab-key.pem ubuntu@<Public-IP>
```

인스턴스 내부에서 Nginx 설치:

```bash
sudo apt update
sudo apt install nginx -y
sudo systemctl enable --now nginx
```

로컬 검증:

```bash
curl -i http://localhost
```

정상 응답 예시:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0
```

### 4-9. 헬스 체크 엔드포인트 구성

Nginx에서 `/health` 경로를 정상 응답하도록 설정하면 외부 모니터링/검증이 쉬워집니다.

예시 설정:

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location / {
        return 200 'Welcome to nginx\n';
        add_header Content-Type text/plain;
    }

    location = /health {
        access_log off;
        add_header Content-Type text/plain;
        return 200 'OK\n';
    }
}
```

설정 반영:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

다음으로 로컬 검증:

```bash
curl -i http://localhost/health
```

응답 예시:

```text
HTTP/1.1 200 OK

OK
```

### 4-10. 외부 접속 검증

브라우저 또는 터미널에서 다음을 실행해 외부 접근이 가능한지 확인합니다.

```bash
curl -i http://<Public-IP>/health
```

예상 결과:

```text
HTTP/1.1 200 OK

OK
```

이 결과를 통해 인터넷에서 EC2의 Nginx가 정상적으로 응답하는 것을 확인할 수 있습니다.

### 4-11. CLI 명령 전체 예시

아래는 동일 작업을 AWS CLI로 수행할 때의 대표 예시입니다.

```bash
aws ec2 create-vpc --cidr-block 10.0.0.0/16
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 10.0.1.0/24 --availability-zone ap-northeast-2a
aws ec2 create-internet-gateway
aws ec2 attach-internet-gateway --vpc-id <VPC_ID> --internet-gateway-id <IGW_ID>
aws ec2 create-route-table --vpc-id <VPC_ID>
aws ec2 create-route --route-table-id <RTB_ID> --destination-cidr-block 0.0.0.0/0 --gateway-id <IGW_ID>
aws ec2 run-instances \
  --image-id ami-xxxxxxxxxxxxxxxxx \
  --count 1 \
  --instance-type t3.micro \
  --key-name cloud-lab-key \
  --security-group-ids <SG_ID> \
  --subnet-id <SUBNET_ID>
```

### 4-12. 체크 포인트

배포가 완료되었는지 아래 항목을 모두 확인합니다.

- [ ] VPC 생성 완료
- [ ] Public Subnet 생성 완료
- [ ] Internet Gateway 연결 완료
- [ ] Route Table에 0.0.0.0/0 경로 존재
- [ ] EC2 인스턴스 생성 완료
- [ ] Public IP가 할당됨
- [ ] Security Group의 HTTP/SSH 규칙 적절히 설정됨
- [ ] Nginx 실행 상태 확인됨
- [ ] localhost 및 외부 URL 모두 응답 200 확인됨

---

## 5. 외부 접속 검증

아래 방식 중 B를 선택하여 외부 접근 가능 여부를 검증했습니다.

### 선택 방식: B. GET http://<퍼블릭IP>/health

- URL: http://<Public IP>/health
- 응답 상태: 200 OK
- 응답 본문: OK

예시:
```bash
curl -i http://<Public IP>/health
```

출력 예시:
```text
HTTP/1.1 200 OK
Content-Type: text/plain

OK
```

외부 접속 결과 스크린샷은 `docs/external-access-proof.png` 파일에 저장했습니다.

---

## 6. 헬스 체크 구성 예시

Nginx 설정 예시입니다.

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location / {
        return 200 'Welcome to nginx\n';
        add_header Content-Type text/plain;
    }

    location = /health {
        access_log off;
        add_header Content-Type text/plain;
        return 200 'OK\n';
    }
}
```

이 설정으로 외부 요청이 정상적으로 전달되고 있음을 확인할 수 있습니다.

---

## 7. 트러블슈팅 사례

실습 중 발생할 수 있는 대표적인 문제는 다음과 같습니다.

### 사례 1: SSH 접속 실패
- 증상: 인스턴스 생성 후 SSH 접속이 불가
- 가설: 보안 그룹 인바운드 규칙으로 본인 IP가 아닌 범위가 허용되었거나, 22 포트가 차단됨
- 검증: Security Group 규칙 및 인스턴스 상태 확인
- 조치: 22/TCP를 본인 IP로만 허용하도록 다시 설정
- 결과: SSH 접속 정상화

### 사례 2: 외부에서 HTTP 접근이 실패함
- 증상: Public IP로 연결 시 응답이 없음
- 가설: Route Table 경로 또는 Internet Gateway 연결 누락, 또는 Security Group 80 포트 차단
- 검증: 라우팅 테이블, IGW 연결 상태, SG 인바운드 규칙 확인
- 조치: 기본 경로 추가 및 80 포트 허용
- 결과: 웹 서버 응답 정상화

상세 내용은 `docs/troubleshooting.md` 파일에 정리했습니다.

---

## 8. 보안 및 운영 원칙

### 8-1. 최소 권한 원칙
- 필요하지 않은 권한은 부여하지 않음
- 실습 범위를 벗어난 서비스 권한은 사용하지 않음
- 한 번에 관리자 권한을 부여하지 않음

### 8-2. 네트워크 최소 공개 원칙
- 공개 포트는 HTTP 80만 허용
- SSH는 본인 IP만 허용
- 전체 포트 허용 규칙은 사용하지 않음

### 8-3. 과금 방지
- 실습 종료 후 생성한 리소스를 모두 정리
- EC2, EIP, VPC, IGW, EBS를 삭제 체크
- Billing Dashboard에서 과금 항목이 남지 않는지 최종 검증

---

## 9. 리소스 정리 체크리스트

아래 항목은 실습 종료 후 반드시 확인해야 합니다.

- [ ] EC2 인스턴스 종료
- [ ] EBS 볼륨 삭제
- [ ] Elastic IP 해제 및 Release
- [ ] Internet Gateway 연결 해제 및 삭제
- [ ] Route Table 정리
- [ ] Subnet 삭제
- [ ] VPC 삭제
- [ ] Security Group 정리
- [ ] Billing Dashboard에서 과금 항목 없음 확인

상세 사항은 `docs/cleanup-checklist.md` 파일에 정리했습니다.

---

## 10. 결과물 목록

- `docs/architecture.png` : VPC, Subnet, IGW, Route Table, EC2 구조 다이어그램
- `docs/external-access-proof.png` : 외부 응답 확인 스크린샷
- `docs/troubleshooting.md` : 오류 해결 보고서
- `docs/cleanup-checklist.md` : 정리 체크리스트

---

## 11. 정리

이번 프로젝트는 AWS 클라우드에서 네트워크와 보안을 실제로 구성해보며, 단순한 ‘웹 서비스 올리기’ 수준을 넘어 ‘실제 운영 환경을 구성하는 사고’를 익히는 과정입니다.

특히, 다음 세 가지가 가장 중요합니다.

1. VPC와 Subnet을 이용한 네트워크 구획화
2. Internet Gateway와 Route Table을 통한 외부 연결 구성
3. Security Group과 IAM 최소 권한 원칙을 적용한 보안 설계

이 과정을 통해 클라우드 환경에서 발생할 수 있는 연결 문제와 보안 문제를 로그와 증상을 근거로 분석하고 해결하는 역량을 키울 수 있습니다.

---

## 12. 참고

본 저장소는 실습 문서 정리용 결과물로 구성되며, 실제 AWS 실제 계정과 연결되어 있지 않습니다. 실제 운영 환경에서는 AWS 콘솔에서 값과 리소스 상태를 직접 확인하고, 배포/정리 절차를 반복하면서 안전하게 진행하는 것이 중요합니다.
