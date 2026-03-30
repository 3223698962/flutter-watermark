# Digital Watermark Platform

[中文文档](README.md) | English

A professional cross-platform digital watermark system with 6 advanced algorithms for image watermarking and zero-width character technology for text watermarking.

## Features

### Image Watermarking (6 Advanced Algorithms)

| Algorithm | Full Name | Robustness | Best For |
|-----------|-----------|------------|----------|
| **LSB** | Least Significant Bit | ★☆☆☆☆ | Lossless transmission, quick verification |
| **DCT** | Discrete Cosine Transform | ★★★☆☆ | JPEG images, web transmission |
| **DWT** | Discrete Wavelet Transform | ★★★★☆ | High-quality images, professional use |
| **DWT-SVD** | Wavelet + SVD Hybrid | ★★★★★ | High-security needs, copyright protection |
| **QIM** | Quantization Index Modulation | ★★★★☆ | Anti-attack requirements, academic research |
| **SS** | Spread Spectrum | ★★★★★ | Military/commercial high-security scenarios |

### Algorithm Verification Results

| Attack Type | LSB | DCT | DWT | DWT-SVD | QIM | SS |
|-------------|-----|-----|-----|---------|-----|-----|
| JPEG Q90 | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| JPEG Q50 | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Noise N20 | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Crop 90% | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ |

### Text Watermarking
- Embed invisible watermarks using zero-width characters
- Extract and remove watermarks from text
- No visual change to the original text

### Adjustable Embedding Strength

| Algorithm | Range | Default | Description |
|-----------|-------|---------|-------------|
| DCT | 20-100 | 50 | Coefficient difference |
| DWT | 40-150 | 80 | Coefficient difference |
| DWT-SVD | 0.01-0.1 | 0.03 | Modification ratio |
| QIM | 15-60 | 30 | Quantization step |
| SS | 5-30 | 15 | Spread spectrum strength |

### Image Tracking System
- SQLite database for image records
- Automatic hash tracking for provenance
- Duplicate detection and history display
- Operation statistics and algorithm distribution

## Quick Start

### Server Setup

```bash
cd server
python -m venv venv

# Windows
venv\Scripts\activate
# Linux/macOS
source venv/bin/activate

pip install -r requirements.txt
python run.py
```

Server runs at `http://0.0.0.0:8000`

### Client Setup

```bash
cd client
flutter pub get

# Build for Android
flutter build apk --release

# Build for iOS
flutter build ios --release

# Build for Web
flutter build web --release
```

## API Reference

### Text Watermark

```bash
POST /api/text/embed
Body: {"text": "original text", "watermark": "watermark content"}
Response: {"watermarked_text": "text with watermark"}

POST /api/text/extract
Body: {"text": "text with watermark"}
Response: {"watermark": "extracted watermark"}

POST /api/text/remove
Body: {"text": "text with watermark"}
Response: {"cleaned_text": "clean text"}
```

### Image Watermark

```bash
# Embed watermark
POST /api/image/embed
FormData:
  - image: image file
  - watermark: watermark text
  - algorithm: LSB | DCT | DWT | DWT-SVD | QIM | SS
  - strength: (optional) embedding strength

Response Headers:
  - x-image-hash: original image hash
  - x-watermark-algorithm: algorithm used
  - x-watermark-strength: embedding strength

# Extract watermark
POST /api/image/extract
FormData:
  - image: image file
  - algorithm: watermark algorithm
  - strength: (required for QIM) embedding strength

Response:
{
  "success": true,
  "watermark": "extracted watermark",
  "image_hash": "image hash",
  "is_watermarked": true,
  "record_info": {...}
}

# Get supported algorithms
GET /api/image/algorithms

# Get statistics
GET /api/image/statistics
```

## Project Structure

```
project/
├── client/                  # Flutter client (Android/iOS/Web)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   ├── services/
│   │   └── utils/
│   └── pubspec.yaml
│
└── server/                  # Python server
    ├── app/
    │   ├── main.py
    │   ├── routers/
    │   └── services/
    ├── watermark.db          # SQLite database
    ├── requirements.txt
    └── run.py
```

## Technical Details

### DWT-SVD Hybrid Algorithm (Recommended)

1. Perform Haar wavelet 3-level decomposition
2. Embed watermark in low-frequency LL3 subband
3. Use coefficient pair relationships to represent watermark bits
4. High redundancy (8x) ensures stability

### QIM (Quantization Index Modulation)

1. Perform Haar wavelet 2-level decomposition
2. Embed in mid-frequency LH2 subband
3. Adjust adjacent coefficient relationships based on watermark bits
4. Theoretically optimal robustness-capacity trade-off

### SS (Spread Spectrum)

1. Apply DCT transform to the image
2. Embed in mid-frequency region
3. Similar to communication spread spectrum technology
4. High security, difficult to detect and remove

## Dependencies

**Python Server:**
```
fastapi>=0.110.0
uvicorn>=0.27.0
numpy>=1.26.0
opencv-python>=4.9.0
PyWavelets>=1.5.0
scipy>=1.12.0
python-multipart>=0.0.9
```

**Flutter Client:**
```yaml
http: ^1.2.0
file_picker: ^8.0.0
path_provider: ^2.1.2
share_plus: ^7.2.1
permission_handler: ^11.3.0
gal: ^2.3.0
shared_preferences: ^2.2.2
```

## Security Notes

1. **Text Watermark**: Zero-width characters may be filtered in some systems
2. **Image Watermark**:
   - LSB is fragile to compression, suitable for quick verification only
   - DCT/DWT/QIM/SS resist compression, suitable for distribution
   - DWT-SVD has the strongest robustness, recommended for copyright protection
3. **Communication**: Use HTTPS in production environments

## License

MIT License

## Version

- Client: 1.1.0
- Server: 1.1.0
- Supported SDK: Flutter 3.11.3+, Python 3.10+