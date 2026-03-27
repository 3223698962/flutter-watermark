"""
文本水印服务 - 使用零宽字符实现
"""

class TextWatermarkService:
    """基于零宽字符的文本水印服务"""

    def __init__(self):
        # 零宽字符集（用于嵌入水印）
        self.zero_width_chars = ['\u200B', '\u200C', '\u200D', '\uFEFF']

    def _text_to_binary(self, text: str) -> str:
        """将文本转换为二进制字符串"""
        return ''.join(format(ord(char), '016b') for char in text)

    def _binary_to_text(self, binary: str) -> str:
        """将二进制字符串转换为文本"""
        text = ""
        for i in range(0, len(binary), 16):
            byte = binary[i:i+16]
            if len(byte) == 16:
                char_code = int(byte, 2)
                if char_code > 0:
                    text += chr(char_code)
        return text

    def _binary_to_zero_width(self, binary: str) -> str:
        """将二进制字符串转换为零宽字符"""
        result = ""
        # 每2位转换为一个零宽字符
        for i in range(0, len(binary), 2):
            if i + 1 < len(binary):
                two_bits = binary[i:i+2]
                index = int(two_bits, 2)
                result += self.zero_width_chars[index]
        return result

    def _zero_width_to_binary(self, zero_width_text: str) -> str:
        """将零宽字符转换为二进制字符串"""
        result = ""
        for char in zero_width_text:
            if char in self.zero_width_chars:
                index = self.zero_width_chars.index(char)
                result += format(index, '02b')
        return result

    def embed_watermark(self, text: str, watermark_str: str) -> tuple:
        """
        嵌入文本水印到文本末尾

        Args:
            text: 原始文本
            watermark_str: 水印字符串

        Returns:
            (带水印文本, 水印数据)
        """
        if not watermark_str:
            return text, ""

        # 转换水印为二进制
        binary_watermark = self._text_to_binary(watermark_str)
        # 添加结束标志（空字符）
        binary_watermark += "0000000000000000"

        # 转换为零宽字符
        zero_width_watermark = self._binary_to_zero_width(binary_watermark)

        # 将水印嵌入到文本末尾
        watermarked_text = text + zero_width_watermark

        return watermarked_text, watermark_str

    def extract_watermark(self, text: str) -> dict:
        """
        从文本末尾提取水印

        Args:
            text: 待检测文本

        Returns:
            水印信息字典
        """
        # 从文本末尾提取零宽字符
        zero_width_chars = ""

        # 从后往前扫描
        for char in reversed(text):
            if char in self.zero_width_chars:
                zero_width_chars = char + zero_width_chars
            else:
                break

        if not zero_width_chars:
            return {
                "success": False,
                "watermark": None,
                "message": "未检测到水印"
            }

        # 转换为二进制
        binary_watermark = self._zero_width_to_binary(zero_width_chars)

        # 转换为文本
        watermark_text = self._binary_to_text(binary_watermark)

        # 移除末尾的空字符（结束标志）
        watermark_text = watermark_text.rstrip('\x00')

        if watermark_text:
            return {
                "success": True,
                "watermark": watermark_text,
                "message": "水印提取成功"
            }

        return {
            "success": False,
            "watermark": None,
            "message": "水印格式错误"
        }

    def remove_watermark(self, text: str) -> str:
        """
        移除文本中的水印

        Args:
            text: 带水印的文本

        Returns:
            清理后的文本
        """
        clean_text = ""
        for char in text:
            if char not in self.zero_width_chars:
                clean_text += char
        return clean_text


# 单例实例
text_watermark_service = TextWatermarkService()