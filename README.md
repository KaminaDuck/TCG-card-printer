# MTG Card Printer

Automated system for printing Magic: The Gathering card images on a Canon G3270 printer.

## Features

- **Automatic folder monitoring** - Drop images and they print automatically
- **Smart image processing** - Resizes and optimizes images to 2.5"x3.5" at 300 DPI
- **Print queue management** - Handles multiple cards and printer availability
- **Error handling & logging** - Comprehensive logging and error recovery
- **Border minimization** - Optimizes layout within printer constraints

## Requirements

- Python 3.8+
- Canon G3270 printer (or compatible)
- CUPS printing system (pre-installed on macOS/Linux)
- Card stock paper (2.5" x 3.5")

## Installation

1. Clone or download this project
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Configure printer settings:
   - Add custom paper size (2.5" x 3.5") in printer settings
   - On macOS: System Preferences > Printers & Scanners > Canon G3270 > Options & Supplies > Options
   - Name: "MTG Card" or "Custom.2.5x3.5in"
   - Margins: 0.1" on all sides (minimum)

4. Update printer name in `config.py` if needed:
   ```python
   PRINTER_NAME = "Canon_G3270"  # Update to match your printer
   ```

## Usage

1. **Run the printer daemon:**
   ```bash
   python mtg_card_printer.py
   ```

2. **Add card images:**
   - Drop MTG card images into the `mtg_cards_input` folder
   - Supported formats: JPG, PNG, BMP, TIFF
   - Images are automatically processed and printed

3. **Monitor progress:**
   - Check console output for status
   - View detailed logs in `logs/` directory

## Testing

Run the test suite to verify setup:
```bash
python test_printer.py
```

This will test:
- Image processing capabilities
- Printer connection
- Optional test print

## File Structure

```
mtg-card-printer/
├── mtg_card_printer.py    # Main application
├── config.py              # Configuration settings
├── folder_monitor.py      # File system monitoring
├── image_processor.py     # Image resizing/optimization
├── print_controller.py    # Printer communication
├── logger_setup.py        # Logging configuration
├── test_printer.py        # Test suite
├── requirements.txt       # Python dependencies
├── mtg_cards_input/       # Drop card images here
├── processed/             # Processed images stored here
└── logs/                  # Application logs
```

## Configuration Options

Edit `config.py` to customize:

- `WATCH_FOLDER` - Input folder location
- `TARGET_WIDTH/HEIGHT` - Card dimensions (default: 750x1050 pixels)
- `DPI` - Print resolution (default: 300)
- `AUTO_DELETE_AFTER_PRINT` - Delete originals after printing
- `OPTIMIZE_FOR_PRINT` - Apply print optimizations
- `JPEG_QUALITY` - Output quality for JPEG files

## Troubleshooting

### Printer Not Found
- Run `lpstat -p` to list available printers
- Update `PRINTER_NAME` in config.py to match

### Custom Paper Size Issues
- Ensure custom size is properly configured in system settings
- Try using "Letter" size for testing
- Check printer minimum margin requirements

### Print Quality Issues
- Ensure using 300 DPI images
- Use high-quality card stock
- Set media type to "Cardstock" in printer settings
- Clean printer heads if colors appear faded

### Permission Errors
- Ensure user has printer access rights
- Check file permissions on input/output folders

## Notes

- The Canon G3270 cannot print borderless on custom paper sizes
- Minimum margins are approximately 0.1-0.2 inches
- For best results, use images already sized to 2.5"x3.5" aspect ratio
- The system will center and scale images to minimize white borders

## License

This project is provided as-is for personal use.

---

For issues or questions, check the logs in the `logs/` directory for detailed error information.