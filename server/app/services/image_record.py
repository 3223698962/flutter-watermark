"""
图片哈希记录服务
记录原始图片哈希，用于追踪图片来源
"""

import hashlib
import json
import os
from datetime import datetime
from typing import Optional, Dict

# 记录文件路径
RECORD_FILE = os.path.join(os.path.dirname(__file__), '..', '..', 'image_records.json')


class ImageRecordService:
    def __init__(self):
        self.records: Dict[str, dict] = {}
        self._load_records()

    def _load_records(self):
        """加载记录文件"""
        if os.path.exists(RECORD_FILE):
            try:
                with open(RECORD_FILE, 'r', encoding='utf-8') as f:
                    self.records = json.load(f)
            except:
                self.records = {}

    def _save_records(self):
        """保存记录文件"""
        try:
            with open(RECORD_FILE, 'w', encoding='utf-8') as f:
                json.dump(self.records, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"保存记录失败: {e}")

    def compute_hash(self, image_bytes: bytes) -> str:
        """计算图片SHA256哈希"""
        return hashlib.sha256(image_bytes).hexdigest()[:16]

    def record_image(self, original_hash: str, watermark: str, algorithm: str, watermarked_hash: str):
        """记录图片水印信息"""
        now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        # 记录原始图片
        if original_hash not in self.records:
            self.records[original_hash] = {
                "first_seen": now,
                "watermarks": []
            }

        self.records[original_hash]["watermarks"].append({
            "watermark": watermark,
            "algorithm": algorithm,
            "watermarked_hash": watermarked_hash,
            "time": now
        })

        # 记录水印图片
        self.records[watermarked_hash] = {
            "first_seen": now,
            "source_hash": original_hash,
            "watermark": watermark,
            "algorithm": algorithm
        }

        self._save_records()

    def lookup(self, image_hash: str) -> Optional[dict]:
        """查找图片记录"""
        return self.records.get(image_hash)

    def check_and_record_embed(self, original_bytes: bytes, watermark: str, algorithm: str, watermarked_bytes: bytes) -> dict:
        """
        检查并记录嵌入操作
        返回: {original_hash, watermarked_hash, is_known, previous_info}
        """
        original_hash = self.compute_hash(original_bytes)
        watermarked_hash = self.compute_hash(watermarked_bytes)

        # 检查原始图片是否已知
        existing = self.lookup(original_hash)
        is_known = existing is not None
        previous_info = None

        if is_known:
            previous_info = {
                "first_seen": existing.get("first_seen"),
                "watermark_count": len(existing.get("watermarks", []))
            }

        # 记录此次操作
        self.record_image(original_hash, watermark, algorithm, watermarked_hash)

        return {
            "original_hash": original_hash,
            "watermarked_hash": watermarked_hash,
            "is_known": is_known,
            "previous_info": previous_info
        }

    def check_extract(self, image_bytes: bytes) -> dict:
        """
        检查提取时的图片信息
        返回: {hash, is_watermarked, info}
        """
        image_hash = self.compute_hash(image_bytes)
        record = self.lookup(image_hash)

        if record is None:
            return {
                "hash": image_hash,
                "is_watermarked": False,
                "info": None
            }

        # 检查是否是水印后的图片
        if "source_hash" in record:
            return {
                "hash": image_hash,
                "is_watermarked": True,
                "info": {
                    "source_hash": record.get("source_hash"),
                    "watermark": record.get("watermark"),
                    "algorithm": record.get("algorithm"),
                    "created": record.get("first_seen")
                }
            }
        else:
            # 原始图片
            return {
                "hash": image_hash,
                "is_watermarked": False,
                "info": {
                    "watermark_count": len(record.get("watermarks", [])),
                    "first_seen": record.get("first_seen")
                }
            }


image_record_service = ImageRecordService()