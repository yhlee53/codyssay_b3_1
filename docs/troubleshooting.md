# 트러블슈팅 보고서

## 1. 문제 상황

실습 중 다음 두 가지 문제가 발생할 가능성이 높습니다.

1. EC2 인스턴스 생성 후 SSH 접속이 불가함
2. Public IP로 HTTP 접속이 되지 않음

이 문서는 최소 1건 이상의 현실적인 오류를 가정하고, 증상 → 가설 → 검증 → 조치 → 결과 → 재발 방지 흐름으로 정리한 보고서입니다.

---

## 2. 사례 1: SSH 접속 불가

### 증상
- EC2 인스턴스는 생성되었지만 `ssh -i my-key.pem ubuntu@<Public IP>` 명령이 실패함
- 보통 “Permission denied (publickey)” 또는 “Connection timed out” 메시지 발생

### 원인 가설
- Security Group에서 22/TCP가 본인 IP가 아닌 0.0.0.0/0 또는 잘못된 범위로 열려 있지 않음
- 또는 인스턴스에 Key Pair가 올바르게 연결되지 않음

### 검증 방법
1. EC2 콘솔에서 Security Group 규칙 확인
2. EC2 인스턴스 상태와 네트워크 상태 확인
3. Key Pair 이름이 실제 키와 일치하는지 점검
4. `ssh -vvv` 명령으로 상세 로그 확인

### 조치 내용
- Security Group 인바운드 규칙에서 22/TCP를 본인 IP 기반으로 재설정
- 필요한 경우 `chmod 400 my-key.pem` 후 다시 연결

### 결과
- SSH 접속 성공
- 인스턴스 내부에서 `whoami` 또는 `uname -a` 명령 확인 가능

### 재발 방지
- 실습 전 체크리스트에 “SSH 소스 제한 확인” 항목 추가
- 보안 그룹 규칙을 배포 전후에 다시 검토하는 습관 형성

---

## 3. 사례 2: 외부 HTTP 접속 실패

### 증상
- 브라우저 또는 `curl http://<Public IP>` 요청 시 연결 실패 또는 timeout 발생
- `curl -I http://<Public IP>` 명령이 실패함

### 원인 가설
- Internet Gateway가 VPC에 연결되지 않았거나 Route Table에 기본 경로가 없을 수 있음
- Security Group에서 80/TCP가 허용되지 않았음
- EC2 내부에서 Nginx가 실행 중이지 않음

### 검증 방법
1. VPC의 Route Table 확인
2. Internet Gateway 연결 상태 점검
3. Security Group 인바운드 규칙 확인
4. 인스턴스 내부에서 `sudo systemctl status nginx` 확인
5. `curl -i http://localhost` 로 로컬 검증

### 조치 내용
- Route Table에 0.0.0.0/0 → Internet Gateway 경로 추가
- Security Group에 80/TCP 0.0.0.0/0 규칙 추가
- Nginx가 설치되어 있지 않으면 `sudo apt install nginx -y` 후 실행

### 결과
- Public IP에 대한 HTTP 요청이 200 OK 응답을 반환
- `curl -i http://localhost` 와 외부 호출 모두 정상 동작

### 재발 방지
- 배포 전 네트워크 흐름 체크리스트 작성
  - IGW 연결 여부
  - 라우팅 테이블 기본 경로
  - Security Group 허용 포트
  - Nginx 상태 확인

---

## 4. 추가로 확인해야 할 운영 포인트

- `ss -tulpn | grep :80` 또는 `ss -tulpn | grep :22` 로 포트 상태 점검
- `journalctl -u nginx` 또는 `/var/log/nginx/error.log` 로 에러 로그 확인
- `tcpdump` 또는 VPC Flow Logs를 통해 트래픽 경로 검증 가능

---

## 5. 결론

클라우드 환경에서는 단순히 서버를 띄우는 것만으로는 서비스가 외부에서 동작하지 않습니다. 실제로는 네트워크 경로, 보안 정책, 인스턴스 내부 서비스 상태를 함께 검증해야 합니다.

이 실습은 인프라 오류를 발생시켜 원인을 분석하고, 로그와 구성 상태를 근거로 해결하는 과정을 학습하는 데 초점이 있습니다. 이런 능력은 실제 운영 환경에서 매우 중요합니다.
