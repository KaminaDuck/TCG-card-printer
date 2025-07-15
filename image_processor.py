"""Image processing module for TCG card preparation"""

import logging
from pathlib import Path
from PIL import Image, ImageOps
import config

logger = logging.getLogger(__name__)


class ImageProcessor:
    """Process TCG card images for optimal printing"""
    
    def __init__(self, target_width=config.TARGET_WIDTH, target_height=config.TARGET_HEIGHT):
        self.target_width = target_width
        self.target_height = target_height
        self.target_aspect = target_width / target_height
    
    def process_image(self, input_path, output_path=None):
        """Process a single card image"""
        input_path = Path(input_path)
        
        if output_path is None:
            output_path = config.PROCESSED_FOLDER / f"print_{input_path.name}"
        else:
            output_path = Path(output_path)
        
        logger.info(f"Processing image: {input_path.name}")
        
        try:
            # Open the image
            with Image.open(input_path) as img:
                # Convert to RGB if necessary (handles transparency)
                if img.mode in ('RGBA', 'LA', 'P'):
                    rgb_img = Image.new('RGB', img.size, (255, 255, 255))
                    if img.mode == 'P':
                        img = img.convert('RGBA')
                    rgb_img.paste(img, mask=img.split()[-1] if 'A' in img.mode else None)
                    img = rgb_img
                elif img.mode != 'RGB':
                    img = img.convert('RGB')
                
                # Process the image
                processed = self._smart_resize_crop(img)
                
                # Apply print optimization if enabled
                if config.OPTIMIZE_FOR_PRINT:
                    processed = self._optimize_for_print(processed)
                
                # Save the processed image
                save_kwargs = {'dpi': (config.DPI, config.DPI)}
                if output_path.suffix.lower() in ['.jpg', '.jpeg']:
                    save_kwargs['quality'] = config.JPEG_QUALITY
                    save_kwargs['optimize'] = True
                
                processed.save(output_path, **save_kwargs)
                logger.info(f"Saved processed image: {output_path.name}")
                
                return output_path
                
        except Exception as e:
            logger.error(f"Error processing image {input_path.name}: {e}")
            raise
    
    def _smart_resize_crop(self, img):
        """Intelligently resize and crop image to target dimensions"""
        orig_width, orig_height = img.size
        orig_aspect = orig_width / orig_height
        
        # Determine scaling strategy
        if abs(orig_aspect - self.target_aspect) < 0.1:
            # Aspect ratios are close, simple resize
            return img.resize((self.target_width, self.target_height), Image.Resampling.LANCZOS)
        
        # Calculate scale to fill target completely (may crop)
        scale = max(self.target_width / orig_width, self.target_height / orig_height)
        
        # Scale the image
        new_width = int(orig_width * scale)
        new_height = int(orig_height * scale)
        img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
        
        # Center crop to target dimensions
        left = (new_width - self.target_width) // 2
        top = (new_height - self.target_height) // 2
        right = left + self.target_width
        bottom = top + self.target_height
        
        return img.crop((left, top, right, bottom))
    
    def _optimize_for_print(self, img):
        """Apply optimizations for better print quality"""
        # Auto-contrast to improve print output
        img = ImageOps.autocontrast(img, cutoff=0.5)
        
        # Slight sharpening for card stock
        from PIL import ImageEnhance
        enhancer = ImageEnhance.Sharpness(img)
        img = enhancer.enhance(1.2)
        
        return img
    
    def batch_process(self, input_folder, output_folder=None):
        """Process all images in a folder"""
        input_folder = Path(input_folder)
        
        if output_folder is None:
            output_folder = config.PROCESSED_FOLDER
        else:
            output_folder = Path(output_folder)
        
        output_folder.mkdir(exist_ok=True)
        
        processed_count = 0
        for file_path in input_folder.iterdir():
            if file_path.suffix.lower() in config.SUPPORTED_FORMATS:
                try:
                    output_path = output_folder / f"print_{file_path.name}"
                    self.process_image(file_path, output_path)
                    processed_count += 1
                except Exception as e:
                    logger.error(f"Failed to process {file_path.name}: {e}")
        
        logger.info(f"Batch processing complete. Processed {processed_count} images.")
        return processed_count
