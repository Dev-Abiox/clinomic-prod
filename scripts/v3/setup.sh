#!/bin/bash
# Initial Setup for Clinomic v3 Platform
# Usage: ./scripts/v3/setup.sh
#
# Sets up the complete v3 environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_ROOT"

echo "=========================================="
echo "Clinomic Platform v3 - Setup"
echo "=========================================="

# Step 1: Check prerequisites
echo ""
echo "[1/6] Checking prerequisites..."

# Docker
if command -v docker &> /dev/null; then
    echo "  Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
else
    echo "  Docker: NOT FOUND"
    echo "  Please install Docker from https://www.docker.com/get-started"
    exit 1
fi

# Docker Compose
if docker compose version &> /dev/null; then
    echo "  Docker Compose: $(docker compose version --short)"
else
    echo "  Docker Compose: NOT FOUND"
    exit 1
fi

# Node.js (for frontend)
if command -v node &> /dev/null; then
    echo "  Node.js: $(node --version)"
else
    echo "  Node.js: NOT FOUND (needed for frontend)"
fi

# Step 2: Backend v3 environment
echo ""
echo "[2/6] Setting up backend v3 environment..."

cd "$PROJECT_ROOT/backend_v3"

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env

        # Generate secure keys using Python
        python3 << 'PYTHON'
import secrets
import os

# Generate keys
django_key = secrets.token_urlsafe(50)
jwt_key = secrets.token_urlsafe(32)
refresh_key = secrets.token_urlsafe(32)
audit_key = secrets.token_urlsafe(32)

# Generate Fernet key
try:
    from cryptography.fernet import Fernet
    fernet_key = Fernet.generate_key().decode()
except ImportError:
    fernet_key = "GENERATE_WITH_FERNET"

# Read .env
with open('.env', 'r') as f:
    content = f.read()

# Replace placeholders
replacements = {
    'DJANGO_SECRET_KEY=': f'DJANGO_SECRET_KEY={django_key}',
    'JWT_SECRET_KEY=': f'JWT_SECRET_KEY={jwt_key}',
    'JWT_REFRESH_SECRET_KEY=': f'JWT_REFRESH_SECRET_KEY={refresh_key}',
    'MASTER_ENCRYPTION_KEY=': f'MASTER_ENCRYPTION_KEY={fernet_key}',
    'AUDIT_SIGNING_KEY=': f'AUDIT_SIGNING_KEY={audit_key}',
}

for old, new in replacements.items():
    if old in content and content.split(old)[1].split('\n')[0].strip() == '':
        content = content.replace(old + '\n', new + '\n')

with open('.env', 'w') as f:
    f.write(content)

print('  Keys generated and saved to .env')
PYTHON
    else
        echo "  ERROR: backend_v3/.env.example not found"
        exit 1
    fi
else
    echo "  .env already exists"
fi

cd "$PROJECT_ROOT"

# Step 3: Frontend environment
echo ""
echo "[3/6] Setting up frontend environment..."

cd "$PROJECT_ROOT/frontend"

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "  Created frontend .env"
    else
        # Create basic frontend .env
        echo "VITE_API_URL=http://localhost:8000" > .env
        echo "  Created frontend .env with default API URL"
    fi
else
    echo "  .env already exists"
fi

cd "$PROJECT_ROOT"

# Step 4: Create ML models directory
echo ""
echo "[4/6] Setting up ML models directory..."

mkdir -p backend_v3/ml/models

if [ "$(ls -A backend_v3/ml/models 2>/dev/null)" ]; then
    echo "  ML models found"
else
    echo "  ML models directory created"
    echo "  WARNING: Place model files in backend_v3/ml/models/"
fi

# Step 5: Build Docker images
echo ""
echo "[5/6] Building Docker images..."

docker compose -f docker-compose.v3.yml build

echo "  Docker images built"

# Step 6: Initialize database
echo ""
echo "[6/6] Initializing database..."

# Start database
docker compose -f docker-compose.v3.yml up -d db
echo "  Waiting for database to be ready..."
sleep 5

# Run migrations and seed
docker compose -f docker-compose.v3.yml run --rm backend_v3_dev python manage.py migrate_schemas --shared
docker compose -f docker-compose.v3.yml run --rm backend_v3_dev python manage.py seed_demo_data

# Stop database
docker compose -f docker-compose.v3.yml down

echo "  Database initialized with demo data"

# Summary
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "To start the platform:"
echo ""
echo "  Development (with hot reload):"
echo "    ./scripts/v3/start.sh dev"
echo ""
echo "  Production:"
echo "    ./scripts/v3/start.sh prod"
echo ""
echo "  Full stack (with frontend):"
echo "    ./scripts/v3/start.sh full"
echo ""
echo "URLs:"
echo "  Backend API: http://localhost:8000"
echo "  Frontend:    http://localhost:3000"
echo ""
echo "Demo credentials:"
echo "  admin_demo / Demo@2024"
echo "  lab_demo / Demo@2024"
echo "  doctor_demo / Demo@2024"
echo ""
