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
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Application stage
FROM base

# Copy application source files
COPY . /app

# Create necessary directories
RUN mkdir -p /app/tcg_cards_input /app/processed /app/logs

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Set default environment variables for container paths
ENV TCG_WATCH_FOLDER=/app/tcg_cards_input
ENV TCG_PROCESSED_FOLDER=/app/processed
ENV TCG_LOG_DIR=/app/logs

# Expose volume mount points
VOLUME ["/app/tcg_cards_input", "/app/processed", "/app/logs"]

# Default command to run the application
CMD ["python", "tcg_card_printer.py"]