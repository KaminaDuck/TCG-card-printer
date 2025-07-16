# Multi-stage Dockerfile for TCG Card Printer

# Base stage
FROM python:3.11-slim as base

# Install system dependencies for pycups and image processing
RUN apt-get update && apt-get install -y \
    gcc \
    libcups2-dev \
    libcups2 \
    libjpeg-dev \
    zlib1g-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r appuser -g 1000 && \
    useradd -r -u 1000 -g appuser -m -s /bin/false appuser

# Set working directory
WORKDIR /app

# Copy requirements first for better layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Application stage
FROM base

# Copy application source files (as root for proper ownership)
COPY --chown=appuser:appuser . /app

# Create necessary directories with proper permissions
RUN mkdir -p /app/tcg_cards_input /app/processed /app/logs && \
    chown -R appuser:appuser /app/tcg_cards_input /app/processed /app/logs && \
    chmod 755 /app/tcg_cards_input /app/processed /app/logs

# Copy health check script
COPY --chown=appuser:appuser scripts/health-check.sh /app/scripts/
RUN chmod +x /app/scripts/health-check.sh

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Set default environment variables for container paths
ENV TCG_WATCH_FOLDER=/app/tcg_cards_input \
    TCG_PROCESSED_FOLDER=/app/processed \
    TCG_LOG_DIR=/app/logs

# Security labels
LABEL security.scan="enabled" \
      security.user="appuser" \
      maintainer="TCG Card Printer Team"

# Health check configuration
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/app/scripts/health-check.sh"]

# Switch to non-root user
USER appuser

# Expose volume mount points
VOLUME ["/app/tcg_cards_input", "/app/processed", "/app/logs"]

# Default command to run the application
CMD ["python", "tcg_card_printer.py"]