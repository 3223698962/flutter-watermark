"""
文本水印API路由
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from ..services.text_wm import text_watermark_service

router = APIRouter()


class TextEmbedRequest(BaseModel):
    """文本水印嵌入请求"""
    text: str
    watermark: str


class TextExtractRequest(BaseModel):
    """文本水印提取请求"""
    text: str


class TextEmbedResponse(BaseModel):
    """文本水印嵌入响应"""
    success: bool
    watermarked_text: Optional[str] = None
    watermark: Optional[str] = None
    message: str


class TextExtractResponse(BaseModel):
    """文本水印提取响应"""
    success: bool
    watermark: Optional[str] = None
    message: str


@router.post("/embed", response_model=TextEmbedResponse)
async def embed_text_watermark(request: TextEmbedRequest):
    """
    嵌入文本水印

    - **text**: 原始文本内容
    - **watermark**: 要嵌入的水印字符串
    """
    try:
        if not request.text:
            raise HTTPException(status_code=400, detail="文本内容不能为空")
        if not request.watermark:
            raise HTTPException(status_code=400, detail="水印内容不能为空")

        watermarked_text, watermark = text_watermark_service.embed_watermark(
            request.text, request.watermark
        )

        return TextEmbedResponse(
            success=True,
            watermarked_text=watermarked_text,
            watermark=watermark,
            message="水印嵌入成功"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"水印嵌入失败: {str(e)}")


@router.post("/extract", response_model=TextExtractResponse)
async def extract_text_watermark(request: TextExtractRequest):
    """
    提取文本水印

    - **text**: 包含水印的文本内容
    """
    try:
        if not request.text:
            raise HTTPException(status_code=400, detail="文本内容不能为空")

        result = text_watermark_service.extract_watermark(request.text)

        return TextExtractResponse(
            success=result["success"],
            watermark=result["watermark"],
            message=result["message"]
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"水印提取失败: {str(e)}")


@router.post("/remove")
async def remove_text_watermark(request: TextExtractRequest):
    """
    移除文本水印

    - **text**: 包含水印的文本内容
    """
    try:
        if not request.text:
            raise HTTPException(status_code=400, detail="文本内容不能为空")

        clean_text = text_watermark_service.remove_watermark(request.text)

        return {
            "success": True,
            "clean_text": clean_text,
            "message": "水印移除成功"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"水印移除失败: {str(e)}")