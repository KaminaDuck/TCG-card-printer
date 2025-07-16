# TCG Card Printer - Security Guide

This document outlines security best practices, threat modeling, and security controls for the TCG Card Printer application.

## Table of Contents

- [Security Overview](#security-overview)
- [Threat Model](#threat-model)
- [Container Security](#container-security)
- [Network Security](#network-security)
- [Access Controls](#access-controls)
- [Secrets Management](#secrets-management)
- [Vulnerability Management](#vulnerability-management)
- [Compliance and Auditing](#compliance-and-auditing)
- [Incident Response](#incident-response)
- [Security Testing](#security-testing)

## Security Overview

The TCG Card Printer implements defense-in-depth security principles with multiple layers of protection:

1. **Container Security**: Non-root execution, capability restrictions, read-only filesystems
2. **Network Security**: Network isolation, encrypted communications, minimal exposure
3. **Access Controls**: Authentication, authorization, and least privilege principles
4. **Vulnerability Management**: Regular scanning, patching, and security updates
5. **Monitoring**: Security event logging, anomaly detection, and alerting

### Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Host Security Layer                       │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Container Security Layer                   │ │
│  │  ┌─────────────────────────────────────────────────────┐│ │
│  │  │           Application Security Layer                ││ │
│  │  │  ┌─────────────────────────────────────────────────┐││ │
│  │  │  │         Data Security Layer                     │││ │
│  │  │  └─────────────────────────────────────────────────┘││ │
│  │  └─────────────────────────────────────────────────────┘│ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Threat Model

### Assets

1. **Application Code**: Source code, configuration files, scripts
2. **Container Images**: Docker images containing the application
3. **Print Data**: Card images being processed and printed
4. **Printer Access**: Physical printer and print queue access
5. **System Resources**: CPU, memory, storage, network bandwidth
6. **Credentials**: CUPS passwords, API keys, certificates

### Threat Actors

1. **External Attackers**: Remote attackers attempting unauthorized access
2. **Malicious Insiders**: Users with legitimate access acting maliciously
3. **Compromised Systems**: Previously trusted systems that have been compromised
4. **Supply Chain**: Compromised dependencies or base images

### Attack Vectors

1. **Container Escape**: Exploiting container runtime vulnerabilities
2. **Privilege Escalation**: Gaining elevated privileges within the container
3. **Network Attacks**: Man-in-the-middle, eavesdropping, DDoS
4. **Code Injection**: Malicious file uploads, command injection
5. **Supply Chain Attacks**: Compromised dependencies or base images
6. **Social Engineering**: Targeting users or administrators

### Risk Assessment

| Threat | Likelihood | Impact | Risk Level | Mitigation |
|--------|------------|--------|------------|------------|
| Container Escape | Low | High | Medium | Non-root user, capability restrictions |
| Network Eavesdropping | Medium | Medium | Medium | TLS encryption, network isolation |
| Malicious File Upload | Medium | Low | Low | File validation, sandboxing |
| Credential Exposure | Low | High | Medium | Secrets management, encryption |
| DoS Attack | Medium | Medium | Medium | Rate limiting, resource controls |

## Container Security

### 1. Non-Root Execution

The application runs as a non-privileged user:

```dockerfile
# Create non-root user
RUN groupadd -r appuser -g 1000 && \
    useradd -r -u 1000 -g appuser -m -s /bin/false appuser

# Switch to non-root user
USER appuser
```

**Benefits**:
- Reduces impact of container escape
- Prevents privilege escalation attacks
- Follows principle of least privilege

### 2. Capability Restrictions

Minimal Linux capabilities are granted:

```yaml
# docker-compose.yml
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
cap_add:
  - CHOWN      # File ownership changes
  - SETUID     # User ID changes
  - SETGID     # Group ID changes
```

**Required Capabilities**:
- `CHOWN`: Managing file ownership for volume mounts
- `SETUID/SETGID`: Required for some printing operations

### 3. Security Labels and Policies

Enable security labels for additional protection:

```yaml
security_opt:
  - no-new-privileges:true
  - label:type:container_t  # SELinux
  - apparmor:docker-default # AppArmor
```

### 4. Read-Only Root Filesystem

For maximum security, enable read-only root filesystem:

```bash
docker run --read-only \
  --tmpfs /tmp \
  --tmpfs /var/run \
  --tmpfs /var/log \
  tcg-card-printer:latest
```

### 5. Resource Limits

Prevent resource exhaustion attacks:

```yaml
deploy:
  resources:
    limits:
      cpus: '1'
      memory: 512M
      pids: 100
```

## Network Security

### 1. Network Isolation

Create isolated networks for printing services:

```bash
# Create isolated network
docker network create --driver bridge \
  --subnet=172.20.0.0/16 \
  --opt com.docker.network.bridge.name=br-printing \
  printing-network
```

### 2. TLS Encryption

Enable TLS for CUPS communication:

```bash
# Environment configuration
TCG_CUPS_SERVER_ENCRYPTION=true
TCG_CUPS_SERVER_HOST=secure-cups.example.com
```

### 3. Firewall Rules

Implement host-level firewall rules:

```bash
# Allow only necessary ports
iptables -A INPUT -p tcp --dport 631 -s 172.20.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport 631 -j DROP

# Block unnecessary outbound connections
iptables -A OUTPUT -m owner --gid-owner 1000 -p tcp --dport 80,443,631 -j ACCEPT
iptables -A OUTPUT -m owner --gid-owner 1000 -j DROP
```

### 4. Network Monitoring

Monitor network traffic for anomalies:

```bash
# Monitor container network traffic
docker exec tcg-card-printer netstat -tuln

# Log network connections
docker exec tcg-card-printer ss -tuln > network-connections.log
```

## Access Controls

### 1. Authentication

Implement authentication for CUPS access:

```bash
# CUPS server configuration
echo "DefaultEncryption Required" >> /etc/cups/cupsd.conf
echo "DefaultAuthType Basic" >> /etc/cups/cupsd.conf

# Add user authentication
htpasswd -c /etc/cups/passwd tcg-printer
```

### 2. Authorization

Configure fine-grained access controls:

```xml
<!-- /etc/cups/cupsd.conf -->
<Location />
  Order allow,deny
  AuthType Basic
  AuthName "TCG Printer Access"
  AuthUserFile /etc/cups/passwd
  Require valid-user
</Location>

<Location /printers/Canon_G3070>
  Order allow,deny
  AuthType Basic
  Require user tcg-printer
</Location>
```

### 3. Role-Based Access Control (RBAC)

Implement RBAC for different user types:

```yaml
# Example Kubernetes RBAC
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: tcg-printer-role
rules:
- apiGroups: [""]
  resources: ["pods", "configmaps"]
  verbs: ["get", "list", "watch"]
```

### 4. File System Permissions

Secure file system permissions:

```bash
# Set secure permissions
chmod 755 /app/tcg_cards_input
chmod 755 /app/processed
chmod 750 /app/logs
chmod 640 /app/config.py

# Verify permissions
ls -la /app/
```

## Secrets Management

### 1. Environment Variables vs. Files

Prefer secrets files over environment variables:

```yaml
# Insecure: Environment variable
environment:
  - CUPS_PASSWORD=secret123

# Secure: Secret file
environment:
  - CUPS_PASSWORD_FILE=/run/secrets/cups_password
secrets:
  - cups_password
```

### 2. External Secret Management

Integration with external secret managers:

```bash
# HashiCorp Vault integration
export VAULT_ADDR=https://vault.example.com
export VAULT_TOKEN=$(vault auth -method=userpass username=tcg-service)
export CUPS_PASSWORD=$(vault kv get -field=password secret/cups)

# AWS Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id tcg/cups-credentials \
  --query SecretString --output text
```

### 3. Secret Rotation

Implement automatic secret rotation:

```bash
#!/bin/bash
# rotate-secrets.sh

# Rotate CUPS password
NEW_PASSWORD=$(openssl rand -base64 32)
htpasswd -cb /etc/cups/passwd tcg-printer "$NEW_PASSWORD"

# Update secret in external store
vault kv put secret/cups password="$NEW_PASSWORD"

# Restart services
docker-compose restart tcg-printer
```

### 4. Secret Scanning

Prevent secrets in code repositories:

```bash
# git-secrets installation and configuration
git secrets --install
git secrets --register-aws

# Scan for secrets
git secrets --scan
```

## Vulnerability Management

### 1. Automated Scanning

Integrate security scanning into CI/CD pipeline:

```yaml
# .github/workflows/security.yml
name: Security Scan
on: [push, pull_request]
jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build image
        run: docker build -t tcg-printer .
      - name: Run Trivy scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: tcg-printer
          format: sarif
          output: trivy-results.sarif
```

### 2. Dependency Scanning

Scan Python dependencies for vulnerabilities:

```bash
# Install safety
pip install safety

# Scan dependencies
safety check --json > security-report.json

# Audit with pip-audit
pip install pip-audit
pip-audit --desc --format=json
```

### 3. Base Image Security

Use minimal, regularly updated base images:

```dockerfile
# Use official Python slim image
FROM python:3.11-slim

# Update packages regularly
RUN apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
```

### 4. Vulnerability Response

Establish vulnerability response procedures:

1. **Detection**: Automated scanning and monitoring
2. **Assessment**: Evaluate impact and exploitability
3. **Prioritization**: CVSS scoring and business impact
4. **Remediation**: Patching, updates, or mitigations
5. **Verification**: Testing and validation
6. **Documentation**: Record actions and lessons learned

## Compliance and Auditing

### 1. Security Logging

Comprehensive security event logging:

```python
# Enhanced logging configuration
import logging
import json
from datetime import datetime

class SecurityLogger:
    def __init__(self):
        self.logger = logging.getLogger('security')
        
    def log_security_event(self, event_type, details):
        event = {
            'timestamp': datetime.utcnow().isoformat(),
            'event_type': event_type,
            'details': details,
            'source': 'tcg-card-printer'
        }
        self.logger.warning(json.dumps(event))

# Usage examples
security_logger = SecurityLogger()
security_logger.log_security_event('file_access', {
    'file': filename,
    'user': os.getenv('USER'),
    'action': 'read'
})
```

### 2. Audit Trails

Maintain detailed audit trails:

```bash
# File access auditing
auditctl -w /app/tcg_cards_input -p rwxa -k tcg_file_access
auditctl -w /app/processed -p rwxa -k tcg_file_processed

# Container events
docker events --filter container=tcg-card-printer --format 'table {{.Time}}\t{{.Action}}\t{{.Actor.Attributes.name}}'
```

### 3. Compliance Frameworks

Map controls to compliance frameworks:

#### CIS Docker Benchmark

| Control | Description | Implementation |
|---------|-------------|----------------|
| 4.1 | Run containers with non-root user | USER appuser in Dockerfile |
| 4.5 | Do not use privileged containers | No --privileged flag |
| 4.6 | Do not use sensitive host namespaces | Default namespaces |
| 5.3 | Restrict Linux capabilities | cap_drop: ALL, minimal cap_add |

#### NIST Cybersecurity Framework

| Function | Category | Implementation |
|----------|----------|----------------|
| Identify | Asset Management | Container inventory and labeling |
| Protect | Access Control | RBAC and authentication |
| Detect | Anomaly Detection | Health checks and monitoring |
| Respond | Response Planning | Incident response procedures |
| Recover | Recovery Planning | Backup and disaster recovery |

### 4. Compliance Reporting

Generate compliance reports:

```bash
#!/bin/bash
# compliance-report.sh

# Container security assessment
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/docker-bench-security

# CIS Kubernetes benchmark (if applicable)
kube-bench --json > cis-kubernetes-report.json

# Custom compliance check
./scripts/security-check.sh --compliance-report
```

## Incident Response

### 1. Incident Response Plan

**Phase 1: Preparation**
- Establish incident response team
- Document procedures and contacts
- Prepare tools and access credentials
- Conduct regular training exercises

**Phase 2: Detection and Analysis**
- Monitor security alerts and logs
- Analyze potential security incidents
- Determine incident scope and impact
- Document initial findings

**Phase 3: Containment, Eradication, and Recovery**
- Contain the incident to prevent spread
- Remove malicious components
- Restore systems from clean backups
- Verify system integrity

**Phase 4: Post-Incident Activities**
- Document lessons learned
- Update security controls
- Improve detection capabilities
- Conduct post-mortem review

### 2. Security Playbooks

#### Container Compromise Response

```bash
#!/bin/bash
# container-incident-response.sh

# 1. Isolate container
docker network disconnect printing-network tcg-card-printer

# 2. Preserve evidence
docker commit tcg-card-printer evidence-$(date +%Y%m%d-%H%M%S)
docker logs tcg-card-printer > incident-logs-$(date +%Y%m%d-%H%M%S).log

# 3. Analyze container
docker exec tcg-card-printer ps aux
docker exec tcg-card-printer netstat -tuln
docker exec tcg-card-printer find /app -type f -newer /tmp/baseline

# 4. Clean rebuild
docker stop tcg-card-printer
docker rm tcg-card-printer
./scripts/build.sh --scan
./scripts/run.sh --enable-security
```

#### Data Breach Response

```bash
#!/bin/bash
# data-breach-response.sh

# 1. Assess data exposure
find /app/tcg_cards_input -type f -exec ls -la {} \;
find /app/processed -type f -exec ls -la {} \;

# 2. Secure remaining data
chmod 600 /app/tcg_cards_input/*
chmod 600 /app/processed/*

# 3. Notify stakeholders
echo "Data breach detected at $(date)" | mail -s "Security Incident" admin@example.com

# 4. Forensic analysis
tar czf evidence-$(date +%Y%m%d).tar.gz /app/tcg_cards_input /app/processed /app/logs
```

### 3. Communication Plan

**Internal Communications**:
- Security team notification
- Management escalation
- Technical team coordination
- Legal and compliance teams

**External Communications**:
- Customer notification
- Regulatory reporting
- Public disclosure (if required)
- Vendor coordination

## Security Testing

### 1. Static Analysis

Code security analysis:

```bash
# Bandit for Python security issues
pip install bandit
bandit -r . -f json -o security-report.json

# Semgrep for security patterns
pip install semgrep
semgrep --config=auto --json -o semgrep-report.json
```

### 2. Dynamic Analysis

Runtime security testing:

```bash
# OWASP ZAP for web application testing
docker run -v $(pwd):/zap/wrk/:rw -t owasp/zap2docker-stable zap-baseline.py \
  -t http://tcg-printer:8080 -J zap-report.json

# Container runtime analysis
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image tcg-card-printer:latest
```

### 3. Penetration Testing

Regular penetration testing schedule:

**Quarterly Tests**:
- Container escape attempts
- Network segmentation testing
- Authentication bypass testing
- Privilege escalation testing

**Annual Tests**:
- Full application security assessment
- Social engineering testing
- Physical security review
- Disaster recovery testing

### 4. Security Metrics

Track security metrics:

```python
# Security metrics collection
security_metrics = {
    'vulnerabilities_found': len(vulnerability_scan_results),
    'vulnerabilities_fixed': len(fixed_vulnerabilities),
    'mean_time_to_fix': calculate_mttr(vulnerability_data),
    'security_incidents': len(security_incidents),
    'compliance_score': calculate_compliance_score()
}
```

## Security Maintenance

### 1. Regular Updates

Automated update schedule:

```bash
#!/bin/bash
# security-updates.sh

# Update base image
docker pull python:3.11-slim

# Rebuild with latest security patches
./scripts/build.sh --scan

# Update dependencies
pip install --upgrade -r requirements.txt
safety check

# Restart services
docker-compose up -d
```

### 2. Security Monitoring

Continuous security monitoring:

```bash
# Real-time log monitoring
tail -f /app/logs/security.log | grep -E "(CRITICAL|ERROR|WARNING)"

# Container behavior monitoring
docker stats tcg-card-printer
docker exec tcg-card-printer ps aux | grep -v "appuser"
```

### 3. Security Training

Regular security training for team members:

- Secure coding practices
- Container security best practices
- Incident response procedures
- Threat awareness and recognition

For additional security guidance or to report security issues, contact the security team at security@example.com.