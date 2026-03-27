# 路由模块
from .text_watermark import router as text_router
from .image_watermark import router as image_router

__all__ = ['text_router', 'image_router']