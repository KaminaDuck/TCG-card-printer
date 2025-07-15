"""Configuration settings for TCG Card Printer"""

import os
from pathlib import Path

# Directories
BASE_DIR = Path(__file__).parent.absolute()
WATCH_FOLDER = BASE_DIR / "tcg_cards_input"
PROCESSED_FOLDER = BASE_DIR / "processed"
LOG_DIR = BASE_DIR / "logs"

# Image settings
TARGET_WIDTH = 750  # pixels (2.5 inches at 300 DPI)
TARGET_HEIGHT = 1050  # pixels (3.5 inches at 300 DPI)
DPI = 300

# Printer settings
PRINTER_NAME = "Canon_G3070_series"  # Update this to match your printer's name in CUPS
MEDIA_TYPE = "Cardstock"
PAPER_SIZE = "Custom.2.5x3.5in"  # Custom paper size

# File types to monitor
SUPPORTED_FORMATS = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff'}

# Logging
LOG_LEVEL = "INFO"
LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

# Processing settings
AUTO_DELETE_AFTER_PRINT = False
OPTIMIZE_FOR_PRINT = True
JPEG_QUALITY = 95

# Create directories if they don't exist
for directory in [WATCH_FOLDER, PROCESSED_FOLDER, LOG_DIR]:
    directory.mkdir(exist_ok=True)
