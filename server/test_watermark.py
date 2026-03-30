"""
图像水印算法验证测试脚本
测试嵌入、提取功能以及抗攻击鲁棒性
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cv2
import numpy as np
from app.services.image_wm import image_watermark_service
import time


def create_test_image(width=512, height=512):
    """创建测试图像"""
    # 创建渐变图像
    img = np.zeros((height, width, 3), dtype=np.uint8)
    for i in range(height):
        for j in range(width):
            img[i, j] = [i % 256, j % 256, (i + j) % 256]
    # 添加一些图案
    cv2.rectangle(img, (100, 100), (400, 400), (255, 255, 255), 3)
    cv2.circle(img, (250, 250), 100, (0, 0, 255), -1)
    cv2.putText(img, 'TEST', (180, 260), cv2.FONT_HERSHEY_SIMPLEX, 2, (255, 255, 255), 3)
    return img


def test_basic_embed_extract():
    """测试基本嵌入和提取功能"""
    print("=" * 60)
    print("测试1: 基本嵌入和提取功能")
    print("=" * 60)

    # 创建测试图像
    test_img = create_test_image()
    _, encoded = cv2.imencode('.png', test_img)
    img_bytes = encoded.tobytes()

    watermark_text = "测试水印2024"
    results = {}

    for algo in image_watermark_service.ALGORITHMS:
        print(f"\n--- 测试算法: {algo} ---")
        try:
            # 嵌入
            start = time.time()
            strength = image_watermark_service.DEFAULT_STRENGTH.get(algo)
            watermarked_bytes, wm_hash = image_watermark_service.embed_watermark(
                img_bytes, watermark_text, algo, strength
            )
            embed_time = time.time() - start

            # 提取
            start = time.time()
            result = image_watermark_service.extract_watermark(watermarked_bytes, algo, strength)
            extract_time = time.time() - start

            success = result.get('success', False)
            extracted = result.get('watermark', '')

            results[algo] = {
                'success': success,
                'match': extracted == watermark_text if success else False,
                'embed_time': f"{embed_time:.3f}s",
                'extract_time': f"{extract_time:.3f}s",
                'extracted': extracted
            }

            status = "[OK] 通过" if success and extracted == watermark_text else "[FAIL] 失败"
            print(f"  嵌入时间: {embed_time:.3f}s")
            print(f"  提取时间: {extract_time:.3f}s")
            print(f"  提取结果: {extracted}")
            print(f"  状态: {status}")

        except Exception as e:
            results[algo] = {'success': False, 'error': str(e)}
            print(f"  [ERROR] 错误: {e}")

    return results


def test_jpeg_compression():
    """测试JPEG压缩鲁棒性"""
    print("\n" + "=" * 60)
    print("测试2: JPEG压缩鲁棒性")
    print("=" * 60)

    test_img = create_test_image()
    _, encoded = cv2.imencode('.png', test_img)
    img_bytes = encoded.tobytes()

    watermark_text = "JPEG测试"
    quality_levels = [90, 70, 50, 30]
    results = {}

    for algo in image_watermark_service.ALGORITHMS:
        if algo == 'LSB':
            print(f"\n--- {algo}: 跳过 (LSB不支持有损压缩) ---")
            continue

        print(f"\n--- 测试算法: {algo} ---")
        strength = image_watermark_service.DEFAULT_STRENGTH.get(algo)
        watermarked_bytes, _ = image_watermark_service.embed_watermark(
            img_bytes, watermark_text, algo, strength
        )

        algo_results = {}
        for quality in quality_levels:
            # 模拟JPEG压缩
            nparr = np.frombuffer(watermarked_bytes, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            _, compressed = cv2.imencode('.jpg', img, [cv2.IMWRITE_JPEG_QUALITY, quality])
            compressed_bytes = compressed.tobytes()

            # 提取
            result = image_watermark_service.extract_watermark(compressed_bytes, algo, strength)
            success = result.get('success', False) and result.get('watermark') == watermark_text
            algo_results[quality] = success

            status = "[OK]" if success else "[X]"
            print(f"  JPEG质量 {quality}%: {status}")

        results[algo] = algo_results

    return results


def test_noise_attack():
    """测试噪声攻击鲁棒性"""
    print("\n" + "=" * 60)
    print("测试3: 噪声攻击鲁棒性")
    print("=" * 60)

    test_img = create_test_image()
    _, encoded = cv2.imencode('.png', test_img)
    img_bytes = encoded.tobytes()

    watermark_text = "噪声测试"
    noise_levels = [5, 10, 20]  # 噪声强度
    results = {}

    for algo in image_watermark_service.ALGORITHMS:
        if algo == 'LSB':
            print(f"\n--- {algo}: 跳过 (LSB对噪声敏感) ---")
            continue

        print(f"\n--- 测试算法: {algo} ---")
        strength = image_watermark_service.DEFAULT_STRENGTH.get(algo)
        watermarked_bytes, _ = image_watermark_service.embed_watermark(
            img_bytes, watermark_text, algo, strength
        )

        algo_results = {}
        for noise_level in noise_levels:
            # 添加高斯噪声
            nparr = np.frombuffer(watermarked_bytes, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

            noise = np.random.normal(0, noise_level, img.shape).astype(np.int16)
            noisy_img = np.clip(img.astype(np.int16) + noise, 0, 255).astype(np.uint8)

            _, encoded = cv2.imencode('.png', noisy_img)
            noisy_bytes = encoded.tobytes()

            # 提取
            result = image_watermark_service.extract_watermark(noisy_bytes, algo, strength)
            success = result.get('success', False) and result.get('watermark') == watermark_text
            algo_results[noise_level] = success

            status = "[OK]" if success else "[X]"
            print(f"  噪声强度 {noise_level}: {status}")

        results[algo] = algo_results

    return results


def test_crop_attack():
    """测试裁剪攻击鲁棒性"""
    print("\n" + "=" * 60)
    print("测试4: 裁剪攻击鲁棒性")
    print("=" * 60)

    test_img = create_test_image()
    _, encoded = cv2.imencode('.png', test_img)
    img_bytes = encoded.tobytes()

    watermark_text = "裁剪测试"
    crop_ratios = [0.9, 0.8, 0.7]  # 保留比例
    results = {}

    for algo in image_watermark_service.ALGORITHMS:
        if algo == 'LSB':
            print(f"\n--- {algo}: 跳过 (LSB对裁剪敏感) ---")
            continue

        print(f"\n--- 测试算法: {algo} ---")
        strength = image_watermark_service.DEFAULT_STRENGTH.get(algo)
        watermarked_bytes, _ = image_watermark_service.embed_watermark(
            img_bytes, watermark_text, algo, strength
        )

        nparr = np.frombuffer(watermarked_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        h, w = img.shape[:2]

        algo_results = {}
        for ratio in crop_ratios:
            # 中心裁剪
            new_h, new_w = int(h * ratio), int(w * ratio)
            start_y, start_x = (h - new_h) // 2, (w - new_w) // 2
            cropped = img[start_y:start_y+new_h, start_x:start_x+new_w]

            # 放回原始尺寸（用黑色填充）
            restored = np.zeros_like(img)
            restored[start_y:start_y+new_h, start_x:start_x+new_w] = cropped

            _, encoded = cv2.imencode('.png', restored)
            restored_bytes = encoded.tobytes()

            # 提取
            result = image_watermark_service.extract_watermark(restored_bytes, algo, strength)
            success = result.get('success', False) and result.get('watermark') == watermark_text
            algo_results[ratio] = success

            status = "[OK]" if success else "[X]"
            print(f"  保留 {ratio*100:.0f}%: {status}")

        results[algo] = algo_results

    return results


def test_strength_impact():
    """测试不同强度的影响"""
    print("\n" + "=" * 60)
    print("测试5: 强度参数影响 (DCT算法)")
    print("=" * 60)

    test_img = create_test_image()
    _, encoded = cv2.imencode('.png', test_img)
    img_bytes = encoded.tobytes()

    watermark_text = "强度测试"
    strengths = [20, 50, 80, 100]
    results = {}

    for strength in strengths:
        print(f"\n--- 强度: {strength} ---")

        # 嵌入
        watermarked_bytes, _ = image_watermark_service.embed_watermark(
            img_bytes, watermark_text, 'DCT', strength
        )

        # 计算图像质量 (PSNR)
        nparr_orig = np.frombuffer(img_bytes, np.uint8)
        orig = cv2.imdecode(nparr_orig, cv2.IMREAD_COLOR)
        nparr_wm = np.frombuffer(watermarked_bytes, np.uint8)
        wm = cv2.imdecode(nparr_wm, cv2.IMREAD_COLOR)

        mse = np.mean((orig.astype(float) - wm.astype(float)) ** 2)
        psnr = 20 * np.log10(255.0 / np.sqrt(mse)) if mse > 0 else float('inf')

        # 提取
        result = image_watermark_service.extract_watermark(watermarked_bytes, 'DCT', strength)
        success = result.get('success', False) and result.get('watermark') == watermark_text

        # JPEG压缩后提取
        _, compressed = cv2.imencode('.jpg', wm, [cv2.IMWRITE_JPEG_QUALITY, 70])
        compressed_bytes = compressed.tobytes()
        result_jpeg = image_watermark_service.extract_watermark(compressed_bytes, 'DCT', strength)
        success_jpeg = result_jpeg.get('success', False) and result_jpeg.get('watermark') == watermark_text

        results[strength] = {
            'psnr': f"{psnr:.2f} dB",
            'extract_success': success,
            'jpeg_70_success': success_jpeg
        }

        print(f"  PSNR: {psnr:.2f} dB (越高图像质量越好)")
        print(f"  直接提取: {'[OK]' if success else '[X]'}")
        print(f"  JPEG 70%后提取: {'[OK]' if success_jpeg else '[X]'}")

    return results


def print_summary(basic_results, jpeg_results, noise_results, crop_results):
    """打印测试总结"""
    print("\n" + "=" * 60)
    print("测试总结")
    print("=" * 60)

    print("\n【基本功能测试】")
    print("-" * 40)
    for algo, result in basic_results.items():
        if result.get('success'):
            status = "[OK] 通过" if result.get('match') else "[~] 内容不匹配"
        else:
            status = "[X] 失败"
        print(f"  {algo:12s}: {status}")

    print("\n【JPEG压缩鲁棒性】")
    print("-" * 40)
    header = "算法          " + "  ".join([f"Q{q:>2}" for q in [90, 70, 50, 30]])
    print(header)
    for algo, results in jpeg_results.items():
        row = f"{algo:12s}: "
        for q in [90, 70, 50, 30]:
            row += " [OK] " if results.get(q) else " [X] "
        print(row)

    print("\n【噪声攻击鲁棒性】")
    print("-" * 40)
    header = "算法          " + "  ".join([f"N{n:>2}" for n in [5, 10, 20]])
    print(header)
    for algo, results in noise_results.items():
        row = f"{algo:12s}: "
        for n in [5, 10, 20]:
            row += " [OK] " if results.get(n) else " [X] "
        print(row)

    print("\n【裁剪攻击鲁棒性】")
    print("-" * 40)
    header = "算法          " + "  ".join([f"{int(r*100):>2}%" for r in [0.9, 0.8, 0.7]])
    print(header)
    for algo, results in crop_results.items():
        row = f"{algo:12s}: "
        for r in [0.9, 0.8, 0.7]:
            row += " [OK] " if results.get(r) else " [X] "
        print(row)

    print("\n【推荐使用场景】")
    print("-" * 40)
    print("  LSB:     无损传输、版权标记 (脆弱型)")
    print("  DCT:     JPEG图像、网络传输 (抗JPEG压缩)")
    print("  DWT:     高质量图像、专业应用 (综合鲁棒性)")
    print("  DWT-SVD: 高安全需求、版权保护 (极强鲁棒性)")
    print("  QIM:     抗攻击需求、学术研究 (最优权衡)")
    print("  SS:      军事/商业高安全场景 (最高安全性)")


def main():
    print("\n" + "=" * 60)
    print("   图像水印算法验证测试")
    print("=" * 60)

    # 运行所有测试
    basic_results = test_basic_embed_extract()
    jpeg_results = test_jpeg_compression()
    noise_results = test_noise_attack()
    crop_results = test_crop_attack()
    strength_results = test_strength_impact()

    # 打印总结
    print_summary(basic_results, jpeg_results, noise_results, crop_results)

    print("\n测试完成!")


if __name__ == "__main__":
    main()