#!/usr/bin/env python3
"""Test script for MTG Card Printer components"""

import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

from logger_setup import setup_logging
from image_processor import ImageProcessor
from print_controller import PrintController
import config

# Setup logging
setup_logging()
import logging
logger = logging.getLogger(__name__)


def create_test_card(output_path, text="TEST CARD"):
    """Create a test MTG card image"""
    # Create a test image with MTG card dimensions
    img = Image.new('RGB', (750, 1050), color='white')
    draw = ImageDraw.Draw(img)
    
    # Draw border
    border_width = 20
    draw.rectangle([border_width, border_width, 750-border_width, 1050-border_width], 
                   outline='black', width=3)
    
    # Add text in center
    try:
        # Try to use a better font if available
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 60)
    except:
        font = ImageFont.load_default()
    
    # Calculate text position
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    position = ((750 - text_width) // 2, (1050 - text_height) // 2)
    
    draw.text(position, text, fill='black', font=font)
    
    # Add some card-like elements
    draw.rectangle([50, 50, 700, 150], outline='black', width=2)  # Title box
    draw.rectangle([50, 850, 700, 1000], outline='black', width=2)  # Text box
    
    # Save the test image
    img.save(output_path, dpi=(300, 300))
    logger.info(f"Created test card: {output_path}")


def test_image_processor():
    """Test the image processor"""
    logger.info("Testing Image Processor...")
    
    # Create test image
    test_input = Path("test_card_input.png")
    create_test_card(test_input, "PROCESSOR TEST")
    
    # Process the image
    processor = ImageProcessor()
    output_path = processor.process_image(test_input)
    
    # Verify output
    if output_path.exists():
        img = Image.open(output_path)
        logger.info(f"Processed image size: {img.size}")
        logger.info(f"Expected size: ({config.TARGET_WIDTH}, {config.TARGET_HEIGHT})")
        
        if img.size == (config.TARGET_WIDTH, config.TARGET_HEIGHT):
            logger.info("✓ Image processor test PASSED")
            return True
        else:
            logger.error("✗ Image processor test FAILED - incorrect size")
            return False
    else:
        logger.error("✗ Image processor test FAILED - no output")
        return False


def test_printer_connection():
    """Test printer connection"""
    logger.info("Testing Printer Connection...")
    
    try:
        controller = PrintController()
        status = controller.get_printer_status()
        
        if 'error' in status:
            logger.error(f"✗ Printer connection test FAILED: {status['error']}")
            return False
        
        logger.info(f"Printer: {status['name']}")
        logger.info(f"State: {status['state']} ({'Ready' if status['is_ready'] else 'Not Ready'})")
        logger.info(f"Info: {status['info']}")
        
        if status['state_reasons']:
            logger.info(f"State reasons: {status['state_reasons']}")
        
        logger.info("✓ Printer connection test PASSED")
        return True
        
    except Exception as e:
        logger.error(f"✗ Printer connection test FAILED: {e}")
        return False


def test_print_sample():
    """Test printing a sample card"""
    logger.info("Testing Print Sample...")
    
    try:
        # Create test card
        test_card = config.PROCESSED_FOLDER / "test_print_card.png"
        create_test_card(test_card, "PRINT TEST")
        
        # Try to print
        controller = PrintController()
        job_id = controller.print_image(test_card, {
            'MediaType': 'Plain',  # Use plain paper for testing
            'ColorModel': 'Gray',  # Grayscale to save ink
        })
        
        logger.info(f"✓ Print job submitted: {job_id}")
        logger.info("Check your printer for the test page")
        return True
        
    except Exception as e:
        logger.error(f"✗ Print test FAILED: {e}")
        return False


def main():
    """Run all tests"""
    print("\nMTG Card Printer Test Suite")
    print("=" * 50)
    
    tests = [
        ("Image Processor", test_image_processor),
        ("Printer Connection", test_printer_connection),
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\n{test_name}:")
        try:
            passed = test_func()
            results.append((test_name, passed))
        except Exception as e:
            logger.error(f"Test crashed: {e}")
            results.append((test_name, False))
    
    # Summary
    print("\n" + "=" * 50)
    print("Test Summary:")
    passed = sum(1 for _, p in results if p)
    total = len(results)
    
    for test_name, passed in results:
        status = "PASSED" if passed else "FAILED"
        print(f"  {test_name}: {status}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    # Ask about print test
    if passed == total:
        response = input("\nAll tests passed! Would you like to print a test card? (y/n): ")
        if response.lower() == 'y':
            test_print_sample()


if __name__ == "__main__":
    main()