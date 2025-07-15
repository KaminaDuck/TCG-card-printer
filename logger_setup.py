"""Logging configuration and setup"""

import logging
import logging.handlers
from pathlib import Path
from datetime import datetime
import config


def setup_logging():
    """Configure logging for the application"""
    # Create logs directory if it doesn't exist
    config.LOG_DIR.mkdir(exist_ok=True)
    
    # Create formatters
    detailed_formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(funcName)s:%(lineno)d - %(message)s'
    )
    simple_formatter = logging.Formatter(config.LOG_FORMAT)
    
    # Get root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, config.LOG_LEVEL))
    
    # Remove any existing handlers
    root_logger.handlers = []
    
    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(simple_formatter)
    root_logger.addHandler(console_handler)
    
    # File handler - rotates daily
    log_file = config.LOG_DIR / f"mtg_printer_{datetime.now().strftime('%Y%m%d')}.log"
    file_handler = logging.handlers.RotatingFileHandler(
        log_file,
        maxBytes=10*1024*1024,  # 10MB
        backupCount=5
    )
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(detailed_formatter)
    root_logger.addHandler(file_handler)
    
    # Error file handler - only errors and above
    error_file = config.LOG_DIR / "errors.log"
    error_handler = logging.handlers.RotatingFileHandler(
        error_file,
        maxBytes=5*1024*1024,  # 5MB
        backupCount=3
    )
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(detailed_formatter)
    root_logger.addHandler(error_handler)
    
    # Log initial setup
    logger = logging.getLogger(__name__)
    logger.info("Logging system initialized")
    logger.info(f"Log directory: {config.LOG_DIR}")
    logger.info(f"Log level: {config.LOG_LEVEL}")
    
    return root_logger


class ErrorHandler:
    """Centralized error handling"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.error_count = 0
        self.last_errors = []
    
    def handle_error(self, error, context="", critical=False):
        """Handle an error with appropriate logging and recovery"""
        self.error_count += 1
        error_info = {
            'error': str(error),
            'type': type(error).__name__,
            'context': context,
            'timestamp': datetime.now().isoformat()
        }
        
        self.last_errors.append(error_info)
        if len(self.last_errors) > 10:
            self.last_errors.pop(0)
        
        if critical:
            self.logger.critical(f"CRITICAL ERROR in {context}: {error}", exc_info=True)
        else:
            self.logger.error(f"Error in {context}: {error}", exc_info=True)
        
        # Return suggested action
        if isinstance(error, FileNotFoundError):
            return "check_file_path"
        elif isinstance(error, PermissionError):
            return "check_permissions"
        elif "printer" in str(error).lower():
            return "check_printer"
        else:
            return "retry"
    
    def get_error_summary(self):
        """Get summary of recent errors"""
        return {
            'total_errors': self.error_count,
            'recent_errors': self.last_errors[-5:]
        }
    
    def reset_error_count(self):
        """Reset error tracking"""
        self.error_count = 0
        self.last_errors = []