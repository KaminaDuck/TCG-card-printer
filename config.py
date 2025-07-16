"""Configuration settings for TCG Card Printer"""

import os
import sys
from pathlib import Path
from typing import Optional


class ConfigurationError(Exception):
    """Raised when configuration validation fails"""
    pass


def parse_bool(value: str, default: bool = False) -> bool:
    """Parse boolean environment variables with validation."""
    if not value:
        return default
    return value.lower() in ('true', '1', 'yes', 'on', 'enabled')


def validate_dpi(dpi: int) -> int:
    """Validate DPI is within acceptable range."""
    MIN_DPI = 150
    MAX_DPI = 600
    
    if not MIN_DPI <= dpi <= MAX_DPI:
        raise ConfigurationError(
            f"DPI must be between {MIN_DPI} and {MAX_DPI}. Got: {dpi}"
        )
    return dpi


def validate_port(port: str) -> int:
    """Validate network port number."""
    try:
        port_num = int(port)
        if not 1 <= port_num <= 65535:
            raise ValueError
        return port_num
    except ValueError:
        raise ConfigurationError(
            f"Invalid port number: {port}. Must be between 1 and 65535."
        )


def get_env_path(env_var: str, default: Path) -> Path:
    """Get path from environment variable with validation."""
    path_str = os.getenv(env_var, str(default))
    return Path(path_str).absolute()


# Directories
BASE_DIR = Path(__file__).parent.absolute()
WATCH_FOLDER = get_env_path('TCG_WATCH_FOLDER', BASE_DIR / "tcg_cards_input")
PROCESSED_FOLDER = get_env_path('TCG_PROCESSED_FOLDER', BASE_DIR / "processed")
LOG_DIR = get_env_path('TCG_LOG_DIR', BASE_DIR / "logs")

# Image settings
TARGET_WIDTH = 750  # pixels (2.5 inches at 300 DPI)
TARGET_HEIGHT = 1050  # pixels (3.5 inches at 300 DPI)

try:
    DPI = validate_dpi(int(os.getenv('TCG_DPI', '300')))
except ValueError:
    raise ConfigurationError(f"Invalid DPI value: {os.getenv('TCG_DPI')}")

# Printer settings
PRINTER_NAME = os.getenv('TCG_PRINTER_NAME', 'Canon_G3070_series')  # Update this to match your printer's name in CUPS
MEDIA_TYPE = os.getenv('TCG_MEDIA_TYPE', 'Cardstock')
PAPER_SIZE = os.getenv('TCG_PAPER_SIZE', 'Custom.2.5x3.5in')  # Custom paper size

# Network printing configuration (alternative to CUPS socket)
USE_NETWORK_PRINTING = parse_bool(os.getenv('TCG_USE_NETWORK_PRINTING', 'false'))
CUPS_SERVER_HOST = os.getenv('TCG_CUPS_SERVER_HOST', 'localhost')
CUPS_SERVER_PORT = validate_port(os.getenv('TCG_CUPS_SERVER_PORT', '631'))
CUPS_SERVER_ENCRYPTION = parse_bool(os.getenv('TCG_CUPS_SERVER_ENCRYPTION', 'false'))
CUPS_SERVER_USERNAME = os.getenv('TCG_CUPS_SERVER_USERNAME', '')
CUPS_SERVER_PASSWORD = os.getenv('TCG_CUPS_SERVER_PASSWORD', '')

# IPP (Internet Printing Protocol) settings
IPP_PRINTER_URI = os.getenv('TCG_IPP_PRINTER_URI', '')  # e.g., ipp://printer.local:631/printers/Canon_G3070

# File types to monitor
SUPPORTED_FORMATS = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff'}

# Logging
LOG_LEVEL = os.getenv('TCG_LOG_LEVEL', 'INFO').upper()
if LOG_LEVEL not in ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']:
    raise ConfigurationError(f"Invalid log level: {LOG_LEVEL}")

LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

# Processing settings
AUTO_DELETE_AFTER_PRINT = parse_bool(os.getenv('TCG_AUTO_DELETE', 'false'))
OPTIMIZE_FOR_PRINT = parse_bool(os.getenv('TCG_OPTIMIZE_FOR_PRINT', 'true'))

try:
    JPEG_QUALITY = int(os.getenv('TCG_JPEG_QUALITY', '95'))
    if not 1 <= JPEG_QUALITY <= 100:
        raise ValueError
except ValueError:
    raise ConfigurationError("JPEG_QUALITY must be between 1 and 100")

# Health check settings
HEALTH_CHECK_ENABLED = parse_bool(os.getenv('TCG_HEALTH_CHECK_ENABLED', 'true'))
HEALTH_CHECK_INTERVAL = int(os.getenv('TCG_HEALTH_CHECK_INTERVAL', '30'))  # seconds
HEALTH_CHECK_TIMEOUT = int(os.getenv('TCG_HEALTH_CHECK_TIMEOUT', '10'))  # seconds

# Resource monitoring
ENABLE_RESOURCE_MONITORING = parse_bool(os.getenv('TCG_ENABLE_RESOURCE_MONITORING', 'false'))
MAX_MEMORY_MB = int(os.getenv('TCG_MAX_MEMORY_MB', '512'))
MAX_CPU_PERCENT = int(os.getenv('TCG_MAX_CPU_PERCENT', '80'))

# Create directories if they don't exist
for directory in [WATCH_FOLDER, PROCESSED_FOLDER, LOG_DIR]:
    try:
        directory.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        raise ConfigurationError(f"Failed to create directory {directory}: {e}")

# Validate configuration on import
def validate_configuration():
    """Validate all configuration settings."""
    errors = []
    
    # Check if printer name is provided
    if not PRINTER_NAME:
        errors.append("PRINTER_NAME is required")
    
    # Check network printing configuration
    if USE_NETWORK_PRINTING:
        if not CUPS_SERVER_HOST:
            errors.append("CUPS_SERVER_HOST is required when USE_NETWORK_PRINTING is enabled")
        
        if CUPS_SERVER_USERNAME and not CUPS_SERVER_PASSWORD:
            errors.append("CUPS_SERVER_PASSWORD is required when CUPS_SERVER_USERNAME is set")
    
    # Check if directories are writable
    for dir_name, directory in [
        ("WATCH_FOLDER", WATCH_FOLDER),
        ("PROCESSED_FOLDER", PROCESSED_FOLDER),
        ("LOG_DIR", LOG_DIR)
    ]:
        if not os.access(directory, os.W_OK):
            errors.append(f"{dir_name} ({directory}) is not writable")
    
    if errors:
        raise ConfigurationError(
            "Configuration validation failed:\n" + "\n".join(f"  - {e}" for e in errors)
        )


# Run validation
try:
    validate_configuration()
except ConfigurationError as e:
    print(f"Configuration Error: {e}", file=sys.stderr)
    sys.exit(1)
