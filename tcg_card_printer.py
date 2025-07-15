#!/usr/bin/env python3
"""Main TCG Card Printer Application"""

import sys
import signal
import time
import logging
from pathlib import Path

from logger_setup import setup_logging, ErrorHandler
from folder_monitor import FolderMonitor
from image_processor import ImageProcessor
from print_controller import PrintController
import config

# Setup logging first
setup_logging()
logger = logging.getLogger(__name__)


class TCGCardPrinter:
    """Main application orchestrator"""
    
    def __init__(self):
        self.error_handler = ErrorHandler()
        self.image_processor = ImageProcessor()
        self.print_controller = None
        self.folder_monitor = None
        self.running = False
        self.print_queue = []
        
        # Setup signal handlers
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        logger.info(f"Received signal {signum}, shutting down...")
        self.stop()
        sys.exit(0)
    
    def initialize(self):
        """Initialize all components"""
        logger.info("Initializing TCG Card Printer...")
        
        # Initialize print controller
        try:
            self.print_controller = PrintController()
            printer_status = self.print_controller.get_printer_status()
            
            if printer_status.get('is_ready'):
                logger.info(f"Printer ready: {printer_status['name']}")
            else:
                logger.warning(f"Printer not ready: {printer_status}")
            
            # Attempt to setup custom paper size
            self.print_controller.setup_custom_paper_size()
            
        except Exception as e:
            self.error_handler.handle_error(e, "printer initialization", critical=True)
            raise
        
        # Initialize folder monitor
        self.folder_monitor = FolderMonitor(
            config.WATCH_FOLDER,
            self._process_and_print
        )
        
        logger.info("Initialization complete")
    
    def _process_and_print(self, image_path):
        """Process an image and send it to print"""
        try:
            # Process the image
            logger.info(f"Processing image: {image_path.name}")
            processed_path = self.image_processor.process_image(image_path)
            
            # Check printer status
            status = self.print_controller.get_printer_status()
            if not status.get('is_ready'):
                logger.warning(f"Printer not ready, queuing: {processed_path.name}")
                self.print_queue.append(processed_path)
                return
            
            # Print the processed image
            job_id = self.print_controller.print_image(processed_path)
            logger.info(f"Sent to printer: {processed_path.name} (Job ID: {job_id})")
            
            # Monitor print job
            self._monitor_print_job(job_id, processed_path)
            
            # Delete original if configured
            if config.AUTO_DELETE_AFTER_PRINT:
                image_path.unlink()
                logger.info(f"Deleted original: {image_path.name}")
            
        except Exception as e:
            action = self.error_handler.handle_error(e, f"processing {image_path.name}")
            
            if action == "retry":
                logger.info(f"Will retry {image_path.name} later")
                self.print_queue.append(image_path)
    
    def _monitor_print_job(self, job_id, image_path, timeout=60):
        """Monitor a print job until completion"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            job_status = self.print_controller.get_job_status(job_id)
            
            if job_status is None:
                # Job completed or removed
                logger.info(f"Print completed: {image_path.name}")
                break
            
            job_state = job_status.get('job-state', 0)
            if job_state >= 7:  # Cancelled or aborted
                logger.error(f"Print job failed: {image_path.name}")
                break
            
            time.sleep(2)
    
    def _process_print_queue(self):
        """Process any queued print jobs"""
        if not self.print_queue:
            return
        
        status = self.print_controller.get_printer_status()
        if not status.get('is_ready'):
            return
        
        # Process queued items
        while self.print_queue and status.get('is_ready'):
            item = self.print_queue.pop(0)
            logger.info(f"Processing queued item: {item.name}")
            self._process_and_print(item)
            status = self.print_controller.get_printer_status()
    
    def run(self):
        """Run the main application loop"""
        self.running = True
        
        try:
            # Process any existing files
            self.folder_monitor.process_existing_files()
            
            # Start monitoring
            self.folder_monitor.start()
            
            logger.info("TCG Card Printer is running. Drop card images into:")
            logger.info(f"  {config.WATCH_FOLDER}")
            logger.info("Press Ctrl+C to stop.")
            
            # Main loop
            while self.running:
                # Process print queue periodically
                self._process_print_queue()
                
                # Sleep to prevent busy waiting
                time.sleep(5)
                
        except KeyboardInterrupt:
            logger.info("Received keyboard interrupt")
        except Exception as e:
            self.error_handler.handle_error(e, "main loop", critical=True)
            raise
        finally:
            self.stop()
    
    def stop(self):
        """Stop the application"""
        logger.info("Stopping TCG Card Printer...")
        self.running = False
        
        if self.folder_monitor:
            self.folder_monitor.stop()
        
        # Log final status
        error_summary = self.error_handler.get_error_summary()
        if error_summary['total_errors'] > 0:
            logger.warning(f"Session ended with {error_summary['total_errors']} errors")
        
        logger.info("TCG Card Printer stopped")


def main():
    """Main entry point"""
    print("TCG Card Printer v1.0")
    print("=" * 50)
    
    try:
        app = TCGCardPrinter()
        app.initialize()
        app.run()
    except Exception as e:
        logger.critical(f"Failed to start: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
