#!/usr/bin/env zsh
set -euo pipefail

export AWS_PAGER=""
export AWS_DEFAULT_REGION="ap-northeast-2"

STATE_FILE="$PWD/.aws-lab.env"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "오류: $STATE_FILE이 없습니다. 먼저 생성 스크립트를 실행하세요." >&2
  exit 1
fi

source "$STATE_FILE"

aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" >/dev/null
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"

ASSOCIATION_IDS=$(aws ec2 describe-route-tables \
  --route-table-ids "$RTB_ID" \
  --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' \
  --output text)

for ASSOCIATION_ID in ${(z)ASSOCIATION_IDS}; do
  if [[ -n "$ASSOCIATION_ID" ]]; then
    aws ec2 disassociate-route-table --association-id "$ASSOCIATION_ID" >/dev/null
  fi
done

aws ec2 delete-security-group --group-id "$SG_ID"
aws ec2 delete-subnet --subnet-id "$SUBNET_ID"
aws ec2 delete-route-table --route-table-id "$RTB_ID"

aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID"
aws ec2 delete-vpc --vpc-id "$VPC_ID"
aws ec2 delete-key-pair --key-name "$KEY_NAME"

rm -f "$STATE_FILE" "$PWD/cloud-lab-key.pem" "$PWD/.aws-lab-user-data.sh"

echo "생성된 실습 리소스를 삭제했습니다."
