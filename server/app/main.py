"""
数字水印平台 API - 主应用入口
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .routers import text_router, image_router

# 创建FastAPI应用
app = FastAPI(
    title="数字水印平台 API",
    description="提供文本水印和图像水印服务",
    version="1.0.0"
)

# CORS配置（允许Flutter前端访问）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应限制具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(text_router, prefix="/api/text", tags=["文本水印"])
app.include_router(image_router, prefix="/api/image", tags=["图像水印"])


@app.get("/")
async def root():
    """API根路径"""
    return {
        "message": "数字水印平台API运行中",
        "version": "1.0.0",
        "endpoints": {
            "文本水印": {
                "嵌入": "POST /api/text/embed",
                "提取": "POST /api/text/extract",
                "移除": "POST /api/text/remove"
            },
            "图像水印": {
                "嵌入": "POST /api/image/embed",
                "提取": "POST /api/image/extract"
            }
        }
    }


@app.get("/health")
async def health_check():
    """健康检查"""
    return {"status": "healthy"}