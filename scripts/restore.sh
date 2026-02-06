#!/bin/bash
set -e

BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: ./restore.sh <path_to_backup.sql.enc>"
    exit 1
fi

CONTAINER="version10-db-1"
DB_USER="postgres"
DB_NAME="biosaas_v2"
PASSPHRASE="PilotRescueKey2026"

echo "⚠️  DANGER: This will WIPE the '$DB_NAME' database and restore from $BACKUP_FILE"
read -p "Type 'YES' to confirm: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo "🔓 Restoring..."

# 1. Reset Schema
docker exec $CONTAINER psql -U $DB_USER -d $DB_NAME -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

# 2. Decrypt & Import
# Convert host path to relative if needed or just cat it
cat "$BACKUP_FILE" | docker exec -i $CONTAINER sh -c "openssl enc -d -aes-256-cbc -pass pass:$PASSPHRASE | psql -U $DB_USER $DB_NAME"

echo "✅ Restore Complete."
