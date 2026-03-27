"""
图像水印API路由
"""

import json
from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from fastapi.responses import Response
from ..services.image_wm import image_watermark_service
from ..services.image_record import image_record_service

router = APIRouter()


@router.get("/algorithms")
async def get_algorithms():
    """获取支持的算法列表"""
    return {
        "algorithms": image_watermark_service.ALGORITHMS,
        "descriptions": {
            "LSB": "最低有效位替换 - 简单高效，容量大",
            "DCT": "离散余弦变换 - 抗JPEG压缩，鲁棒性强",
            "DWT": "离散小波变换 - 多分辨率，抗压缩攻击"
        }
    }


@router.post("/embed")
async def embed_image_watermark(
    image: UploadFile = File(None, description="原始图像文件"),
    watermark: str = Form(None, description="水印文本"),
    algorithm: str = Form("LSB", description="水印算法: LSB, DCT, DWT")
):
    """
    嵌入图像水印
    """
    try:
        if image is None:
            raise HTTPException(status_code=400, detail="未接收到图像文件")
        if not watermark:
            raise HTTPException(status_code=400, detail="水印内容不能为空")

        # 读取图像数据
        image_bytes = await image.read()

        if not image_bytes:
            raise HTTPException(status_code=400, detail="图像文件为空")

        # 嵌入水印
        watermarked_bytes, watermark_hash = image_watermark_service.embed_watermark(
            image_bytes, watermark, algorithm
        )

        # 记录图片哈希
        record_result = image_record_service.check_and_record_embed(
            image_bytes, watermark, algorithm, watermarked_bytes
        )

        print(f"[DEBUG] embed result: {record_result}")

        # 返回带水印的图像
        return Response(
            content=watermarked_bytes,
            media_type="image/png",
            headers={
                "x-watermark-hash": watermark_hash,
                "x-watermark-algorithm": algorithm,
                "x-image-hash": record_result["original_hash"],
                "x-image-known": str(record_result["is_known"]).lower(),
                "x-previous-info": json.dumps(record_result.get("previous_info") or {}),
                "content-disposition": f"attachment; filename=watermarked_{image.filename}"
            }
        )
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"[ERROR] embed failed: {e}")
        raise HTTPException(status_code=500, detail=f"水印嵌入失败: {str(e)}")


@router.post("/extract")
async def extract_image_watermark(
    image: UploadFile = File(None, description="图像文件"),
    algorithm: str = Form("LSB", description="水印算法: LSB, DCT, DWT, DFT")
):
    """
    提取图像水印

    - **image**: 可能包含水印的图像文件
    - **algorithm**: 水印算法 (LSB/DCT/DWT/DFT)
    """
    try:
        if image is None:
            raise HTTPException(status_code=400, detail="未接收到图像文件")

        # 读取图像数据
        image_bytes = await image.read()

        if not image_bytes:
            raise HTTPException(status_code=400, detail="图像文件为空")

        # 检查图片记录
        record_info = image_record_service.check_extract(image_bytes)

        # 提取水印
        result = image_watermark_service.extract_watermark(image_bytes, algorithm)

        response = {
            "success": result.get("success", False),
            "watermark": result.get("watermark"),
            "message": result.get("message", "提取完成"),
            "algorithm": algorithm,
            "filename": image.filename,
            "image_hash": record_info["hash"],
            "is_watermarked": record_info["is_watermarked"],
            "record_info": record_info["info"]
        }

        return response
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"水印提取失败: {str(e)}")