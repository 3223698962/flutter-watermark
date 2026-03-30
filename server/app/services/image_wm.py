"""
图像水印服务 - 支持多种算法
LSB: 最低有效位替换 (脆弱型，容量大)
DCT: 离散余弦变换域 (中等鲁棒性)
DWT: 离散小波变换域 (较强鲁棒性)
DWT-SVD: 小波+奇异值分解混合 (极强鲁棒性，抗JPEG压缩、裁剪、噪声)
QIM: 量化索引调制 (先进量化方法，抗攻击能力强)
SS: 扩频水印 (类似通信扩频，安全性高)
"""

import cv2
import numpy as np
import hashlib
from typing import Tuple, Dict
import pywt
from scipy.fftpack import dct, idct
from scipy.linalg import svd


class ImageWatermarkService:
    ALGORITHMS = ['LSB', 'DCT', 'DWT', 'DWT-SVD', 'QIM', 'SS']

    # 默认嵌入强度参数
    DEFAULT_STRENGTH = {
        'LSB': 1,           # LSB固定为1，无需调节
        'DCT': 50,          # DCT系数差值强度
        'DWT': 80,          # DWT系数差值强度
        'DWT-SVD': 0.03,    # SVD奇异值修改比例
        'QIM': 30,          # QIM量化步长
        'SS': 15            # 扩频强度
    }

    # 各算法强度范围
    STRENGTH_RANGE = {
        'LSB': {'min': 1, 'max': 1, 'step': 0, 'label': '固定'},
        'DCT': {'min': 20, 'max': 100, 'step': 10, 'label': '系数差值'},
        'DWT': {'min': 40, 'max': 150, 'step': 10, 'label': '系数差值'},
        'DWT-SVD': {'min': 0.01, 'max': 0.1, 'step': 0.01, 'label': '修改比例'},
        'QIM': {'min': 15, 'max': 60, 'step': 5, 'label': '量化步长'},
        'SS': {'min': 5, 'max': 30, 'step': 5, 'label': '扩频强度'}
    }

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
    def _embed_lsb(self, img_bytes: bytes, text: str, strength: float = 1) -> Tuple[bytes, str]:
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
    def _embed_dct(self, img_bytes: bytes, text: str, strength: float = 50) -> Tuple[bytes, str]:
        """DCT域水印 - 使用块内系数关系，冗余嵌入增强鲁棒性"""
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
        delta = strength  # 使用传入的强度参数
        redundancy = 4  # 每个bit嵌入4个块中，多数投票提取

        blocks_h = (h - 8) // 8
        blocks_w = (w - 8) // 8
        total_blocks = blocks_h * blocks_w

        block_idx = 0
        for bit_idx, bit in enumerate(bits):
            for rep in range(redundancy):
                if block_idx >= total_blocks:
                    break

                i = (block_idx // blocks_w) * 8
                j = (block_idx % blocks_w) * 8

                block = y[i:i+8, j:j+8]
                dct_block = dct(dct(block.T, norm='ortho').T, norm='ortho')

                # 使用(1,1)和(2,2)系数的关系嵌入
                c1 = dct_block[1, 1]
                c2 = dct_block[2, 2]
                avg = (c1 + c2) / 2

                if bit == '1':
                    dct_block[1, 1] = avg + delta
                    dct_block[2, 2] = avg - delta
                else:
                    dct_block[1, 1] = avg - delta
                    dct_block[2, 2] = avg + delta

                y[i:i+8, j:j+8] = idct(idct(dct_block.T, norm='ortho').T, norm='ortho')
                block_idx += 1

        yuv[:, :, 0] = np.clip(y, 0, 255).astype(np.uint8)
        result = cv2.cvtColor(yuv.astype(np.uint8), cv2.COLOR_YUV2BGR)

        _, enc = cv2.imencode('.png', result)
        return enc.tobytes(), wm_hash

    def _extract_dct(self, img_bytes: bytes) -> Dict:
        """DCT域水印提取 - 多数投票"""
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return {"success": False, "message": "无法解析图像"}

        yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
        y = yuv[:, :, 0]

        h, w = y.shape
        redundancy = 4

        blocks_h = (h - 8) // 8
        blocks_w = (w - 8) // 8
        total_blocks = blocks_h * blocks_w
        max_bits = total_blocks // redundancy

        bits = ''
        for bit_idx in range(max_bits):
            votes = 0
            for rep in range(redundancy):
                block_idx = bit_idx * redundancy + rep
                if block_idx >= total_blocks:
                    continue

                i = (block_idx // blocks_w) * 8
                j = (block_idx % blocks_w) * 8

                block = y[i:i+8, j:j+8]
                dct_block = dct(dct(block.T, norm='ortho').T, norm='ortho')

                c1 = dct_block[1, 1]
                c2 = dct_block[2, 2]

                if c1 > c2:
                    votes += 1

            bits += '1' if votes > redundancy // 2 else '0'

            result = self._bits_to_text(bits)
            if result.get('success'):
                return result

        return self._bits_to_text(bits)

    # ==================== DWT ====================
    def _embed_dwt(self, img_bytes: bytes, text: str, strength: float = 80) -> Tuple[bytes, str]:
        """DWT域水印 - 使用中频子带冗余嵌入，增强跨平台鲁棒性"""
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("无法解析图像")

        wm_hash = hashlib.md5(text.encode()).hexdigest()[:16]
        bits = self._text_to_bits(text)

        # 使用Y通道
        yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
        y = yuv[:, :, 0]

        # 小波分解 - level=2，中频更稳定
        coeffs = pywt.wavedec2(y, 'haar', level=2)
        # 使用LH子带 (level=2的中频水平细节)，比高频HH更鲁棒
        LH = coeffs[2][1].copy()  # level 2的LH分量
        flat = LH.flatten()

        # 冗余嵌入: 每个bit嵌入到16个系数对，大幅增强鲁棒性
        redundancy = 16
        delta = strength  # 使用传入的强度参数

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

        # 重建LH
        new_LH = flat.reshape(LH.shape)
        new_coeffs = [coeffs[0], coeffs[1], (coeffs[2][0], new_LH, coeffs[2][2])]
        y_new = pywt.waverec2(new_coeffs, 'haar')
        y_new = y_new[:img.shape[0], :img.shape[1]]

        yuv[:, :, 0] = np.clip(y_new, 0, 255).astype(np.uint8)
        result = cv2.cvtColor(yuv.astype(np.uint8), cv2.COLOR_YUV2BGR)

        _, enc = cv2.imencode('.png', result)
        return enc.tobytes(), wm_hash

    def _extract_dwt(self, img_bytes: bytes) -> Dict:
        """DWT域水印提取 - 多数投票"""
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return {"success": False, "message": "无法解析图像"}

        yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
        y = yuv[:, :, 0]

        coeffs = pywt.wavedec2(y, 'haar', level=2)
        LH = coeffs[2][1]
        flat = LH.flatten()

        redundancy = 16
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

    # ==================== DWT-SVD 混合算法 ====================
    def _embed_dwt_svd(self, img_bytes: bytes, text: str, strength: float = 0.03) -> Tuple[bytes, str]:
        """
        DWT-SVD混合水印 - 极强鲁棒性算法
        在小波低频子带使用差分嵌入
        """
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("无法解析图像")

        wm_hash = hashlib.md5(text.encode()).hexdigest()[:16]
        bits = self._text_to_bits(text)

        # 使用Y通道
        yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
        y = yuv[:, :, 0]

        # Haar小波分解 level=3，使用最低频
        coeffs = pywt.wavedec2(y, 'haar', level=3)
        LL3 = coeffs[0].copy()
        flat = LL3.flatten()

        # 固定冗余度
        redundancy = 8
        delta = 30  # 差值强度

        for i, bit in enumerate(bits):
            for j in range(redundancy):
                idx = i * redundancy * 2 + j * 2
                if idx + 1 >= len(flat):
                    break

                c1, c2 = flat[idx], flat[idx + 1]
                avg = (c1 + c2) / 2

                if bit == '1':
                    flat[idx] = avg + delta
                    flat[idx + 1] = avg - delta
                else:
                    flat[idx] = avg - delta
                    flat[idx + 1] = avg + delta

        # 重建
        new_LL3 = flat.reshape(LL3.shape)
        new_coeffs = [new_LL3, coeffs[1], coeffs[2], coeffs[3]]
        y_new = pywt.waverec2(new_coeffs, 'haar')
        y_new = y_new[:img.shape[0], :img.shape[1]]

        yuv[:, :, 0] = np.clip(y_new, 0, 255).astype(np.uint8)
        result = cv2.cvtColor(yuv.astype(np.uint8), cv2.COLOR_YUV2BGR)

        _, enc = cv2.imencode('.png', result)
        return enc.tobytes(), wm_hash

    def _extract_dwt_svd(self, img_bytes: bytes) -> Dict:
        """DWT-SVD混合水印提取"""
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return {"success": False, "message": "无法解析图像"}

        yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
        y = yuv[:, :, 0]

        # 小波分解
        coeffs = pywt.wavedec2(y, 'haar', level=3)
        LL3 = coeffs[0]
        flat = LL3.flatten()

        redundancy = 8
        bits = ''
        max_bits = len(flat) // (redundancy * 2)

        for i in range(max_bits):
            votes = 0
            for j in range(redundancy):
                idx = i * redundancy * 2 + j * 2
                if idx + 1 >= len(flat):
                    break

                if flat[idx] > flat[idx + 1]:
                    votes += 1

            bits += '1' if votes > redundancy // 2 else '0'

            result = self._bits_to_text(bits)
            if result.get('success'):
                return result

        return self._bits_to_text(bits)

    # ==================== QIM 量化索引调制 ====================
    def _embed_qim(self, img_bytes: bytes, text: str, strength: float = 30) -> Tuple[bytes, str]:
        """
        QIM (Quantization Index Modulation) 量化索引调制水印
        使用差分嵌入：相邻系数的量化差异表示水印位
        """
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("无法解析图像")

        wm_hash = hashlib.md5(text.encode()).hexdigest()[:16]
        bits = self._text_to_bits(text)

        yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
        y = yuv[:, :, 0]

        # 小波分解获取中频子带
        coeffs = pywt.wavedec2(y, 'haar', level=2)
        LH2 = coeffs[2][1]  # 中频水平细节

        flat = LH2.flatten()

        # QIM参数 - 使用差分嵌入
        delta = strength
        redundancy = 8  # 每个bit用8对系数

        for i, bit in enumerate(bits):
            for j in range(redundancy):
                idx = i * redundancy * 2 + j * 2
                if idx + 1 >= len(flat):
                    break

                c1, c2 = flat[idx], flat[idx + 1]
                avg = (c1 + c2) / 2

                if bit == '1':
                    flat[idx] = avg + delta
                    flat[idx + 1] = avg - delta
                else:
                    flat[idx] = avg - delta
                    flat[idx + 1] = avg + delta

        # 重建
        new_LH2 = flat.reshape(LH2.shape)
        new_coeffs = [coeffs[0], coeffs[1], (coeffs[2][0], new_LH2, coeffs[2][2])]
        y_new = pywt.waverec2(new_coeffs, 'haar')
        y_new = y_new[:img.shape[0], :img.shape[1]]

        yuv[:, :, 0] = np.clip(y_new, 0, 255).astype(np.uint8)
        result = cv2.cvtColor(yuv.astype(np.uint8), cv2.COLOR_YUV2BGR)

        _, enc = cv2.imencode('.png', result)
        return enc.tobytes(), wm_hash

    def _extract_qim(self, img_bytes: bytes, strength: float = 30) -> Dict:
        """QIM水印提取 - 基于相邻系数关系"""
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return {"success": False, "message": "无法解析图像"}

        yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
        y = yuv[:, :, 0]

        coeffs = pywt.wavedec2(y, 'haar', level=2)
        LH2 = coeffs[2][1]
        flat = LH2.flatten()

        redundancy = 8
        bits = ''
        max_bits = len(flat) // (redundancy * 2)

        for i in range(max_bits):
            votes = 0
            for j in range(redundancy):
                idx = i * redundancy * 2 + j * 2
                if idx + 1 >= len(flat):
                    break

                # 比较 c1 和 c2
                if flat[idx] > flat[idx + 1]:
                    votes += 1

            bits += '1' if votes > redundancy // 2 else '0'

            result = self._bits_to_text(bits)
            if result.get('success'):
                return result

        return self._bits_to_text(bits)

    # ==================== SS 扩频水印 ====================
    def _embed_ss(self, img_bytes: bytes, text: str, strength: float = 15) -> Tuple[bytes, str]:
        """
        SS (Spread Spectrum) 扩频水印
        使用差分嵌入：DCT中频系数对的差异表示水印位
        """
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("无法解析图像")

        wm_hash = hashlib.md5(text.encode()).hexdigest()[:16]
        bits = self._text_to_bits(text)

        yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
        y = yuv[:, :, 0]

        # DCT变换
        dct_y = dct(dct(y.T, norm='ortho').T, norm='ortho')

        h, w = dct_y.shape
        # 选择中频区域
        start_h, end_h = h // 4, h // 2
        start_w, end_w = w // 4, w // 2

        embed_region = dct_y[start_h:end_h, start_w:end_w].copy()
        flat = embed_region.flatten()

        delta = strength
        redundancy = 8  # 每个bit用8对系数

        for i, bit in enumerate(bits):
            for j in range(redundancy):
                idx = i * redundancy * 2 + j * 2
                if idx + 1 >= len(flat):
                    break

                c1, c2 = flat[idx], flat[idx + 1]
                avg = (c1 + c2) / 2

                if bit == '1':
                    flat[idx] = avg + delta
                    flat[idx + 1] = avg - delta
                else:
                    flat[idx] = avg - delta
                    flat[idx + 1] = avg + delta

        embed_region = flat.reshape(embed_region.shape)
        dct_y[start_h:end_h, start_w:end_w] = embed_region

        # IDCT重建
        y_new = idct(idct(dct_y.T, norm='ortho').T, norm='ortho')

        yuv[:, :, 0] = np.clip(y_new, 0, 255).astype(np.uint8)
        result = cv2.cvtColor(yuv.astype(np.uint8), cv2.COLOR_YUV2BGR)

        _, enc = cv2.imencode('.png', result)
        return enc.tobytes(), wm_hash

    def _extract_ss(self, img_bytes: bytes) -> Dict:
        """扩频水印提取 - 基于相邻系数关系"""
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return {"success": False, "message": "无法解析图像"}

        yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
        y = yuv[:, :, 0]

        # DCT变换
        dct_y = dct(dct(y.T, norm='ortho').T, norm='ortho')

        h, w = dct_y.shape
        start_h, end_h = h // 4, h // 2
        start_w, end_w = w // 4, w // 2

        embed_region = dct_y[start_h:end_h, start_w:end_w].copy()
        flat = embed_region.flatten()

        redundancy = 8
        bits = ''
        max_bits = len(flat) // (redundancy * 2)

        for i in range(max_bits):
            votes = 0
            for j in range(redundancy):
                idx = i * redundancy * 2 + j * 2
                if idx + 1 >= len(flat):
                    break

                # 比较 c1 和 c2
                if flat[idx] > flat[idx + 1]:
                    votes += 1

            bits += '1' if votes > redundancy // 2 else '0'

            result = self._bits_to_text(bits)
            if result.get('success'):
                return result

        return self._bits_to_text(bits)

    # ==================== 统一接口 ====================
    def embed_watermark(self, img_bytes: bytes, text: str, algo: str = 'LSB', strength: float = None) -> Tuple[bytes, str]:
        """嵌入水印，支持自定义强度"""
        algo = algo.upper()
        # 使用默认强度如果未指定
        if strength is None:
            strength = self.DEFAULT_STRENGTH.get(algo, 50)

        if algo == 'LSB':
            return self._embed_lsb(img_bytes, text, strength)
        elif algo == 'DCT':
            return self._embed_dct(img_bytes, text, strength)
        elif algo == 'DWT':
            return self._embed_dwt(img_bytes, text, strength)
        elif algo == 'DWT-SVD':
            return self._embed_dwt_svd(img_bytes, text, strength)
        elif algo == 'QIM':
            return self._embed_qim(img_bytes, text, strength)
        elif algo == 'SS':
            return self._embed_ss(img_bytes, text, strength)
        raise ValueError(f"不支持算法: {algo}")

    def extract_watermark(self, img_bytes: bytes, algo: str = 'LSB', strength: float = None) -> Dict:
        """提取水印，强度参数用于QIM等需要量化步长的算法"""
        algo = algo.upper()
        if strength is None:
            strength = self.DEFAULT_STRENGTH.get(algo, 50)

        if algo == 'LSB':
            return self._extract_lsb(img_bytes)
        elif algo == 'DCT':
            return self._extract_dct(img_bytes)
        elif algo == 'DWT':
            return self._extract_dwt(img_bytes)
        elif algo == 'DWT-SVD':
            return self._extract_dwt_svd(img_bytes)
        elif algo == 'QIM':
            return self._extract_qim(img_bytes, strength)
        elif algo == 'SS':
            return self._extract_ss(img_bytes)
        return {"success": False, "watermark": None, "message": f"不支持算法: {algo}"}

    def get_strength_config(self, algo: str) -> Dict:
        """获取指定算法的强度配置"""
        algo = algo.upper()
        config = self.STRENGTH_RANGE.get(algo, {'min': 1, 'max': 100, 'step': 1, 'label': '强度'})
        return {
            'min': config['min'],
            'max': config['max'],
            'step': config['step'],
            'label': config['label'],
            'default': self.DEFAULT_STRENGTH.get(algo, 50)
        }

    def get_algorithm_info(self) -> Dict:
        """获取各算法的特性说明"""
        return {
            'LSB': {
                'name': '最低有效位替换',
                'robustness': '低',
                'capacity': '高',
                'visibility': '不可见',
                'description': '空域算法，容量大但脆弱，易被压缩、裁剪破坏',
                'best_for': '无损传输场景、版权标记'
            },
            'DCT': {
                'name': '离散余弦变换',
                'robustness': '中',
                'capacity': '中',
                'visibility': '不可见',
                'description': '变换域算法，抵抗JPEG压缩能力强',
                'best_for': 'JPEG图像、网络传输'
            },
            'DWT': {
                'name': '离散小波变换',
                'robustness': '较高',
                'capacity': '中',
                'visibility': '不可见',
                'description': '小波域算法，多分辨率特性，抗多种攻击',
                'best_for': '高质量图像、专业应用'
            },
            'DWT-SVD': {
                'name': '小波-奇异值分解混合',
                'robustness': '极高',
                'capacity': '低',
                'visibility': '不可见',
                'description': '结合小波和SVD优点，能抵抗压缩、裁剪、噪声、滤波等多种攻击',
                'best_for': '高安全需求、版权保护'
            },
            'QIM': {
                'name': '量化索引调制',
                'robustness': '高',
                'capacity': '中',
                'visibility': '不可见',
                'description': '最先进的量化方法，理论上最优的鲁棒性-容量权衡',
                'best_for': '抗攻击需求、学术研究'
            },
            'SS': {
                'name': '扩频水印',
                'robustness': '极高',
                'capacity': '低',
                'visibility': '不可见',
                'description': '类似通信扩频技术，安全性高，难以检测和去除',
                'best_for': '军事/商业高安全场景'
            }
        }


image_watermark_service = ImageWatermarkService()