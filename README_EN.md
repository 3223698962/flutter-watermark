# Digital Watermark Platform

A lightweight digital watermark system supporting text and image watermark embedding & extraction.

## Features

### Text Watermark
- Uses **zero-width characters** technique
- Embed, extract, and remove hidden watermarks
- Invisible to viewers

### Image Watermark
Three algorithms available:

| Algorithm | Robustness | Use Case |
|-----------|------------|----------|
| LSB | Low | Quick verification |
| DCT | High (JPEG resistant) | Recommended for sharing |
| DWT | High (compression resistant) | Long-term storage |

### Image Tracking
- Automatic hash recording for provenance
- Detect previously watermarked images

## Tech Stack

**Client:** Flutter (Android/Web)

**Server:** Python + FastAPI

## Quick Start

### Server
```bash
cd server
python -m venv venv
venv\Scripts\activate  # Windows
pip install -r requirements.txt
python run.py
```
Server runs at `http://0.0.0.0:8000`

### Client
```bash
cd client
flutter pub get
flutter run
```

## API Endpoints

```
POST /api/text/embed    - Embed text watermark
POST /api/text/extract  - Extract text watermark
POST /api/text/remove   - Remove text watermark

POST /api/image/embed   - Embed image watermark
POST /api/image/extract - Extract image watermark
```

## License

MIT