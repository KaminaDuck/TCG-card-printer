"""Print controller module for Canon G3270"""

import logging
import cups
import tempfile
from pathlib import Path
import subprocess
import platform
import config

logger = logging.getLogger(__name__)


class PrintController:
    """Control printing to Canon G3270"""
    
    def __init__(self, printer_name=None):
        self.printer_name = printer_name or config.PRINTER_NAME
        self.conn = None
        self._connect()
    
    def _connect(self):
        """Establish connection to CUPS"""
        try:
            self.conn = cups.Connection()
            printers = self.conn.getPrinters()
            
            if self.printer_name not in printers:
                # Try to find Canon G3270 by partial name match
                canon_printers = [p for p in printers if 'Canon' in p and 'G3270' in p]
                if canon_printers:
                    self.printer_name = canon_printers[0]
                    logger.info(f"Found Canon G3270 as: {self.printer_name}")
                else:
                    available = ', '.join(printers.keys())
                    raise ValueError(f"Printer '{self.printer_name}' not found. Available: {available}")
            
            logger.info(f"Connected to printer: {self.printer_name}")
            
        except Exception as e:
            logger.error(f"Failed to connect to CUPS: {e}")
            raise
    
    def print_image(self, image_path, options=None):
        """Print a single image"""
        image_path = Path(image_path)
        
        if not image_path.exists():
            raise FileNotFoundError(f"Image not found: {image_path}")
        
        # Default print options for MTG cards
        print_options = {
            'media': 'Custom.2.5x3.5in',  # Custom paper size
            'MediaType': 'Cardstock',      # Media type
            'Resolution': '300dpi',        # Print resolution
            'ColorModel': 'RGB',           # Color model
            'PageSize': 'Custom.2.5x3.5in', # Ensure custom size
            'FitToPage': 'False',          # Don't auto-fit
            'Scaling': '100',              # No scaling
        }
        
        # Update with any custom options
        if options:
            print_options.update(options)
        
        try:
            # Print the file
            job_id = self.conn.printFile(
                self.printer_name,
                str(image_path),
                f"MTG Card - {image_path.stem}",
                print_options
            )
            
            logger.info(f"Print job submitted: {job_id} for {image_path.name}")
            return job_id
            
        except Exception as e:
            logger.error(f"Failed to print {image_path.name}: {e}")
            raise
    
    def setup_custom_paper_size(self):
        """Setup custom paper size for MTG cards"""
        # This is system-specific and may require manual setup
        logger.info("Setting up custom paper size (2.5x3.5 inches)...")
        
        if platform.system() == "Darwin":  # macOS
            # On macOS, custom paper sizes are typically added through System Preferences
            logger.info("On macOS, please add custom paper size through:")
            logger.info("System Preferences > Printers & Scanners > Your Printer > Options & Supplies > Options > Custom Size")
            logger.info("Name: MTG Card")
            logger.info("Width: 2.5 inches (63.5 mm)")
            logger.info("Height: 3.5 inches (88.9 mm)")
            logger.info("Margins: 0.1 inches (2.54 mm) on all sides")
        else:
            # Linux - can often be done via lpadmin
            try:
                cmd = [
                    'lpadmin', '-p', self.printer_name,
                    '-o', 'PageSize=Custom.2.5x3.5in'
                ]
                subprocess.run(cmd, check=True)
                logger.info("Custom paper size configured via lpadmin")
            except subprocess.CalledProcessError as e:
                logger.warning(f"Could not set custom size via lpadmin: {e}")
                logger.info("Please configure custom paper size manually in your printer settings")
    
    def get_printer_status(self):
        """Get current printer status"""
        try:
            printers = self.conn.getPrinters()
            if self.printer_name in printers:
                printer_info = printers[self.printer_name]
                state = printer_info.get('printer-state', 'unknown')
                state_reasons = printer_info.get('printer-state-reasons', [])
                
                status = {
                    'name': self.printer_name,
                    'state': state,
                    'state_reasons': state_reasons,
                    'is_ready': state == 3,  # 3 = idle/ready
                    'location': printer_info.get('printer-location', 'Not set'),
                    'info': printer_info.get('printer-info', 'No description')
                }
                
                return status
            else:
                return {'error': f'Printer {self.printer_name} not found'}
                
        except Exception as e:
            logger.error(f"Failed to get printer status: {e}")
            return {'error': str(e)}
    
    def cancel_job(self, job_id):
        """Cancel a print job"""
        try:
            self.conn.cancelJob(job_id)
            logger.info(f"Cancelled job: {job_id}")
        except Exception as e:
            logger.error(f"Failed to cancel job {job_id}: {e}")
            raise
    
    def get_job_status(self, job_id):
        """Get status of a print job"""
        try:
            jobs = self.conn.getJobs()
            if job_id in jobs:
                return jobs[job_id]
            else:
                return None
        except Exception as e:
            logger.error(f"Failed to get job status: {e}")
            return None