# Digital Watermark Platform

A cross-platform digital watermark system supporting multiple advanced algorithms for text and image watermarking.

[English](#english) | [中文](#chinese)

---

<a name="chinese"></a>
## 中文文档

### 功能特性

#### 文本水印
使用**零宽字符**技术，在不改变文本显示效果的前提下嵌入水印信息。

| 功能 | 说明 |
|------|------|
| 嵌入水印 | 在文本末尾嵌入隐藏水印 |
| 提取水印 | 从含水印文本中提取隐藏信息 |
| 移除水印 | 清除文本中的零宽字符水印 |

#### 图像水印（6种先进算法）

| 算法 | 全称 | 特点 | 鲁棒性 | 适用场景 |
|------|------|------|--------|----------|
| **LSB** | 最低有效位替换 | 容量大，脆弱 | ★☆☆☆☆ | 无损传输、版权标记 |
| **DCT** | 离散余弦变换 | 抗JPEG压缩 | ★★★☆☆ | JPEG图像、网络传输 |
| **DWT** | 离散小波变换 | 综合鲁棒性 | ★★★★☆ | 高质量图像、专业应用 |
| **DWT-SVD** | 小波+SVD混合 | 极强鲁棒性 | ★★★★★ | 高安全需求、版权保护 |
| **QIM** | 量化索引调制 | 最先进方法 | ★★★★☆ | 抗攻击需求、学术研究 |
| **SS** | 扩频水印 | 高安全性 | ★★★★★ | 军事/商业高安全场景 |

**算法验证结果：**

| 攻击类型 | LSB | DCT | DWT | DWT-SVD | QIM | SS |
|---------|-----|-----|-----|---------|-----|-----|
| JPEG Q90 | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| JPEG Q50 | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 噪声 N20 | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 裁剪 90% | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ |

#### 可调节嵌入强度

不同算法支持自定义嵌入强度，平衡图像质量与鲁棒性：

| 算法 | 强度范围 | 默认值 | 说明 |
|------|---------|--------|------|
| DCT | 20-100 | 50 | 系数差值强度 |
| DWT | 40-150 | 80 | 系数差值强度 |
| DWT-SVD | 0.01-0.1 | 0.03 | 修改比例 |
| QIM | 15-60 | 30 | 量化步长 |
| SS | 5-30 | 15 | 扩频强度 |

#### 图片追踪溯源

基于 SQLite 数据库的图片记录系统：

- **嵌入记录**：自动记录原始图片哈希、水印内容、算法、强度
- **重复检测**：检测图片是否已被处理，显示历史记录
- **统计信息**：支持查看操作统计、算法使用分布

---

### 项目结构

```
project/
├── client/                  # Flutter 客户端 (支持 Android/iOS/Web)
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
└── server/                  # Python 服务端
    ├── app/
    │   ├── main.py
    │   ├── routers/
    │   │   ├── text_watermark.py
    │   │   └── image_watermark.py
    │   └── services/
    │       ├── text_wm.py
    │       ├── image_wm.py
    │       └── image_record.py
    ├── watermark.db          # SQLite 数据库
    ├── requirements.txt
    └── run.py
```

---

### API 接口

#### 文本水印

```bash
# 嵌入水印
POST /api/text/embed
Body: {"text": "原文", "watermark": "水印内容"}
Response: {"watermarked_text": "含水印文本"}

# 提取水印
POST /api/text/extract
Body: {"text": "含水印文本"}
Response: {"watermark": "提取的水印"}

# 移除水印
POST /api/text/remove
Body: {"text": "含水印文本"}
Response: {"cleaned_text": "清洁文本"}
```

#### 图像水印

```bash
# 嵌入水印
POST /api/image/embed
FormData: image, watermark, algorithm, strength(可选)
Response Headers:
  - x-image-hash: 原图哈希
  - x-watermark-algorithm: 使用的算法
  - x-watermark-strength: 嵌入强度

# 提取水印
POST /api/image/extract
FormData: image, algorithm, strength(QIM算法需要)
Response: {
  "success": true,
  "watermark": "提取的水印",
  "image_hash": "图片哈希",
  "is_watermarked": true,
  "record_info": {...}
}

# 获取算法列表
GET /api/image/algorithms
Response: {
  "algorithms": ["LSB", "DCT", "DWT", "DWT-SVD", "QIM", "SS"],
  "strength_ranges": {...},
  "default_strength": {...}
}

# 获取统计信息
GET /api/image/statistics
Response: {
  "original_images": 100,
  "watermarked_images": 150,
  "total_operations": 150,
  "algorithm_stats": {"DCT": 50, "DWT-SVD": 80, ...}
}
```

---

### 部署指南

#### 服务端

```bash
cd server
python -m venv venv

# Windows
venv\Scripts\activate
# Linux/Mac
source venv/bin/activate

pip install -r requirements.txt
python run.py
```

服务运行在 `http://0.0.0.0:8000`

#### 客户端

```bash
cd client
flutter pub get

# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

---

### 技术实现

#### 图像水印算法原理

**DWT-SVD 混合算法（推荐）：**
1. 对图像进行 Haar 小波 3 级分解
2. 在低频 LL3 子带进行差分嵌入
3. 使用系数对的大小关系表示水印位
4. 高冗余度（8x）确保稳定性

**QIM 量化索引调制：**
1. 对图像进行 Haar 小波 2 级分解
2. 在中频 LH2 子带进行差分嵌入
3. 根据水印位调整相邻系数关系

**SS 扩频水印：**
1. 对图像进行 DCT 变换
2. 在中频区域进行差分嵌入
3. 类似通信扩频技术，安全性高

---

### 依赖说明

**Python 服务端：**
```
fastapi>=0.110.0
uvicorn>=0.27.0
numpy>=1.26.0
opencv-python>=4.9.0
PyWavelets>=1.5.0
scipy>=1.12.0
python-multipart>=0.0.9
```

**Flutter 客户端：**
```yaml
http: ^1.2.0
file_picker: ^8.0.0
path_provider: ^2.1.2
share_plus: ^7.2.1
permission_handler: ^11.3.0
gal: ^2.3.0
shared_preferences: ^2.2.2
```

---

### 安全说明

1. **文本水印**：零宽字符可能在某些系统中被过滤，适合低安全场景
2. **图像水印**：
   - LSB 易受压缩攻击，仅适合即时验证
   - DCT/DWT/QIM/SS 抗压缩，适合保存传播
   - DWT-SVD 鲁棒性最强，推荐用于版权保护
3. **通信安全**：建议生产环境使用 HTTPS

---

