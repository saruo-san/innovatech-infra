#!/bin/bash
set -e
# Script to run on EC2 (or upload to EC2) to pull images and start containers
# Usage: sudo DOCKERHUB_USER=... DOCKERHUB_TOKEN=... POSTGRES_USER=... POSTGRES_PASSWORD=... POSTGRES_DB=... /path/to/deploy-ec2.sh

DOCKERHUB_USER="${DOCKERHUB_USER:-}"
DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN:-}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-example}"
POSTGRES_DB="${POSTGRES_DB:-appdb}"

if [ -n "$DOCKERHUB_USER" ] && [ -n "$DOCKERHUB_TOKEN" ]; then
  echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USER" --password-stdin || true
fi

docker volume create backend_pgdata || true

docker pull "${DOCKERHUB_USER}/innovatech-backend:latest" || true
docker pull "${DOCKERHUB_USER}/innovatech-frontend:latest" || true

docker rm -f backend || true
docker rm -f frontend || true

docker run -d --name postgres --restart unless-stopped -e POSTGRES_USER="${POSTGRES_USER}" -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" -e POSTGRES_DB="${POSTGRES_DB}" -v backend_pgdata:/var/lib/postgresql/data -p 5432:5432 postgres:15-alpine || true

docker run -d --name backend --restart unless-stopped -p 3000:3000 --link postgres:postgres -e DATABASE_HOST=postgres -e DATABASE_USER="${POSTGRES_USER}" -e DATABASE_PASSWORD="${POSTGRES_PASSWORD}" -e DATABASE_DB="${POSTGRES_DB}" "${DOCKERHUB_USER}/innovatech-backend:latest"

docker run -d --name frontend --restart unless-stopped -p 80:8080 "${DOCKERHUB_USER}/innovatech-frontend:latest"
