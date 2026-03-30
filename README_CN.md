# 数字水印平台

[中文](README_CN.md) | [English](README.md)

一个专业的跨平台数字水印系统，提供6种先进图像水印算法和零宽字符文本水印技术。

## 功能特性

### 图像水印（6种先进算法）

| 算法 | 全称 | 鲁棒性 | 适用场景 |
|------|------|--------|----------|
| **LSB** | 最低有效位替换 | ★☆☆☆☆ | 无损传输、快速验证 |
| **DCT** | 离散余弦变换 | ★★★☆☆ | JPEG图像、网络传输 |
| **DWT** | 离散小波变换 | ★★★★☆ | 高质量图像、专业应用 |
| **DWT-SVD** | 小波+SVD混合 | ★★★★★ | 高安全需求、版权保护 |
| **QIM** | 量化索引调制 | ★★★★☆ | 抗攻击需求、学术研究 |
| **SS** | 扩频水印 | ★★★★★ | 军事/商业高安全场景 |

### 算法验证结果

| 攻击类型 | LSB | DCT | DWT | DWT-SVD | QIM | SS |
|---------|-----|-----|-----|---------|-----|-----|
| JPEG Q90 | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| JPEG Q50 | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 噪声 N20 | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 裁剪 90% | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ |

### 文本水印

使用**零宽字符**技术，在不改变文本显示效果的前提下嵌入水印信息。

- 在文本中嵌入隐藏水印
- 从含水印文本中提取水印
- 清除文本中的水印
- 对原文显示效果无影响

### 可调节嵌入强度

不同算法支持自定义嵌入强度，平衡图像质量与鲁棒性。

| 算法 | 范围 | 默认值 | 说明 |
|------|------|--------|------|
| DCT | 20-100 | 50 | 系数差值强度 |
| DWT | 40-150 | 80 | 系数差值强度 |
| DWT-SVD | 0.01-0.1 | 0.03 | 修改比例 |
| QIM | 15-60 | 30 | 量化步长 |
| SS | 5-30 | 15 | 扩频强度 |

### 盲水印检测

当提取失败时，系统会进行盲水印检测并提供：

- **置信度评分**：水印存在的概率（0-100%）
- **最佳匹配算法**：检测置信度最高的算法建议
- **跨算法检测**：分析所有算法的水印特征

### 图片追踪溯源

基于SQLite数据库的图片记录系统：

- 自动记录每张图片的哈希值
- 重复检测并显示历史记录
- 操作统计和算法使用分布
- 水印历史追踪

## 快速开始

### 服务端部署

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

服务运行在 `http://0.0.0.0:8000`

### 客户端构建

```bash
cd client
flutter pub get

# 构建 Android 版本
flutter build apk --release

# 构建 iOS 版本
flutter build ios --release

# 构建 Web 版本
flutter build web --release
```

## API 接口

### 文本水印

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

### 图像水印

```bash
# 嵌入水印
POST /api/image/embed
FormData:
  - image: 图像文件
  - watermark: 水印文本
  - algorithm: LSB | DCT | DWT | DWT-SVD | QIM | SS
  - strength: (可选) 嵌入强度

响应头:
  - x-image-hash: 原图哈希
  - x-image-known: 图片是否已被处理过
  - x-previous-info: 历史处理信息 (JSON)
  - x-watermark-algorithm: 使用的算法
  - x-watermark-strength: 嵌入强度

# 提取水印
POST /api/image/extract
FormData:
  - image: 图像文件
  - algorithm: 水印算法
  - strength: (QIM和DWT-SVD需要) 嵌入强度

响应:
{
  "success": true,
  "watermark": "提取的水印",
  "message": "提取信息",
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
    "watermark": "存储的水印",
    "algorithm": "DWT-SVD",
    "created": "2024-01-01 12:00:00"
  }
}

# 获取支持的算法
GET /api/image/algorithms

# 获取统计信息
GET /api/image/statistics
```

## 项目结构

```
project/
├── client/                  # Flutter 客户端 (Android/iOS/Web)
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
├── server/                  # Python 服务端
│   ├── app/
│   │   ├── main.py
│   │   ├── routers/
│   │   │   ├── text_watermark.py
│   │   │   └── image_watermark.py
│   │   └── services/
│   │       ├── text_wm.py
│   │       ├── image_wm.py
│   │       └── image_record.py
│   ├── watermark.db          # SQLite 数据库
│   ├── requirements.txt
│   └── run.py
│
└── Watermark/               # 参考实现
    ├── script/
    │   ├── blind_watermark.py
    │   └── watermark_invisiable.py
    └── test.py
```

## 技术实现

### DWT-SVD 混合算法（推荐）

1. 对图像进行 Haar 小波 2 级分解
2. 在低频 LL2 子带进行差分嵌入
3. 使用系数对的大小关系表示水印位
4. 高冗余度（32倍）确保稳定性
5. 抗 JPEG 压缩、噪声和裁剪攻击

### QIM 量化索引调制

1. 对图像进行 Haar 小波 2 级分解
2. 在中频 LH2 子带进行差分嵌入
3. 根据水印位调整相邻系数关系
4. 理论上最优的鲁棒性-容量权衡

### SS 扩频水印

1. 对图像进行 DCT 变换
2. 在中频区域（频谱的1/4到1/2）嵌入
3. 类似通信扩频技术
4. 安全性高，难以检测和移除

### 盲检测算法

系统分析多种统计特征：

- **LSB**：熵值分析和 UTF-8 有效性检查
- **DCT**：中频系数模式分析
- **DWT**：小波系数符号一致性
- **DWT-SVD**：低频系数差分模式
- **QIM**：量化残留分析
- **SS**：系数对相关性分析

## 依赖说明

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

## 安全说明

1. **文本水印**：零宽字符可能在某些系统中被过滤，适合低安全场景

2. **图像水印**：
   - LSB 易受压缩攻击，仅适合快速验证
   - DCT/DWT/QIM/SS 抗压缩，适合保存传播
   - DWT-SVD 鲁棒性最强，推荐用于版权保护

3. **通信安全**：生产环境建议使用 HTTPS

## 许可证

MIT License

## 版本

- 客户端: 1.2.0
- 服务端: 1.2.0
- 支持 SDK: Flutter 3.11.3+, Python 3.10+