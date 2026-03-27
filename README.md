# 数字水印平台

一个轻量级数字水印系统，支持文本和图像水印的嵌入与提取。

## 项目结构

```
project/
├── client/                  # Flutter 客户端
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   ├── text_watermark_screen.dart
│   │   │   └── image_watermark_screen.dart
│   │   ├── services/
│   │   │   └── api_service.dart
│   │   └── utils/
│   │       ├── platform_utils.dart
│   │       ├── platform_utils_io.dart
│   │       └── platform_utils_web.dart
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
    ├── image_records.json
    ├── requirements.txt
    └── run.py
```

---

## 功能特性

### 文本水印

使用**零宽字符**技术，在不改变文本显示效果的前提下嵌入水印信息。

| 功能 | 说明 |
|------|------|
| 嵌入水印 | 在文本末尾嵌入隐藏水印 |
| 提取水印 | 从含水印文本中提取隐藏信息 |
| 移除水印 | 清除文本中的零宽字符水印 |

**零宽字符集：**
| 字符 | Unicode | 二进制值 |
|------|---------|----------|
| U+200B | 零宽空格 | 00 |
| U+200C | 零宽非连接符 | 01 |
| U+200D | 零宽连接符 | 10 |
| U+FEFF | 字节顺序标记 | 11 |

### 图像水印

支持三种频域算法，适应不同使用场景：

| 算法 | 特点 | 适用场景 |
|------|------|----------|
| **LSB** | 最低有效位替换 | 即时验证，不保存 |
| **DCT** | 离散余弦变换，抗JPEG压缩 | 保存后提取（推荐） |
| **DWT** | 离散小波变换，抗压缩 | 保存后提取 |

**算法对比：**

| 算法 | 直接提取 | JPEG压缩后 | 容量 | 鲁棒性 |
|------|---------|-----------|------|--------|
| LSB | ✅ | ❌ | 大 | 低 |
| DCT | ✅ | ✅ | 中 | 高 |
| DWT | ✅ | ✅ | 中 | 高 |

### 图片追踪

服务端自动记录图片哈希，支持溯源：

- **嵌入时**：记录原始图片哈希、水印内容、算法
- **再次嵌入**：检测图片是否已被处理，提示历史记录
- **提取时**：显示图片是否为水印后图片，显示来源信息

---

## 客户端界面

### 服务器配置

- **右上角状态栏**：显示连接状态（已连接/未连接）
- **设置按钮**：点击配置服务器地址
- **配置持久化**：自动保存配置，重启App后自动加载


---

## 技术实现

### 文本水印算法

```python
# 水印文本转二进制
def text_to_bits(text):
    data = text.encode('utf-8')
    return ''.join(format(b, '08b') for b in data)

# 二进制转零宽字符
zero_width_chars = {'00': '\u200B', '01': '\u200C', '10': '\u200D', '11': '\uFEFF'}

# 嵌入到原文本末尾
watermarked_text = original_text + zero_width_watermark
```

### 图像水印算法

#### LSB（最低有效位）

```python
# 将水印bit嵌入像素最低位
for i, bit in enumerate(watermark_bits):
    pixel[i] = (pixel[i] & 0xFE) | int(bit)
```

#### DCT（离散余弦变换）

```python
# 8x8块DCT变换，修改系数对关系
if bit == '1':
    dct_block[1,1] = avg + delta
    dct_block[2,2] = avg - delta
```

#### DWT（离散小波变换）

```python
# Haar小波3级分解，HH高频子带冗余嵌入
# 每个bit嵌入8次，多数投票提取
```

### 图片哈希记录

```python
# 计算图片SHA256哈希（取前16位）
image_hash = hashlib.sha256(image_bytes).hexdigest()[:16]

# 记录结构
{
    "hash": {
        "first_seen": "2026-03-27 21:00:00",
        "watermarks": [{"watermark": "...", "algorithm": "DCT"}]
    }
}
```

---

## API 接口

### 文本水印

```
POST /api/text/embed
Body: {"text": "原文", "watermark": "水印内容"}
Response: {"watermarked_text": "含水印文本"}

POST /api/text/extract
Body: {"text": "含水印文本"}
Response: {"watermark": "提取的水印"}

POST /api/text/remove
Body: {"text": "含水印文本"}
Response: {"cleaned_text": "清洁文本"}
```

### 图像水印

```
POST /api/image/embed
FormData: image, watermark, algorithm
Response Headers:
  - x-image-hash: 原图哈希
  - x-image-known: 是否已记录 (true/false)
  - x-previous-info: 历史记录JSON

POST /api/image/extract
FormData: image, algorithm
Response: {
  "watermark": "提取的水印",
  "image_hash": "图片哈希",
  "is_watermarked": true,
  "record_info": {"source_hash": "...", "created": "..."}
}
```

---

## 部署指南

### 服务端

```bash
cd server
python -m venv venv
venv\Scripts\activate  # Windows
pip install -r requirements.txt
python run.py
```

服务运行在 `http://0.0.0.0:8000`

### 客户端

```bash
cd client
flutter pub get
flutter build apk --release
```

---

## 依赖说明

### Python 服务端

```
fastapi>=0.109.0
uvicorn>=0.27.0
numpy>=1.26.0
opencv-python>=4.9.0
PyWavelets>=1.5.0
scipy>=1.12.0
python-multipart>=0.0.6
```

### Flutter 客户端

```yaml
dependencies:
  http: ^1.2.0           # HTTP请求
  file_picker: ^8.0.0    # 文件选择
  path_provider: ^2.1.2  # 路径获取
  share_plus: ^7.2.1     # 分享功能
  permission_handler: ^11.3.0  # 权限管理
  gal: ^2.3.0            # 相册保存
  shared_preferences: ^2.2.2  # 配置持久化
```

---

## 安全说明

1. **文本水印**：零宽字符可能在某些系统中被过滤，适合低安全场景
2. **图像水印**：
   - LSB 易受压缩攻击，仅适合即时验证
   - DCT/DWT 抗压缩，适合保存传播
3. **通信安全**：建议生产环境使用HTTPS

---

## 版本信息

- 客户端版本：1.0.0
- 支持SDK：Flutter 3.11.3+, Python 3.10+