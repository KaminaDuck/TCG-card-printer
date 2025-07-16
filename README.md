# TCG Card Printer

Automated system for printing trading card game cards on a Canon G3270 printer.

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
   - Name: "TCG Card" or "Custom.2.5x3.5in"
   - Margins: 0.1" on all sides (minimum)

4. Update printer name in `config.py` if needed:
   ```python
   PRINTER_NAME = "Canon_G3270"  # Update to match your printer
   ```

## Usage

1. **Run the printer daemon:**
   ```bash
   python tcg_card_printer.py
   ```

2. **Add card images:**
   - Drop TCG card images into the `tcg_cards_input` folder
   - Supported formats: JPG, PNG, BMP, TIFF
   - Images are automatically processed and printed

3. **Monitor progress:**
   - Check console output for status
   - View detailed logs in `logs/` directory

## Docker Usage

### Building the Container

Build the Docker image locally:

```bash
docker build -t tcg-card-printer .
```

For specific platforms:
```bash
docker build --platform linux/amd64 -t tcg-card-printer .
```

### Running with Docker

Basic docker run command with required volume mounts:

```bash
docker run -d \
  --name tcg-printer \
  -v $(pwd)/tcg_cards_input:/app/tcg_cards_input \
  -v $(pwd)/processed:/app/processed \
  -v $(pwd)/logs:/app/logs \
  -v /var/run/cups/cups.sock:/var/run/cups/cups.sock \
  -e TCG_PRINTER_NAME="Canon_G3070_series" \
  -e TCG_AUTO_DELETE="false" \
  -e PYTHONUNBUFFERED=1 \
  tcg-card-printer
```

**Volume Mount Explanation:**
- `tcg_cards_input`: Input folder where you drop card images
- `processed`: Folder where processed images are stored (optional)
- `logs`: Application logs for debugging (optional)
- `/var/run/cups/cups.sock`: CUPS socket for printer access (required)

### Running with Docker Compose

The easiest way to run the container is using the provided `docker-compose.yml`:

```bash
# Start the container
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the container
docker-compose down
```

**Customizing Volume Paths:**

Edit `docker-compose.yml` to match your host system paths:

```yaml
volumes:
  - /path/to/your/input:/app/tcg_cards_input
  - /path/to/your/processed:/app/processed
  - /path/to/your/logs:/app/logs
```

### Container Configuration

**Available Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `TCG_WATCH_FOLDER` | Input folder path | `/app/tcg_cards_input` |
| `TCG_PROCESSED_FOLDER` | Processed folder path | `/app/processed` |
| `TCG_LOG_DIR` | Log directory path | `/app/logs` |
| `TCG_PRINTER_NAME` | CUPS printer name | `Canon_G3070_series` |
| `TCG_AUTO_DELETE` | Delete after print | `false` |
| `TCG_DPI` | Print resolution | `300` |
| `PYTHONUNBUFFERED` | Real-time logging | `1` |

**Printer Setup for Containers:**

1. Ensure CUPS is running on the host system
2. Configure printer and custom paper size on the host
3. Verify printer name with `lpstat -p`
4. Update `TCG_PRINTER_NAME` environment variable to match

### Troubleshooting Container Issues

**Volume Mount Permission Issues:**
```bash
# Fix permissions on host directories
chmod 755 tcg_cards_input processed logs
```

**CUPS Connectivity Problems:**
- Ensure CUPS socket exists: `ls -la /var/run/cups/cups.sock`
- Check CUPS service: `sudo systemctl status cups`
- Verify container can access socket: `docker exec tcg-printer ls -la /var/run/cups/`

**Container Networking:**
- The container uses host CUPS socket, not network access
- No port mapping required

**Log Access and Debugging:**
```bash
# View container logs
docker logs tcg-printer

# Access container shell
docker exec -it tcg-printer /bin/bash

# Check application logs
docker exec tcg-printer cat /app/logs/tcg_printer.log
```

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
tcg-card-printer/
├── tcg_card_printer.py    # Main application
├── config.py              # Configuration settings
├── folder_monitor.py      # File system monitoring
├── image_processor.py     # Image resizing/optimization
├── print_controller.py    # Printer communication
├── logger_setup.py        # Logging configuration
├── test_printer.py        # Test suite
├── requirements.txt       # Python dependencies
├── tcg_cards_input/       # Drop card images here
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
