#!/bin/bash
set -e

# Configuration
CONTAINER="version10-db-1"
DB_USER="postgres"
DB_NAME="biosaas_v2"
BACKUP_DIR="../backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H%M")
BACKUP_FILE="backup_${TIMESTAMP}.sql.enc"
PASSPHRASE="PilotRescueKey2026"

# Ensure backup dir
mkdir -p $BACKUP_DIR

echo "🔒 Starting Encrypted Backup..."

# 1. Dump & Encrypt inside container (preserves piping context)
# We stream output to host file directly
docker exec -i $CONTAINER sh -c "pg_dump -U $DB_USER $DB_NAME | openssl enc -aes-256-cbc -salt -pass pass:$PASSPHRASE" > "$BACKUP_DIR/$BACKUP_FILE"

# 2. Verify
if [ -s "$BACKUP_DIR/$BACKUP_FILE" ]; then
    echo "✅ Backup Complete: $BACKUP_DIR/$BACKUP_FILE"
else
    echo "❌ Backup failed (empty file)"
    exit 1
fi
