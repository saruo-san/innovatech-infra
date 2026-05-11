#!/bin/bash
set -e

# Cloud-init / user-data script for Ubuntu 22.04 to install Docker and prepare deploy script
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add default ubuntu user to docker group (if exists)
if id "ubuntu" &>/dev/null; then
  usermod -aG docker ubuntu || true
fi

systemctl enable --now docker

mkdir -p /opt/deploy
chown ubuntu:ubuntu /opt/deploy || true

cat > /opt/deploy/deploy-ec2.sh <<'EOF'
#!/bin/bash
set -e
# deploy-ec2.sh (runs on EC2) - expects env vars: DOCKERHUB_USER DOCKERHUB_TOKEN POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB

if [ -n "$DOCKERHUB_USER" ] && [ -n "$DOCKERHUB_TOKEN" ]; then
  echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USER" --password-stdin || true
fi

docker volume create backend_pgdata || true

docker pull ${DOCKERHUB_USER}/innovatech-backend:latest || true
docker pull ${DOCKERHUB_USER}/innovatech-frontend:latest || true

docker rm -f backend || true
docker rm -f frontend || true

docker run -d --name postgres --restart unless-stopped -e POSTGRES_USER="${POSTGRES_USER:-postgres}" -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-example}" -e POSTGRES_DB="${POSTGRES_DB:-appdb}" -v backend_pgdata:/var/lib/postgresql/data -p 5432:5432 postgres:15-alpine || true

docker run -d --name backend --restart unless-stopped -p 3000:3000 --link postgres:postgres -e DATABASE_HOST=postgres -e DATABASE_USER="${POSTGRES_USER:-postgres}" -e DATABASE_PASSWORD="${POSTGRES_PASSWORD:-example}" -e DATABASE_DB="${POSTGRES_DB:-appdb}" ${DOCKERHUB_USER}/innovatech-backend:latest

docker run -d --name frontend --restart unless-stopped -p 80:8080 ${DOCKERHUB_USER}/innovatech-frontend:latest
EOF

chmod +x /opt/deploy/deploy-ec2.sh
chown ubuntu:ubuntu /opt/deploy/deploy-ec2.sh || true

echo "# deploy prepared at /opt/deploy/deploy-ec2.sh"
