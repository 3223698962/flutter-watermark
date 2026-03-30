# Digital Watermark Platform

[English](README.md) | [中文](README_CN.md)

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

Uses **Zero-Width Characters** to embed invisible watermarks without changing text display.

- Embed watermark into text
- Extract watermark from text
- Remove watermark from text
- No visual change to the original text

### Adjustable Embedding Strength

Balance between image quality and robustness with configurable strength parameters.

| Algorithm | Range | Default | Description |
|-----------|-------|---------|-------------|
| DCT | 20-100 | 50 | Coefficient difference |
| DWT | 40-150 | 80 | Coefficient difference |
| DWT-SVD | 0.01-0.1 | 0.03 | Modification ratio |
| QIM | 15-60 | 30 | Quantization step |
| SS | 5-30 | 15 | Spread spectrum strength |

### Blind Watermark Detection

When extraction fails, the system performs blind watermark detection and provides:

- **Confidence Score**: Probability of watermark presence (0-100%)
- **Best Match Algorithm**: Suggested algorithm with highest detection confidence
- **Cross-Algorithm Detection**: Analyzes watermark features across all algorithms

### Image Tracking System

SQLite-based image record system for provenance tracking:

- Automatic hash recording for each image
- Duplicate detection with history display
- Operation statistics and algorithm distribution
- Watermark history tracking

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
# Embed watermark
POST /api/text/embed
Body: {"text": "original text", "watermark": "watermark content"}
Response: {"watermarked_text": "text with watermark"}

# Extract watermark
POST /api/text/extract
Body: {"text": "text with watermark"}
Response: {"watermark": "extracted watermark"}

# Remove watermark
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
  - x-image-known: whether image was seen before
  - x-previous-info: previous processing info (JSON)
  - x-watermark-algorithm: algorithm used
  - x-watermark-strength: embedding strength

# Extract watermark
POST /api/image/extract
FormData:
  - image: image file
  - algorithm: watermark algorithm
  - strength: (required for QIM and DWT-SVD) embedding strength

Response:
{
  "success": true,
  "watermark": "extracted watermark",
  "message": "extraction message",
  "confidence": 0.85,
  "detection": {
    "confidence": 0.85,
    "best_match": "DWT-SVD",
    "best_confidence": 0.92,
    "has_watermark": true
  },
  "image_hash": "abc123",
  "is_watermarked": true,
  "record_info": {
    "watermark": "stored watermark",
    "algorithm": "DWT-SVD",
    "created": "2024-01-01 12:00:00"
  }
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
│   │   │   ├── home_screen.dart
│   │   │   ├── text_watermark_screen.dart
│   │   │   └── image_watermark_screen.dart
│   │   ├── services/
│   │   │   └── api_service.dart
│   │   └── utils/
│   └── pubspec.yaml
│
├── server/                  # Python server
│   ├── app/
│   │   ├── main.py
│   │   ├── routers/
│   │   │   ├── text_watermark.py
│   │   │   └── image_watermark.py
│   │   └── services/
│   │       ├── text_wm.py
│   │       ├── image_wm.py
│   │       └── image_record.py
│   ├── watermark.db          # SQLite database
│   ├── requirements.txt
│   └── run.py
│
└── Watermark/               # Reference implementation
    ├── script/
    │   ├── blind_watermark.py
    │   └── watermark_invisiable.py
    └── test.py
```

## Technical Details

### DWT-SVD Hybrid Algorithm (Recommended)

1. Perform Haar wavelet 2-level decomposition
2. Embed watermark in low-frequency LL2 subband
3. Use coefficient pair relationships to represent watermark bits
4. High redundancy (32x) ensures stability
5. Resistant to JPEG compression, noise, and cropping

### QIM (Quantization Index Modulation)

1. Perform Haar wavelet 2-level decomposition
2. Embed in mid-frequency LH2 subband
3. Adjust adjacent coefficient relationships based on watermark bits
4. Theoretically optimal robustness-capacity trade-off

### SS (Spread Spectrum)

1. Apply DCT transform to the image
2. Embed in mid-frequency region (1/4 to 1/2 of spectrum)
3. Similar to communication spread spectrum technology
4. High security, difficult to detect and remove

### Blind Detection Algorithm

The system analyzes multiple statistical features:

- **LSB**: Entropy analysis and UTF-8 validity check
- **DCT**: Mid-frequency coefficient pattern analysis
- **DWT**: Wavelet coefficient sign consistency
- **DWT-SVD**: Low-frequency coefficient difference pattern
- **QIM**: Quantization residue analysis
- **SS**: Coefficient pair correlation analysis

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

1. **Text Watermark**: Zero-width characters may be filtered in some systems, suitable for low-security scenarios

2. **Image Watermark**:
   - LSB is fragile to compression, suitable for quick verification only
   - DCT/DWT/QIM/SS resist compression, suitable for distribution
   - DWT-SVD has the strongest robustness, recommended for copyright protection

3. **Communication**: Use HTTPS in production environments

## License

MIT License

## Version

- Client: 1.2.0
- Server: 1.2.0
- Supported SDK: Flutter 3.11.3+, Python 3.10+