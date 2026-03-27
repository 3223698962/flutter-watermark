"""
图像水印服务 - 支持多种算法
LSB: 最低有效位替换
DCT: 离散余弦变换域
DWT: 离散小波变换域
"""

import cv2
import numpy as np
import hashlib
from typing import Tuple, Dict
import pywt
from scipy.fftpack import dct, idct


class ImageWatermarkService:
    ALGORITHMS = ['LSB', 'DCT', 'DWT']

    # 嵌入强度参数
    DELTA = {'DCT': 30, 'DWT': 25}  # 提高DWT强度以增强鲁棒性

    def _text_to_bits(self, text: str) -> str:
        """文本转二进制，添加长度头"""
        data = text.encode('utf-8')
        length = len(data)
        # 2字节长度 + 数据
        header = format(length, '016b')
        body = ''.join(format(b, '08b') for b in data)
        return header + body

    def _bits_to_text(self, bits: str) -> Dict:
        """二进制转文本"""
        if len(bits) < 16:
            return {"success": False, "watermark": None, "message": "数据不足"}

        length = int(bits[:16], 2)
        # 放宽长度限制，允许更长的水印
        if length == 0 or length > 10000:
            return {"success": False, "watermark": None, "message": "未检测到有效水印，图像可能被压缩或修改"}

        data_bits = bits[16:16 + length * 8]
        if len(data_bits) < length * 8:
            return {"success": False, "watermark": None, "message": "数据不完整"}

        data = bytearray()
        for i in range(0, length * 8, 8):
            data.append(int(data_bits[i:i+8], 2))

        try:
            return {"success": True, "watermark": data.decode('utf-8'), "message": "水印提取成功"}
        except:
            return {"success": False, "watermark": None, "message": "解码失败，图像可能被修改"}

    # ==================== LSB ====================
    def _embed_lsb(self, img_bytes: bytes, text: str) -> Tuple[bytes, str]:
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("无法解析图像")

        wm_hash = hashlib.md5(text.encode()).hexdigest()[:16]
        bits = self._text_to_bits(text)

        flat = img.flatten()
        for i, b in enumerate(bits):
            flat[i] = (flat[i] & 0xFE) | int(b)

        img = flat.reshape(img.shape)
        _, enc = cv2.imencode('.png', img)
        return enc.tobytes(), wm_hash

    def _extract_lsb(self, img_bytes: bytes) -> Dict:
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return {"success": False, "message": "无法解析图像"}

        bits = ''.join(str(p & 1) for p in img.flatten())
        return self._bits_to_text(bits)

    # ==================== DCT ====================
    def _embed_dct(self, img_bytes: bytes, text: str) -> Tuple[bytes, str]:
        """DCT域水印 - 使用块内系数关系"""
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("无法解析图像")

        wm_hash = hashlib.md5(text.encode()).hexdigest()[:16]
        bits = self._text_to_bits(text)

        # 使用Y通道
        yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
        y = yuv[:, :, 0]

        h, w = y.shape
        idx = 0
        delta = 15  # 差值

        for i in range(0, h - 8, 8):
            for j in range(0, w - 8, 8):
                if idx >= len(bits):
                    break

                block = y[i:i+8, j:j+8]
                dct_block = dct(dct(block.T, norm='ortho').T, norm='ortho')

                # 使用(1,1)和(2,2)系数的关系嵌入
                c1 = dct_block[1, 1]
                c2 = dct_block[2, 2]
                avg = (c1 + c2) / 2

                if bits[idx] == '1':
                    dct_block[1, 1] = avg + delta
                    dct_block[2, 2] = avg - delta
                else:
                    dct_block[1, 1] = avg - delta
                    dct_block[2, 2] = avg + delta

                y[i:i+8, j:j+8] = idct(idct(dct_block.T, norm='ortho').T, norm='ortho')
                idx += 1
            if idx >= len(bits):
                break

        yuv[:, :, 0] = np.clip(y, 0, 255).astype(np.uint8)
        result = cv2.cvtColor(yuv.astype(np.uint8), cv2.COLOR_YUV2BGR)

        _, enc = cv2.imencode('.png', result)
        return enc.tobytes(), wm_hash

    def _extract_dct(self, img_bytes: bytes) -> Dict:
        """DCT域水印提取"""
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return {"success": False, "message": "无法解析图像"}

        yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
        y = yuv[:, :, 0]

        h, w = y.shape

        bits = ''
        for i in range(0, h - 8, 8):
            for j in range(0, w - 8, 8):
                block = y[i:i+8, j:j+8]
                dct_block = dct(dct(block.T, norm='ortho').T, norm='ortho')

                c1 = dct_block[1, 1]
                c2 = dct_block[2, 2]

                if c1 > c2:
                    bits += '1'
                else:
                    bits += '0'

                result = self._bits_to_text(bits)
                if result.get('success'):
                    return result

        return self._bits_to_text(bits)

    # ==================== DWT ====================
    def _embed_dwt(self, img_bytes: bytes, text: str) -> Tuple[bytes, str]:
        """DWT域水印 - 使用高频子带冗余嵌入"""
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("无法解析图像")

        wm_hash = hashlib.md5(text.encode()).hexdigest()[:16]
        bits = self._text_to_bits(text)

        # 使用Y通道
        yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
        y = yuv[:, :, 0]

        # 小波分解
        coeffs = pywt.wavedec2(y, 'haar', level=3)
        # 使用HH子带 (高频，对压缩更鲁棒)
        HH = coeffs[3][2].copy()  # level 3的HH分量
        flat = HH.flatten()

        # 冗余嵌入: 每个bit嵌入到8个系数对
        redundancy = 8
        delta = 50  # 更大的差值

        for i, bit in enumerate(bits):
            base_idx = i * 2 * redundancy
            if base_idx + 2 * redundancy > len(flat):
                break
            for j in range(redundancy):
                idx = base_idx + j * 2
                c1, c2 = flat[idx], flat[idx + 1]
                avg = (c1 + c2) / 2
                if bit == '1':
                    flat[idx] = avg + delta
                    flat[idx + 1] = avg - delta
                else:
                    flat[idx] = avg - delta
                    flat[idx + 1] = avg + delta

        # 重建HH
        new_HH = flat.reshape(HH.shape)
        new_coeffs = [coeffs[0], coeffs[1], coeffs[2], (coeffs[3][0], coeffs[3][1], new_HH)]
        y_new = pywt.waverec2(new_coeffs, 'haar')
        y_new = y_new[:img.shape[0], :img.shape[1]]

        yuv[:, :, 0] = np.clip(y_new, 0, 255).astype(np.uint8)
        result = cv2.cvtColor(yuv.astype(np.uint8), cv2.COLOR_YUV2BGR)

        _, enc = cv2.imencode('.png', result)
        return enc.tobytes(), wm_hash

    def _extract_dwt(self, img_bytes: bytes) -> Dict:
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return {"success": False, "message": "无法解析图像"}

        yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
        y = yuv[:, :, 0]

        coeffs = pywt.wavedec2(y, 'haar', level=3)
        HH = coeffs[3][2]
        flat = HH.flatten()

        redundancy = 8
        bits = ''
        max_bits = len(flat) // (2 * redundancy)

        for i in range(max_bits):
            base_idx = i * 2 * redundancy
            if base_idx + 2 * redundancy > len(flat):
                break

            # 多数投票
            votes = 0
            for j in range(redundancy):
                idx = base_idx + j * 2
                if flat[idx] > flat[idx + 1]:
                    votes += 1

            bits += '1' if votes > redundancy // 2 else '0'

            result = self._bits_to_text(bits)
            if result.get('success'):
                return result

        return self._bits_to_text(bits)

    # ==================== 统一接口 ====================
    def embed_watermark(self, img_bytes: bytes, text: str, algo: str = 'LSB') -> Tuple[bytes, str]:
        algo = algo.upper()
        if algo == 'LSB':
            return self._embed_lsb(img_bytes, text)
        elif algo == 'DCT':
            return self._embed_dct(img_bytes, text)
        elif algo == 'DWT':
            return self._embed_dwt(img_bytes, text)
        raise ValueError(f"不支持算法: {algo}")

    def extract_watermark(self, img_bytes: bytes, algo: str = 'LSB') -> Dict:
        algo = algo.upper()
        if algo == 'LSB':
            return self._extract_lsb(img_bytes)
        elif algo == 'DCT':
            return self._extract_dct(img_bytes)
        elif algo == 'DWT':
            return self._extract_dwt(img_bytes)
        return {"success": False, "watermark": None, "message": f"不支持算法: {algo}"}


image_watermark_service = ImageWatermarkService()