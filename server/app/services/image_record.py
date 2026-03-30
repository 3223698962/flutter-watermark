"""
图片哈希记录服务 - SQLite版本
记录原始图片哈希，用于追踪图片来源
"""

import hashlib
import sqlite3
import os
from datetime import datetime
from typing import Optional, Dict, List
from contextlib import contextmanager

# 数据库文件路径
DB_FILE = os.path.join(os.path.dirname(__file__), '..', '..', 'watermark.db')


class ImageRecordService:
    def __init__(self):
        self._init_db()

    @contextmanager
    def _get_connection(self):
        """获取数据库连接的上下文管理器"""
        conn = sqlite3.connect(DB_FILE)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
            conn.commit()
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    def _init_db(self):
        """初始化数据库表"""
        with self._get_connection() as conn:
            cursor = conn.cursor()

            # 原始图片表
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS original_images (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    image_hash TEXT UNIQUE NOT NULL,
                    first_seen TEXT NOT NULL,
                    file_name TEXT,
                    file_size INTEGER,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
            ''')

            # 水印记录表
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS watermark_records (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    original_hash TEXT NOT NULL,
                    watermark_text TEXT NOT NULL,
                    algorithm TEXT NOT NULL,
                    strength REAL,
                    watermarked_hash TEXT NOT NULL,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (original_hash) REFERENCES original_images(image_hash)
                )
            ''')

            # 水印图片表 (记录生成的水印图片)
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS watermarked_images (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    image_hash TEXT UNIQUE NOT NULL,
                    source_hash TEXT NOT NULL,
                    watermark_text TEXT NOT NULL,
                    algorithm TEXT NOT NULL,
                    strength REAL,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (source_hash) REFERENCES original_images(image_hash)
                )
            ''')

            # 创建索引
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_original_hash ON original_images(image_hash)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_watermarked_hash ON watermarked_images(image_hash)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_source_hash ON watermarked_images(source_hash)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_original_watermark ON watermark_records(original_hash)')

    def compute_hash(self, image_bytes: bytes) -> str:
        """计算图片SHA256哈希"""
        return hashlib.sha256(image_bytes).hexdigest()[:16]

    def record_original_image(self, image_hash: str, file_name: str = None, file_size: int = None) -> bool:
        """记录原始图片"""
        now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        with self._get_connection() as conn:
            cursor = conn.cursor()
            try:
                cursor.execute('''
                    INSERT INTO original_images (image_hash, first_seen, file_name, file_size)
                    VALUES (?, ?, ?, ?)
                ''', (image_hash, now, file_name, file_size))
                return True
            except sqlite3.IntegrityError:
                # 已存在
                return False

    def record_watermark(self, original_hash: str, watermark: str, algorithm: str,
                         strength: float, watermarked_hash: str):
        """记录水印操作"""
        now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        with self._get_connection() as conn:
            cursor = conn.cursor()

            # 记录水印操作
            cursor.execute('''
                INSERT INTO watermark_records (original_hash, watermark_text, algorithm, strength, watermarked_hash, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (original_hash, watermark, algorithm, strength, watermarked_hash, now))

            # 记录水印图片
            cursor.execute('''
                INSERT INTO watermarked_images (image_hash, source_hash, watermark_text, algorithm, strength, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (watermarked_hash, original_hash, watermark, algorithm, strength, now))

    def lookup_original(self, image_hash: str) -> Optional[Dict]:
        """查找原始图片记录"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM original_images WHERE image_hash = ?', (image_hash,))
            row = cursor.fetchone()
            if row:
                return dict(row)
            return None

    def lookup_watermarked(self, image_hash: str) -> Optional[Dict]:
        """查找水印图片记录"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM watermarked_images WHERE image_hash = ?', (image_hash,))
            row = cursor.fetchone()
            if row:
                return dict(row)
            return None

    def get_watermark_count(self, original_hash: str) -> int:
        """获取原始图片的水印次数"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT COUNT(*) as count FROM watermark_records WHERE original_hash = ?', (original_hash,))
            row = cursor.fetchone()
            return row['count'] if row else 0

    def get_watermark_history(self, original_hash: str, limit: int = 10) -> List[Dict]:
        """获取水印历史记录"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT * FROM watermark_records
                WHERE original_hash = ?
                ORDER BY created_at DESC
                LIMIT ?
            ''', (original_hash, limit))
            return [dict(row) for row in cursor.fetchall()]

    def check_and_record_embed(self, original_bytes: bytes, watermark: str,
                                algorithm: str, watermarked_bytes: bytes,
                                strength: float = None, filename: str = None) -> dict:
        """
        检查并记录嵌入操作
        返回: {original_hash, watermarked_hash, is_known, previous_info}
        """
        original_hash = self.compute_hash(original_bytes)
        watermarked_hash = self.compute_hash(watermarked_bytes)

        # 检查原始图片是否已知
        existing = self.lookup_original(original_hash)
        is_known = existing is not None
        previous_info = None

        if is_known:
            watermark_count = self.get_watermark_count(original_hash)
            previous_info = {
                "first_seen": existing.get("first_seen"),
                "watermark_count": watermark_count
            }
        else:
            # 记录新的原始图片
            file_size = len(original_bytes)
            self.record_original_image(original_hash, filename, file_size)

        # 记录此次水印操作
        self.record_watermark(original_hash, watermark, algorithm, strength, watermarked_hash)

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

        # 先检查是否是水印图片
        watermarked_record = self.lookup_watermarked(image_hash)
        if watermarked_record:
            return {
                "hash": image_hash,
                "is_watermarked": True,
                "info": {
                    "source_hash": watermarked_record.get("source_hash"),
                    "watermark": watermarked_record.get("watermark_text"),
                    "algorithm": watermarked_record.get("algorithm"),
                    "strength": watermarked_record.get("strength"),
                    "created": watermarked_record.get("created_at")
                }
            }

        # 检查是否是原始图片
        original_record = self.lookup_original(image_hash)
        if original_record:
            watermark_count = self.get_watermark_count(image_hash)
            return {
                "hash": image_hash,
                "is_watermarked": False,
                "info": {
                    "watermark_count": watermark_count,
                    "first_seen": original_record.get("first_seen")
                }
            }

        # 未知图片
        return {
            "hash": image_hash,
            "is_watermarked": False,
            "info": None
        }

    def get_statistics(self) -> Dict:
        """获取统计信息"""
        with self._get_connection() as conn:
            cursor = conn.cursor()

            # 原始图片数量
            cursor.execute('SELECT COUNT(*) as count FROM original_images')
            original_count = cursor.fetchone()['count']

            # 水印图片数量
            cursor.execute('SELECT COUNT(*) as count FROM watermarked_images')
            watermarked_count = cursor.fetchone()['count']

            # 水印操作总数
            cursor.execute('SELECT COUNT(*) as count FROM watermark_records')
            total_operations = cursor.fetchone()['count']

            # 各算法使用统计
            cursor.execute('''
                SELECT algorithm, COUNT(*) as count
                FROM watermark_records
                GROUP BY algorithm
                ORDER BY count DESC
            ''')
            algorithm_stats = {row['algorithm']: row['count'] for row in cursor.fetchall()}

            # 最近7天的操作数
            cursor.execute('''
                SELECT COUNT(*) as count FROM watermark_records
                WHERE created_at >= date('now', '-7 days')
            ''')
            recent_operations = cursor.fetchone()['count']

            return {
                "original_images": original_count,
                "watermarked_images": watermarked_count,
                "total_operations": total_operations,
                "algorithm_stats": algorithm_stats,
                "recent_operations": recent_operations
            }

    def cleanup_old_records(self, days: int = 90) -> int:
        """清理旧记录（可选功能）"""
        with self._get_connection() as conn:
            cursor = conn.cursor()

            # 删除旧的水印图片记录
            cursor.execute('''
                DELETE FROM watermarked_images
                WHERE created_at < date('now', ?)
            ''', (f'-{days} days',))

            # 删除没有关联水印记录的原始图片
            cursor.execute('''
                DELETE FROM original_images
                WHERE image_hash NOT IN (SELECT DISTINCT original_hash FROM watermark_records)
            ''')

            return cursor.rowcount


image_record_service = ImageRecordService()