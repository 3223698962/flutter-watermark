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
            "LSB": "最低有效位替换 - 容量大，易破坏",
            "DCT": "离散余弦变换 - 抗JPEG压缩，中等鲁棒性",
            "DWT": "离散小波变换 - 较强鲁棒性，抗多种攻击",
            "DWT-SVD": "小波+SVD混合 - 极强鲁棒性，抗压缩/裁剪/噪声",
            "QIM": "量化索引调制 - 最先进方法，最优鲁棒性-容量权衡",
            "SS": "扩频水印 - 高安全性，难以检测和去除"
        },
        "info": image_watermark_service.get_algorithm_info(),
        "strength_ranges": image_watermark_service.STRENGTH_RANGE,
        "default_strength": image_watermark_service.DEFAULT_STRENGTH
    }


@router.get("/strength/{algorithm}")
async def get_strength_config(algorithm: str):
    """获取指定算法的强度配置"""
    return image_watermark_service.get_strength_config(algorithm)


@router.get("/statistics")
async def get_statistics():
    """获取水印操作统计信息"""
    return image_record_service.get_statistics()


@router.get("/history/{image_hash}")
async def get_watermark_history(image_hash: str, limit: int = 10):
    """获取指定图片的水印历史"""
    history = image_record_service.get_watermark_history(image_hash, limit)
    return {
        "image_hash": image_hash,
        "history": history,
        "count": len(history)
    }


@router.post("/embed")
async def embed_image_watermark(
    image: UploadFile = File(None, description="原始图像文件"),
    watermark: str = Form(None, description="水印文本"),
    algorithm: str = Form("DCT", description="水印算法: LSB, DCT, DWT, DWT-SVD, QIM, SS"),
    strength: float = Form(None, description="嵌入强度(可选，默认使用算法推荐值)")
):
    """
    嵌入图像水印

    支持的算法及强度范围:
    - LSB: 固定强度1 (容量大，脆弱)
    - DCT: 20-100，默认50 (抗JPEG压缩)
    - DWT: 40-150，默认80 (较强鲁棒性)
    - DWT-SVD: 0.01-0.1，默认0.03 (极强鲁棒性)
    - QIM: 15-60，默认30 (最先进方法)
    - SS: 5-30，默认15 (高安全性)

    强度越高，鲁棒性越强，但可能导致图像质量下降
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

        # 验证强度范围
        strength_config = image_watermark_service.get_strength_config(algorithm)
        if strength is not None:
            if strength < strength_config['min'] or strength > strength_config['max']:
                raise HTTPException(
                    status_code=400,
                    detail=f"强度值应在 {strength_config['min']} - {strength_config['max']} 范围内"
                )

        # 嵌入水印
        watermarked_bytes, watermark_hash = image_watermark_service.embed_watermark(
            image_bytes, watermark, algorithm, strength
        )

        # 记录图片哈希
        record_result = image_record_service.check_and_record_embed(
            image_bytes, watermark, algorithm, watermarked_bytes,
            strength=strength or strength_config['default'],
            filename=image.filename
        )

        print(f"[DEBUG] embed result: {record_result}")

        # 返回带水印的图像
        return Response(
            content=watermarked_bytes,
            media_type="image/png",
            headers={
                "x-watermark-hash": watermark_hash,
                "x-watermark-algorithm": algorithm,
                "x-watermark-strength": str(strength or strength_config['default']),
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
    algorithm: str = Form("DCT", description="水印算法: LSB, DCT, DWT, DWT-SVD, QIM, SS"),
    strength: float = Form(None, description="嵌入时使用的强度(QIM算法需要)")
):
    """
    提取图像水印

    支持的算法:
    - LSB: 最低有效位替换
    - DCT: 离散余弦变换域
    - DWT: 离散小波变换域
    - DWT-SVD: 小波+奇异值分解混合
    - QIM: 量化索引调制 (需要提供嵌入时的强度)
    - SS: 扩频水印
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
        result = image_watermark_service.extract_watermark(image_bytes, algorithm, strength)

        response = {
            "success": result.get("success", False),
            "watermark": result.get("watermark"),
            "message": result.get("message", "提取完成"),
            "algorithm": algorithm,
            "strength": strength or image_watermark_service.DEFAULT_STRENGTH.get(algorithm.upper()),
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