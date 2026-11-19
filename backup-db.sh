#!/bin/bash
set -euo pipefail

BACKUP_DIR="$HOME/the-wall/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/walldb-$TIMESTAMP.sql"

mkdir -p "$BACKUP_DIR"

echo "Skapar backup av The Wall..."

oc exec deployment/wall-db -- \
  sh -c 'pg_dump -U "$POSTGRESQL_USER" -d "$POSTGRESQL_DATABASE"' \
  > "$BACKUP_FILE"

# Kontrollera att backupfilen innehåller en PostgreSQL-dump.
if [[ ! -s "$BACKUP_FILE" ]] || \
   ! grep -q "PostgreSQL database dump" "$BACKUP_FILE"; then
    echo "FEL: Backupen kunde inte verifieras."
    rm -f "$BACKUP_FILE"
    exit 1
fi

echo "Backup lyckades!"
ls -lh "$BACKUP_FILE"

