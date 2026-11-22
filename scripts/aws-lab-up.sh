#!/usr/bin/env zsh
set -euo pipefail

export AWS_PAGER=""
export AWS_DEFAULT_REGION="ap-northeast-2"

# AWS CLI 위치가 PATH에 없다면 먼저 아래 경로를 사용합니다.
# export PATH="$PWD/.aws-cli-bin:$PATH"

# 로컬 AWS CLI가 PATH에 없으면 현재 폴더의 CLI를 사용합니다.
if ! command -v aws >/dev/null 2>&1 && [[ -x "$PWD/.aws-cli-bin/aws" ]]; then
  export PATH="$PWD/.aws-cli-bin:$PATH"
fi

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "오류: AWS 자격 증명이 유효하지 않습니다." >&2
  echo "aws configure 또는 aws login을 실행한 뒤 다시 시도하세요." >&2
  exit 1
fi

MY_IP="$(curl -fsS https://checkip.amazonaws.com)/32"
STATE_FILE="$PWD/.aws-lab.env"
KEY_NAME="cloud-lab-key"
PEM_FILE="$PWD/cloud-lab-key.pem"

# 기존 상태 파일이 있으면 중복 생성을 방지합니다.
if [[ -f "$STATE_FILE" ]]; then
  echo "오류: $STATE_FILE이 이미 있습니다. 삭제 스크립트를 실행하거나 기존 파일을 확인하세요." >&2
  exit 1
fi

if ! VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=lab-vpc}]' \
  --query 'Vpc.VpcId' --output text 2>&1); then
  echo "오류: VPC를 생성할 권한이 없거나 요청이 거부되었습니다." >&2
  echo "IAM 사용자 cloud-lab-user에 docs/aws-lab-iam-policy.json 정책을 연결하세요." >&2
  echo "필요 권한: ec2:CreateVpc, ec2:CreateSubnet, ec2:CreateInternetGateway, ec2:CreateRouteTable, ec2:CreateSecurityGroup, ec2:RunInstances, ssm:GetParameter" >&2
  exit 1
fi

aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support '{"Value":true}'
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'

SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ap-northeast-2a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-subnet}]' \
  --query 'Subnet.SubnetId' --output text)

aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_ID" --map-public-ip-on-launch

IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=lab-igw}]' \
  --query 'InternetGateway.InternetGatewayId' --output text)

aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"

RTB_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=public-route-table}]' \
  --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route \
  --route-table-id "$RTB_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID"

aws ec2 associate-route-table --route-table-id "$RTB_ID" --subnet-id "$SUBNET_ID"

SG_ID=$(aws ec2 create-security-group \
  --group-name lab-sg \
  --description 'Public web access only' \
  --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=lab-sg}]' \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$MY_IP"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0

if aws ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; then
  echo "경고: 키 페어 $KEY_NAME이 이미 존재합니다. 기존 프라이빗 키가 필요합니다." >&2
else
  aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$PEM_FILE"
  chmod 400 "$PEM_FILE"
fi

AMI_ID=$(aws ssm get-parameter \
  --name '/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64' \
  --query 'Parameter.Value' --output text)

USER_DATA_FILE="$PWD/.aws-lab-user-data.sh"
cat > "$USER_DATA_FILE" <<'USER_DATA'
#!/bin/bash
set -e

dnf update -y
dnf install nginx -y
systemctl enable --now nginx

cat > /etc/nginx/conf.d/health.conf <<'NGINX'
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
NGINX

nginx -t
systemctl reload nginx
USER_DATA

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --subnet-id "$SUBNET_ID" \
  --associate-public-ip-address \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":8,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --user-data "file://$USER_DATA_FILE" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=web-server}]' \
  --query 'Instances[0].InstanceId' --output text)

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

cat > "$STATE_FILE" <<EOF
VPC_ID=$VPC_ID
SUBNET_ID=$SUBNET_ID
IGW_ID=$IGW_ID
RTB_ID=$RTB_ID
SG_ID=$SG_ID
INSTANCE_ID=$INSTANCE_ID
PUBLIC_IP=$PUBLIC_IP
KEY_NAME=$KEY_NAME
EOF

chmod 600 "$STATE_FILE"
rm -f "$USER_DATA_FILE"

printf '\n생성 완료\n'
printf 'VPC_ID=%s\nSUBNET_ID=%s\nIGW_ID=%s\nRTB_ID=%s\nSG_ID=%s\nINSTANCE_ID=%s\nPUBLIC_IP=%s\n' \
  "$VPC_ID" "$SUBNET_ID" "$IGW_ID" "$RTB_ID" "$SG_ID" "$INSTANCE_ID" "$PUBLIC_IP"
