#!/usr/bin/env bash
# Deploys a ghcr.io image built by .github/workflows/build-amd64-image.yml.
# Lives on the VPS as /opt/chatwood/deploy.sh. Usage: ./deploy.sh 4.15.1-<short sha>
set -euo pipefail

TAG="$1"
IMAGE="ghcr.io/khaledert15-creator/chatwood:${TAG}"
COMPOSE=/opt/chatwood/docker-compose.chatwood.yml
BACKUP="${COMPOSE}.before-${TAG}"

docker pull "$IMAGE"
CURRENT=$(grep -m1 -oE 'image: [^ ]*chatwood[^ ]*' "$COMPOSE" | cut -d' ' -f2)
cp "$COMPOSE" "$BACKUP"
sed -i "s#image: ${CURRENT}#image: ${IMAGE}#" "$COMPOSE"

# The image entrypoint does not run migrations, so run them before switching containers.
docker compose -f "$COMPOSE" run --rm --no-deps rails bundle exec rails db:migrate
docker compose -f "$COMPOSE" up -d --no-deps rails sidekiq

echo "Deployed ${IMAGE} (was ${CURRENT})."
echo "Roll back: cp ${BACKUP} ${COMPOSE} && docker compose -f ${COMPOSE} up -d --no-deps rails sidekiq"
