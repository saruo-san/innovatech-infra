#!/bin/bash
set -e
# Local helper: copia y ejecuta el script de despliegue en la EC2 vía SSH
# Usage:
#   ./scripts/deploy_to_ec2_local.sh ubuntu@1.2.3.4 ~/.ssh/eval2_key user_dockerhub token_postgres_user postgres_pass appdb

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <ec2-user@host> <ssh-key-path> <dockerhub_user> [dockerhub_token] [postgres_user] [postgres_password] [postgres_db]"
  exit 1
fi

HOST="$1"
KEY="$2"
DH_USER="$3"
DH_TOKEN="${4:-}"
PG_USER="${5:-postgres}"
PG_PASS="${6:-example}"
PG_DB="${7:-appdb}"

echo "Uploading deploy script to ${HOST}..."
scp -i "$KEY" scripts/ec2/deploy-ec2.sh "$HOST:/tmp/deploy-ec2.sh"

echo "Running deploy script on ${HOST} (sudo)..."
ssh -i "$KEY" "$HOST" "chmod +x /tmp/deploy-ec2.sh && sudo DOCKERHUB_USER='$DH_USER' DOCKERHUB_TOKEN='$DH_TOKEN' POSTGRES_USER='$PG_USER' POSTGRES_PASSWORD='$PG_PASS' POSTGRES_DB='$PG_DB' /tmp/deploy-ec2.sh"
