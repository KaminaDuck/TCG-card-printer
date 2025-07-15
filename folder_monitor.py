"""Folder monitoring module using watchdog"""

import logging
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import config

logger = logging.getLogger(__name__)


class CardImageHandler(FileSystemEventHandler):
    """Handler for new card image files"""
    
    def __init__(self, image_processor_callback):
        self.image_processor_callback = image_processor_callback
        self.processed_files = set()
    
    def on_created(self, event):
        """Handle file creation events"""
        if event.is_directory:
            return
        
        self._process_file(event.src_path)
    
    def on_modified(self, event):
        """Handle file modification events"""
        if event.is_directory:
            return
        
        # Only process if we haven't seen this file before
        if event.src_path not in self.processed_files:
            self._process_file(event.src_path)
    
    def _process_file(self, file_path):
        """Process a new or modified file"""
        path = Path(file_path)
        
        # Check if it's a supported image format
        if path.suffix.lower() not in config.SUPPORTED_FORMATS:
            logger.debug(f"Ignoring non-image file: {path.name}")
            return
        
        # Check if file is fully written (sometimes files are created empty)
        try:
            if path.stat().st_size == 0:
                logger.debug(f"Ignoring empty file: {path.name}")
                return
        except:
            return
        
        logger.info(f"New card image detected: {path.name}")
        self.processed_files.add(file_path)
        
        # Call the image processor
        try:
            self.image_processor_callback(path)
        except Exception as e:
            logger.error(f"Error processing {path.name}: {e}")
            # Remove from processed set so it can be retried
            self.processed_files.discard(file_path)


class FolderMonitor:
    """Monitor a folder for new MTG card images"""
    
    def __init__(self, watch_folder, image_processor_callback):
        self.watch_folder = Path(watch_folder)
        self.image_processor_callback = image_processor_callback
        self.observer = Observer()
        self.handler = CardImageHandler(image_processor_callback)
    
    def start(self):
        """Start monitoring the folder"""
        if not self.watch_folder.exists():
            logger.error(f"Watch folder does not exist: {self.watch_folder}")
            raise ValueError(f"Watch folder does not exist: {self.watch_folder}")
        
        self.observer.schedule(self.handler, str(self.watch_folder), recursive=False)
        self.observer.start()
        logger.info(f"Started monitoring folder: {self.watch_folder}")
    
    def stop(self):
        """Stop monitoring the folder"""
        self.observer.stop()
        self.observer.join()
        logger.info("Stopped monitoring folder")
    
    def process_existing_files(self):
        """Process any existing files in the watch folder"""
        logger.info("Processing existing files in watch folder...")
        
        for file_path in self.watch_folder.iterdir():
            if file_path.is_file() and file_path.suffix.lower() in config.SUPPORTED_FORMATS:
                logger.info(f"Processing existing file: {file_path.name}")
                try:
                    self.image_processor_callback(file_path)
                except Exception as e:
                    logger.error(f"Error processing existing file {file_path.name}: {e}")