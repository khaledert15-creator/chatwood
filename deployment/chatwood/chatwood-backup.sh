#!/usr/bin/env bash
# Backs up the Chatwood database (every run) and uploaded files (once a day) to the same restic
# repository as /root/backup/system-backup.sh. Lives on the VPS as /root/backup/chatwood-backup.sh,
# scheduled by /etc/cron.d/chatwood-backup. Run with FULL=1 to include uploaded files now.
set -euo pipefail
umask 077

BACKUP_HOME=/root/backup
STAGE="$BACKUP_HOME/stage-chatwood"

exec 8>"$BACKUP_HOME/.chatwood.lock"
flock -n 8 || { echo "$(date -u +%FT%TZ) another chatwood backup is still running, skipped"; exit 0; }

set -a; . "$BACKUP_HOME/restic.env"; set +a

mkdir -p "$STAGE"
docker exec chatwood-postgres-1 pg_dump -U postgres -Fc chatwoot > "$STAGE/chatwoot.dump.tmp"
mv -f "$STAGE/chatwoot.dump.tmp" "$STAGE/chatwoot.dump"
restic backup "$STAGE/chatwoot.dump" --host chatwood --tag chatwood-db --quiet
rm -f "$STAGE/chatwoot.dump"

if [ "$(date -u +%H)" = "02" ] || [ "${FULL:-}" = "1" ]; then
  storage=$(docker inspect chatwood-rails-1 --format '{{range .Mounts}}{{if eq .Destination "/app/storage"}}{{.Source}}{{end}}{{end}}')
  restic backup "$storage" --host chatwood --tag chatwood-storage --quiet
  restic forget --host chatwood --tag chatwood-db --keep-hourly 24 --keep-daily 30 --keep-weekly 12 --keep-monthly 12 --prune --quiet
  restic forget --host chatwood --tag chatwood-storage --keep-daily 7 --keep-weekly 8 --prune --quiet
fi

echo "$(date -u +%FT%TZ) chatwood backup ok"
