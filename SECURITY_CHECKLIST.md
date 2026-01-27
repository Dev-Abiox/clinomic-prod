# Security Hardening Checklist - Clinomic Production

**Environment:** Production  
**Domain:** clinomiclabs.com  
**Compliance Target:** HIPAA / ISO27001  

---

## 1. Network Security

### Firewall (UFW)
- [ ] Default deny incoming
- [ ] Default allow outgoing
- [ ] Only ports 22, 80, 443 open
- [ ] Docker networks internal only

```bash
# Verify
ufw status verbose
```

### SSH Hardening
- [ ] Password authentication disabled
- [ ] Root login restricted to key only
- [ ] Max auth tries: 3
- [ ] Idle timeout configured
- [ ] Only ed25519 or RSA 4096+ keys

```bash
# Verify
grep -E "PasswordAuthentication|PermitRootLogin|MaxAuthTries" /etc/ssh/sshd_config
```

### Fail2ban
- [ ] SSH jail enabled
- [ ] Nginx jails enabled
- [ ] Ban time: 24 hours for SSH

```bash
# Verify
fail2ban-client status sshd
```

---

## 2. Docker Security

### Socket Protection
- [ ] Docker socket 660 permissions
- [ ] Only docker group can access
- [ ] `no-new-privileges` enabled
- [ ] User namespace remapping (optional)

```bash
# Verify
ls -la /var/run/docker.sock
docker info | grep -E "Security|Privileges"
```

### Container Security
- [ ] Containers run as non-root
- [ ] Read-only filesystems where possible
- [ ] Resource limits configured
- [ ] Health checks defined

```bash
# Verify
docker inspect clinomic-backend | jq '.[0].HostConfig.Memory'
```

---

## 3. Application Security

### Authentication
- [ ] JWT tokens with short expiry (60 min)
- [ ] Refresh tokens stored hashed
- [ ] MFA enabled for ADMIN/DOCTOR roles
- [ ] Rate limiting on login endpoint

### Encryption
- [ ] TLS 1.2+ only
- [ ] Strong cipher suite
- [ ] HSTS enabled
- [ ] Field-level encryption for PHI

```bash
# Test SSL
echo | openssl s_client -connect clinomiclabs.com:443 -tls1_3 2>/dev/null | head -5
```

### CORS
- [ ] Production domains only
- [ ] No wildcard in production
- [ ] Credentials allowed only from trusted origins

---

## 4. Data Security

### MongoDB
- [ ] Authentication enabled
- [ ] Localhost only binding
- [ ] Strong admin password
- [ ] Application user with limited permissions

```bash
# Verify (from container)
docker exec clinomic-mongodb mongosh --eval "db.adminCommand('getCmdLineOpts')" | grep -i bind
```

### Backups
- [ ] Daily automated backups
- [ ] Encrypted backup storage
- [ ] Tested restore procedure
- [ ] 30-day retention

### Audit Logging
- [ ] All auth events logged
- [ ] All data access logged
- [ ] Hash-chained audit entries
- [ ] 7-year retention for HIPAA

---

## 5. Secrets Management

### Storage
- [ ] Secrets in `.env` file only
- [ ] `.env` never in git
- [ ] 600 permissions on `.env`
- [ ] Secrets rotated on schedule

```bash
# Verify
ls -la /opt/clinomic/.env
```

### Rotation Schedule

| Secret | Rotation Period | Last Rotated |
|--------|-----------------|--------------|
| MongoDB password | 90 days | __________ |
| JWT secret | On breach | __________ |
| Master encryption key | Never | _N/A_ |
| Audit signing key | Never | _N/A_ |

---

## 6. SSL/TLS

### Certificate
- [ ] Valid for domain
- [ ] Not expired
- [ ] Auto-renewal configured
- [ ] Tested renewal works

```bash
# Check expiry
certbot certificates
```

### Headers
- [ ] HSTS with long max-age
- [ ] X-Frame-Options: SAMEORIGIN
- [ ] X-Content-Type-Options: nosniff
- [ ] Content-Security-Policy defined

```bash
# Verify headers
curl -I https://clinomiclabs.com 2>/dev/null | grep -iE "strict|frame|content-type|security"
```

---

## 7. Monitoring & Incident Response

### Logging
- [ ] Centralized logging configured
- [ ] Log retention policy defined
- [ ] Sensitive data redacted from logs
- [ ] Log integrity verified

### Alerting
- [ ] Health check monitoring
- [ ] SSL expiry alerts
- [ ] Disk space alerts
- [ ] Failed login alerts

### Incident Response
- [ ] Runbook documented
- [ ] Rollback procedure tested
- [ ] Escalation contacts defined
- [ ] Post-incident review process

---

## 8. Deployment Security

### CI/CD
- [ ] Branch protection on main
- [ ] Required reviews before merge
- [ ] Automated security scans
- [ ] Manual approval for production
- [ ] Secrets in GitHub Secrets only

### Container Images
- [ ] Base images from trusted registry
- [ ] Regular security scans (Trivy)
- [ ] No secrets in images
- [ ] Multi-stage builds

---

## Compliance Notes

### HIPAA Requirements
- ✓ Access controls (RBAC)
- ✓ Audit logging (hash-chained)
- ✓ Encryption in transit (TLS 1.3)
- ✓ Encryption at rest (Fernet)
- ✓ Automatic logoff (JWT expiry)
- ⚠ BAA required with cloud providers

### ISO 27001
- ✓ Access control policy
- ✓ Cryptographic controls
- ✓ Operations security
- ⚠ Information security policy (document required)
- ⚠ Risk assessment (document required)

---

## Sign-off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| DevOps Engineer | | | |
| Security Lead | | | |
| Technical Lead | | | |
