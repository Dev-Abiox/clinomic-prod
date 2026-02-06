$ErrorActionPreference = "Stop"

# Configuration
$ContainerName = "version10-db-1"
$DbUser = "postgres"
$DbName = "biosaas_v2"
$BackupDir = "..\backups"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$BackupFile = "$BackupDir\backup_$Timestamp.sql.enc"
$Passphrase = "PilotRescueKey2026"

# Ensure backup directory exists
if (!(Test-Path -Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

Write-Host "🔒 Starting Encrypted Backup..." -ForegroundColor Cyan

try {
    # PowerShell piping of binary data from Docker stdout is tricky (encoding issues).
    # Safer approach: Run command in container to write to /tmp, then docker cp.
    
    # 1. Dump & Encrypt to Container /tmp
    docker exec $ContainerName sh -c "pg_dump -U $DbUser $DbName | openssl enc -aes-256-cbc -salt -pass pass:$Passphrase -out /tmp/temp_backup.enc"
    
    # 2. CP to Host
    docker cp "$($ContainerName):/tmp/temp_backup.enc" $BackupFile
    
    # 3. Cleanup Container Map
    docker exec $ContainerName rm /tmp/temp_backup.enc

    if ((Get-Item $BackupFile).Length -gt 0) {
        Write-Host "✅ Backup Successful!" -ForegroundColor Green
        Write-Host "📂 Saved to: $BackupFile" -ForegroundColor Gray
    }
    else {
        Write-Error "❌ Backup file created but is empty."
    }
}
catch {
    Write-Error "❌ Backup Failed: $_"
    exit 1
}
