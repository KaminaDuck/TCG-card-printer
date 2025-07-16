# TCG Card Printer - Deployment Guide

This document provides comprehensive guidance for deploying the TCG Card Printer in various environments, from development to production.

## Table of Contents

- [Quick Start](#quick-start)
- [Deployment Scenarios](#deployment-scenarios)
- [Security Hardening](#security-hardening)
- [Resource Management](#resource-management)
- [Monitoring and Health Checks](#monitoring-and-health-checks)
- [Network Printing](#network-printing)
- [Production Deployment](#production-deployment)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Local Development

```bash
# 1. Build the container
./scripts/build.sh

# 2. Run with default settings
./scripts/run.sh

# 3. Drop card images in tcg_cards_input folder
```

### Docker Compose (Recommended)

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Edit configuration
vim .env

# 3. Start services
docker-compose up -d

# 4. Monitor logs
docker-compose logs -f
```

## Deployment Scenarios

### 1. Local Desktop Deployment

**Use Case**: Single user, local printer access
**Configuration**: Direct CUPS socket mounting

```bash
# Run with enhanced security
./scripts/run.sh --enable-security --health-check

# Or use Docker Compose
docker-compose up -d
```

**Key Features**:
- Direct CUPS socket access
- Minimal resource requirements
- Simple setup and maintenance

### 2. Network Printing Deployment

**Use Case**: Remote printing, multiple users, containerized environment
**Configuration**: Network-based CUPS communication

```bash
# Use network printing compose file
docker-compose -f docker-compose.network.yml up -d

# Or run with network printing options
./scripts/run.sh --network-printing --cups-host printer-server.local
```

**Key Features**:
- No CUPS socket dependency
- Scalable for multiple instances
- Centralized print server management

### 3. Enterprise Deployment

**Use Case**: Production environment, high availability, monitoring
**Configuration**: Full security hardening, resource limits, monitoring

```bash
# Build with security scanning
./scripts/build.sh --scan --scan-tool trivy

# Deploy with full security
./scripts/run.sh \
  --enable-security \
  --memory 512m \
  --cpu 0.5 \
  --health-check \
  --network printing-network
```

**Key Features**:
- Security scanning integration
- Resource limits and monitoring
- Health checks and alerting
- Centralized logging

## Security Hardening

### Container Security

#### 1. Non-Root User Execution

The container runs as a non-privileged user (UID 1000) by default:

```dockerfile
# Dockerfile already includes:
USER appuser
```

#### 2. Capability Dropping

Minimal capabilities are granted:

```yaml
# docker-compose.yml
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
cap_add:
  - CHOWN
  - SETUID
  - SETGID
```

#### 3. Read-Only Root Filesystem (Optional)

For maximum security, consider read-only root filesystem:

```bash
docker run --read-only \
  --tmpfs /tmp \
  --tmpfs /var/run \
  tcg-card-printer:latest
```

### Network Security

#### 1. Custom Networks

Isolate printing services:

```bash
# Create isolated network
docker network create --driver bridge printing-network

# Run container in isolated network
./scripts/run.sh --network printing-network
```

#### 2. TLS Encryption

Enable CUPS encryption for network printing:

```bash
# Environment variables
export TCG_CUPS_SERVER_ENCRYPTION=true
export TCG_CUPS_SERVER_HOST=secure-cups-server.local
```

### Secrets Management

#### 1. Environment Variables

Use Docker secrets or external secret management:

```yaml
# docker-compose.yml
services:
  tcg-printer:
    environment:
      TCG_CUPS_SERVER_PASSWORD_FILE: /run/secrets/cups_password
    secrets:
      - cups_password

secrets:
  cups_password:
    external: true
```

#### 2. External Secret Providers

Integration with HashiCorp Vault, AWS Secrets Manager, etc.:

```bash
# Example with AWS CLI
export TCG_CUPS_SERVER_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id cups-password --query SecretString --output text)
```

## Resource Management

### Memory Management

#### 1. Container Limits

Set appropriate memory limits:

```yaml
# docker-compose.yml
deploy:
  resources:
    limits:
      memory: 512M
    reservations:
      memory: 128M
```

#### 2. Application Tuning

Configure application memory usage:

```bash
# Environment variables
TCG_MAX_MEMORY_MB=512
TCG_ENABLE_MEMORY_OPTIMIZATION=true
MAX_IMAGE_SIZE_MB=50
```

### CPU Management

#### 1. CPU Limits

Control CPU usage:

```yaml
deploy:
  resources:
    limits:
      cpus: '1'
    reservations:
      cpus: '0.25'
```

#### 2. Processing Optimization

Tune image processing:

```bash
# Match to available CPU cores
PROCESSING_THREADS=2
PROCESSING_TIMEOUT=300
```

### Storage Management

#### 1. Volume Strategy

Choose appropriate volume strategy:

```bash
# Bind mounts (development)
-v ./tcg_cards_input:/app/tcg_cards_input

# Named volumes (production)
-v tcg_input:/app/tcg_cards_input
```

#### 2. Log Rotation

Configure log rotation:

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

## Monitoring and Health Checks

### Health Check Configuration

#### 1. Container Health Checks

Configure health check intervals:

```yaml
healthcheck:
  test: ["/app/scripts/health-check.sh", "detailed"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 15s
```

#### 2. Health Check Levels

Different health check levels:

```bash
# Basic health check (default)
/app/scripts/health-check.sh basic

# Detailed health check
/app/scripts/health-check.sh detailed

# Diagnostic health check
/app/scripts/health-check.sh diagnostic
```

### Monitoring Integration

#### 1. Prometheus Metrics

Export metrics for Prometheus:

```yaml
# Optional: Add metrics exporter sidecar
services:
  metrics-exporter:
    image: prom/node-exporter
    command:
      - '--path.rootfs=/host'
    volumes:
      - '/:/host:ro,rslave'
```

#### 2. Log Aggregation

Integration with ELK stack:

```yaml
logging:
  driver: "gelf"
  options:
    gelf-address: "udp://logstash:12201"
    tag: "tcg-printer"
```

## Network Printing

### CUPS Server Setup

#### 1. Standalone CUPS Server

Deploy dedicated CUPS server:

```yaml
# docker-compose.network.yml includes:
services:
  cups-server:
    image: olbat/cupsd:latest
    environment:
      CUPSADMIN: admin
      CUPSPASSWORD: admin
```

#### 2. Client Configuration

Configure clients for network printing:

```bash
# Environment variables
TCG_USE_NETWORK_PRINTING=true
TCG_CUPS_SERVER_HOST=cups-server.local
TCG_CUPS_SERVER_PORT=631
```

### IPP (Internet Printing Protocol)

#### 1. Direct IPP Connection

Connect directly to IPP-enabled printers:

```bash
# IPP URI format
TCG_IPP_PRINTER_URI=ipp://192.168.1.100:631/printers/Canon_G3070
```

#### 2. Discovery and Configuration

Auto-discover network printers:

```bash
# Use avahi-browse or similar tools
avahi-browse -t _ipp._tcp

# Configure discovered printers
TCG_IPP_PRINTER_URI=ipp://Canon-G3070.local:631/printers/Canon_G3070
```

## Production Deployment

### Pre-Deployment Checklist

#### 1. Security Review

- [ ] Security scanning completed
- [ ] Secrets properly managed
- [ ] Network isolation configured
- [ ] Resource limits set
- [ ] Health checks configured

#### 2. Performance Testing

- [ ] Load testing completed
- [ ] Resource usage measured
- [ ] Print quality verified
- [ ] Error handling tested

#### 3. Operational Readiness

- [ ] Monitoring configured
- [ ] Backup procedures established
- [ ] Recovery procedures tested
- [ ] Documentation updated

### Deployment Strategies

#### 1. Blue-Green Deployment

```bash
# Deploy new version alongside old
docker-compose -f docker-compose.yml -p tcg-blue up -d
docker-compose -f docker-compose.yml -p tcg-green up -d

# Switch traffic
# Update load balancer or DNS
```

#### 2. Rolling Updates

```bash
# Docker Swarm mode
docker service update --image tcg-card-printer:new tcg-printer

# Kubernetes
kubectl set image deployment/tcg-printer container=tcg-card-printer:new
```

### High Availability

#### 1. Load Balancing

Distribute load across multiple instances:

```yaml
# docker-compose.yml
services:
  tcg-printer:
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
```

#### 2. Failover Configuration

Configure automatic failover:

```bash
# Health check based failover
restart: unless-stopped

# External health monitoring
# Use tools like Consul, etcd, or cloud health checks
```

### Backup and Recovery

#### 1. Data Backup

Backup critical data:

```bash
# Backup processed files
docker run --rm -v tcg_processed:/data alpine tar czf - /data > backup.tar.gz

# Backup configuration
cp .env docker-compose.yml /backup/
```

#### 2. Disaster Recovery

Recovery procedures:

```bash
# Restore from backup
docker run --rm -v tcg_processed:/data alpine tar xzf - < backup.tar.gz

# Rebuild and restart
./scripts/build.sh
docker-compose up -d
```

## Troubleshooting

### Common Issues

#### 1. Container Won't Start

```bash
# Check logs
docker logs tcg-card-printer

# Common causes:
# - File permission issues
# - CUPS socket not accessible
# - Configuration errors
```

#### 2. Printing Failures

```bash
# Check printer connectivity
docker exec tcg-card-printer lpstat -p

# Check CUPS configuration
docker exec tcg-card-printer lpstat -t

# Test print
docker exec tcg-card-printer lp -d Canon_G3070_series /etc/passwd
```

#### 3. Performance Issues

```bash
# Monitor resource usage
docker stats tcg-card-printer

# Check health status
docker exec tcg-card-printer /app/scripts/health-check.sh diagnostic

# Review logs for bottlenecks
docker logs tcg-card-printer | grep -E "(WARNING|ERROR)"
```

### Debugging Tools

#### 1. Interactive Shell

```bash
# Access container shell
docker exec -it tcg-card-printer /bin/bash

# Check application status
ps aux | grep python
ls -la /app/
```

#### 2. Health Check Tools

```bash
# Manual health check
docker exec tcg-card-printer /app/scripts/health-check.sh detailed

# JSON output for automation
docker exec tcg-card-printer /app/scripts/health-check.sh basic json
```

#### 3. Network Diagnostics

```bash
# Test CUPS connectivity
docker exec tcg-card-printer curl -v http://cups-server:631/

# Test IPP connectivity
docker exec tcg-card-printer curl -v $TCG_IPP_PRINTER_URI
```

### Performance Optimization

#### 1. Image Processing Optimization

```bash
# Tune DPI for speed vs quality balance
TCG_DPI=150  # Faster processing
TCG_DPI=300  # Better quality (default)
TCG_DPI=600  # Highest quality (slower)

# Optimize JPEG quality
TCG_JPEG_QUALITY=85  # Good quality, smaller files
TCG_JPEG_QUALITY=95  # High quality (default)
```

#### 2. System Optimization

```bash
# Increase processing threads
PROCESSING_THREADS=4  # Match CPU cores

# Optimize memory usage
TCG_ENABLE_MEMORY_OPTIMIZATION=true
MAX_IMAGE_SIZE_MB=25  # Reduce for memory-constrained systems
```

### Support and Maintenance

#### 1. Log Analysis

```bash
# Monitor application logs
tail -f logs/tcg_printer.log

# Search for errors
grep -E "(ERROR|CRITICAL)" logs/tcg_printer.log

# Analyze performance
grep "Processing time" logs/tcg_printer.log
```

#### 2. Regular Maintenance

```bash
# Update container images
docker pull python:3.11-slim
./scripts/build.sh

# Clean up old images
docker image prune

# Rotate logs
logrotate /etc/logrotate.d/tcg-printer
```

For additional support, refer to the project documentation or create an issue in the project repository.