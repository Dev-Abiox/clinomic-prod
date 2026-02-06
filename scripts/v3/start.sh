#!/bin/bash
# Start Clinomic v3 Platform (Full Stack)
# Usage: ./scripts/v3/start.sh [dev|prod]
#
# Starts PostgreSQL, Backend v3, and optionally Frontend

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_ROOT"

MODE=${1:-dev}

echo "=========================================="
echo "Clinomic Platform v3"
echo "Mode: $MODE"
echo "=========================================="

# Check for docker
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is required but not installed."
    echo "Install Docker from https://www.docker.com/get-started"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "ERROR: Docker daemon is not running."
    echo "Please start Docker and try again."
    exit 1
fi

case $MODE in
    dev)
        echo ""
        echo "Starting development environment..."
        echo ""
        echo "Services:"
        echo "  - PostgreSQL: localhost:5433"
        echo "  - Backend v3: localhost:8000"
        echo ""
        docker compose -f docker-compose.v3.yml --profile dev up --build
        ;;

    prod)
        echo ""
        echo "Starting production environment..."
        echo ""
        docker compose -f docker-compose.v3.yml up -d backend_v3
        echo ""
        echo "Services started in background."
        echo "Use 'docker compose -f docker-compose.v3.yml logs -f' to view logs."
        ;;

    full)
        echo ""
        echo "Starting full stack (with frontend)..."
        echo ""
        echo "Services:"
        echo "  - PostgreSQL: localhost:5433"
        echo "  - Backend v3: localhost:8000"
        echo "  - Frontend: localhost:3000"
        echo ""
        docker compose -f docker-compose.v3.yml --profile full up --build
        ;;

    db)
        echo ""
        echo "Starting database only..."
        echo ""
        docker compose -f docker-compose.v3.yml up db
        ;;

    *)
        echo "Usage: $0 [dev|prod|full|db]"
        echo ""
        echo "Modes:"
        echo "  dev   - Development with hot reload (default)"
        echo "  prod  - Production mode (background)"
        echo "  full  - Full stack including frontend"
        echo "  db    - Database only"
        exit 1
        ;;
esac
