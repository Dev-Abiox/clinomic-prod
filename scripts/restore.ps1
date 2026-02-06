$ErrorActionPreference = "Stop"

param (
    [Parameter(Mandatory = $true)]
    [string]$BackupFile
)

# Configuration
$ContainerName = "version10-db-1"
$DbUser = "postgres"
$DbName = "biosaas_v2"
$Passphrase = "PilotRescueKey2026"

# Validation
if (!(Test-Path -Path $BackupFile)) {
    Write-Error "❌ File not found: $BackupFile"
    exit 1
}

Write-Host "⚠️  DANGER ZONE ⚠️" -ForegroundColor Red
Write-Host "You are about to RESTORE from: $BackupFile" -ForegroundColor Yellow
Write-Host "This will DELETE ALL DATA." -ForegroundColor Yellow
$confirm = Read-Host "Type 'YES' to confirm"

if ($confirm -ne "YES") {
    Write-Host "Restore cancelled."
    exit 0
}

Write-Host "🔓 Restoring..." -ForegroundColor Cyan

try {
    # 1. Reset Schema
    Write-Host "   > Cleaning schema..."
    docker exec $ContainerName psql -U $DbUser -d $DbName -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
    
    # 2. Copy Backup to Container
    Write-Host "   > Uploading backup..."
    docker cp $BackupFile "$($ContainerName):/tmp/restore.enc"
    
    # 3. Decrypt & Import
    Write-Host "   > Decrypting and Importing..."
    docker exec $ContainerName sh -c "openssl enc -d -aes-256-cbc -pass pass:$Passphrase -in /tmp/restore.enc | psql -U $DbUser $DbName"
    
    # Cleanup
    docker exec $ContainerName rm /tmp/restore.enc
    
    Write-Host "✅ Restore Complete!" -ForegroundColor Green
    
}
catch {
    Write-Error "❌ Restore Failed: $_"
    exit 1
}
