# Clinomic B12 Platform - Production Deployment Runbook

**Domain:** clinomiclabs.com  
**VPS IP:** 66.116.225.67  
**Stack Path:** /opt/clinomic  
**Last Updated:** January 2026

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Initial VPS Setup](#initial-vps-setup)
3. [CI/CD Pipeline Setup](#cicd-pipeline-setup)
4. [Deployment Procedures](#deployment-procedures)
5. [Rollback Procedures](#rollback-procedures)
6. [SSL Certificate Management](#ssl-certificate-management)
7. [Monitoring & Alerting](#monitoring--alerting)
8. [Troubleshooting](#troubleshooting)
9. [Security Checklist](#security-checklist)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           GITHUB ACTIONS                                 │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐              │
│  │  Push   │───▶│  Test   │───▶│  Build  │───▶│ Approve │              │
│  │  Code   │    │  Lint   │    │  Push   │    │  (prod) │              │
│  └─────────┘    └─────────┘    └─────────┘    └────┬────┘              │
└─────────────────────────────────────────────────────│──────────────────┘
                                                      │ SSH
┌─────────────────────────────────────────────────────▼──────────────────┐
│                        VPS (66.116.225.67)                              │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                         NGINX (Port 80/443)                        │  │
│  │    SSL Termination │ Rate Limiting │ Security Headers             │  │
│  └────────────────────────────┬─────────────────────────────────────┘  │
│                               │                                         │
│         ┌─────────────────────┴─────────────────────┐                  │
│         ▼                                           ▼                  │
│  ┌─────────────────┐                    ┌─────────────────┐            │
│  │    Frontend     │                    │    Backend      │            │
│  │   React:3000    │                    │  FastAPI:8001   │            │
│  │    (static)     │                    │   + ML Models   │            │
│  └─────────────────┘                    └────────┬────────┘            │
│                                                  │                      │
│                                                  ▼                      │
│                                       ┌─────────────────┐              │
│                                       │    MongoDB      │              │
│                                       │    Port 27017   │              │
│                                       │   (localhost)   │              │
│                                       └─────────────────┘              │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Initial VPS Setup

### Prerequisites Checklist

- [ ] Ubuntu 22.04 LTS installed
- [ ] Root SSH access
- [ ] Domain DNS pointing to VPS IP
- [ ] GitHub repository access

### Step 1: SSH into VPS

```bash
ssh root@66.116.225.67
```

### Step 2: Update System

```bash
apt update && apt upgrade -y
apt install -y curl wget git htop vim ufw fail2ban
```

### Step 3: Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Docker Compose v2
apt install -y docker-compose-plugin

# Verify
docker --version
docker compose version
```

### Step 4: Run VM Setup Scripts

```bash
# Clone repository
cd /opt
git clone https://github.com/Dev-Abiox/clinomic-prod.git clinomic
cd clinomic

# Run setup scripts in order
chmod +x scripts/vm-setup/*.sh
./scripts/vm-setup/01-harden-ssh.sh
./scripts/vm-setup/02-configure-firewall.sh
./scripts/vm-setup/03-create-deploy-user.sh
./scripts/vm-setup/04-docker-security.sh
```

### Step 5: Configure Production Environment

```bash
# Copy template
cp .env.production.template .env

# Generate secrets
MONGO_PASS=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 64)
FERNET_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
AUDIT_KEY=$(openssl rand -base64 32)

# Edit .env with your values
vim .env
```

### Step 6: Setup SSL with Certbot

```bash
# Install certbot
apt install -y certbot python3-certbot-nginx

# Get certificate
certbot --nginx -d clinomiclabs.com -d www.clinomiclabs.com

# Verify auto-renewal
certbot renew --dry-run
```

### Step 7: Initial Deployment

```bash
# Pull images
docker compose -f docker-compose.prod.yml pull

# Start services
docker compose -f docker-compose.prod.yml up -d

# Verify
curl -f https://clinomiclabs.com/api/health/ready
```

---

## CI/CD Pipeline Setup

### GitHub Secrets Required

Go to: **Repository → Settings → Secrets and variables → Actions**

| Secret Name | How to Generate | Description |
|-------------|-----------------|-------------|
| `VPS_SSH_PRIVATE_KEY` | From Step 4 above | ed25519 deploy key |
| `GHCR_TOKEN` | GitHub PAT | Package write access |

### GitHub Environment Setup

1. Go to **Repository → Settings → Environments**
2. Create environment: `production`
3. Add protection rules:
   - Required reviewers: Add yourself
   - Wait timer: 0 minutes (optional delay)

### Workflow Files

The following workflows are configured:

| File | Trigger | Purpose |
|------|---------|---------|
| `.github/workflows/ci.yml` | Push/PR | Test, lint, security scan |
| `.github/workflows/deploy.yml` | CI success on main | Deploy to production |
| `.github/workflows/rollback.yml` | Manual | Emergency rollback |

---

## Deployment Procedures

### Automatic Deployment (Recommended)

1. Push code to `main` branch
2. CI pipeline runs tests
3. Build pipeline creates Docker images
4. Deployment requires manual approval
5. Click "Approve" in GitHub Actions
6. Deployment executes automatically

### Manual Deployment (Emergency)

```bash
# SSH to VPS
ssh deploy@66.116.225.67

# Navigate to app
cd /opt/clinomic

# Pull latest images
docker compose -f docker-compose.prod.yml pull

# Deploy with health checks
./scripts/deploy/deploy.sh --tag=latest
```

### Verify Deployment

```bash
# Health check
curl -f https://clinomiclabs.com/api/health/ready

# Check logs
docker logs clinomic-backend --tail 100

# Check all containers
docker compose -f docker-compose.prod.yml ps
```

---

## Rollback Procedures

### Quick Rollback (Previous Version)

```bash
ssh deploy@66.116.225.67
cd /opt/clinomic
./scripts/deploy/rollback.sh --to=previous
```

### Specific Version Rollback

```bash
# Find available tags
docker images | grep clinomic

# Rollback to specific tag
./scripts/deploy/rollback.sh --to=sha-abc1234
```

### GitHub Actions Rollback

1. Go to **Actions → Rollback Production**
2. Click **Run workflow**
3. Enter: `previous` or specific tag
4. Enter reason for audit log
5. Click **Run workflow**

---

## SSL Certificate Management

### Check Certificate Expiry

```bash
echo | openssl s_client -servername clinomiclabs.com -connect clinomiclabs.com:443 2>/dev/null | openssl x509 -noout -dates
```

### Manual Renewal

```bash
certbot renew --force-renewal
nginx -s reload
```

### Auto-Renewal Cron

Certbot installs a systemd timer. Verify:

```bash
systemctl status certbot.timer
```

---

## Monitoring & Alerting

### Health Endpoints

| Endpoint | Purpose | Expected |
|----------|---------|----------|
| `/api/health/live` | Liveness | `{"status": "ok"}` |
| `/api/health/ready` | Readiness | Full health data |

### Log Locations

| Log | Path |
|-----|------|
| Deployment | `/var/log/clinomic-deploys.log` |
| Nginx access | `/var/log/nginx/clinomic_access.log` |
| Nginx error | `/var/log/nginx/clinomic_error.log` |
| Docker | `docker logs <container>` |

### View Logs

```bash
# Deployment history
tail -50 /var/log/clinomic-deploys.log

# Backend logs
docker logs clinomic-backend --tail 100 -f

# All services
docker compose -f docker-compose.prod.yml logs -f
```

---

## Troubleshooting

### Backend Won't Start

```bash
# Check logs
docker logs clinomic-backend

# Common issues:
# 1. MongoDB not ready - wait and retry
# 2. Environment variables missing - check .env
# 3. Port already in use - check with: lsof -i :8001
```

### MongoDB Connection Failed

```bash
# Check MongoDB is running
docker logs clinomic-mongodb

# Test connection
docker exec clinomic-mongodb mongosh --eval "db.adminCommand('ping')"
```

### Nginx 502 Bad Gateway

```bash
# Check upstream services
docker ps

# Check nginx config
nginx -t

# Reload nginx
nginx -s reload
```

### SSL Certificate Issues

```bash
# Check certificate
certbot certificates

# Force renewal
certbot renew --force-renewal
```

---

## Security Checklist

### Pre-Deployment

- [ ] All secrets in `.env`, not in code
- [ ] Password authentication disabled on SSH
- [ ] Firewall enabled (UFW)
- [ ] Fail2ban running
- [ ] Docker socket protected
- [ ] SSL certificate valid
- [ ] CORS configured for production domain only

### Post-Deployment

- [ ] Health endpoint returns 200
- [ ] SSL certificate shows correct domain
- [ ] No exposed ports except 80/443
- [ ] Rate limiting active
- [ ] Audit logs generating

### Regular Maintenance (Monthly)

- [ ] Review deployment logs
- [ ] Check SSL expiry
- [ ] Review fail2ban bans
- [ ] Update base images
- [ ] Rotate MongoDB password (quarterly)

---

## Emergency Contacts

- **Technical Lead:** [Your contact]
- **DevOps:** [Your contact]
- **GitHub Repo:** https://github.com/Dev-Abiox/clinomic-prod

---

## Quick Commands Reference

```bash
# SSH to server
ssh deploy@66.116.225.67

# Go to app
cd /opt/clinomic

# View all containers
docker compose -f docker-compose.prod.yml ps

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Restart all
docker compose -f docker-compose.prod.yml restart

# Restart single service
docker compose -f docker-compose.prod.yml restart backend

# Deploy latest
./scripts/deploy/deploy.sh --tag=latest

# Rollback
./scripts/deploy/rollback.sh --to=previous

# Health check
curl -f https://clinomiclabs.com/api/health/ready | jq
```
