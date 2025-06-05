import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:image/image.dart' as img;

class AvatarCropPage extends StatefulWidget {
  final String imagePath;
  final Color themeColor;
  const AvatarCropPage({required this.imagePath, required this.themeColor, Key? key}) : super(key: key);

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  final GlobalKey<ExtendedImageGestureState> gestureKey = GlobalKey<ExtendedImageGestureState>();

  @override
  Widget build(BuildContext context) {
    final double cropSize = MediaQuery.of(context).size.width * 0.8;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black, // 使用黑色背景
      body: SafeArea(
        child: Column(
          children: [
            // 顶部AppBar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 56,
              color: Colors.black, // 黑色背景
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '移动和缩放',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 22), // 为了平衡左侧返回按钮的空间
                ],
              ),
            ),

            // 图片编辑区域
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 可拖动的图片
                  ExtendedImage.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                    mode: ExtendedImageMode.gesture, // 使用gesture模式而非editor模式
                    extendedImageGestureKey: gestureKey,
                    initGestureConfigHandler: (state) {
                      return GestureConfig(
                        minScale: 0.8,
                        maxScale: 8.0,
                        animationMinScale: 0.7,
                        animationMaxScale: 8.5,
                        speed: 1.0,
                        inertialSpeed: 100.0,
                        initialScale: 1.0,
                        inPageView: false,
                      );
                    },
                  ),

                  // 固定的圆形裁剪框
                  IgnorePointer(
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.transparent,
                      child: CustomPaint(
                        painter: CircleMaskPainter(
                          cropSize: cropSize,
                          maskColor: Colors.black.withOpacity(0.6), // 黑色半透明遮罩
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 底部控制区
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: Colors.black, // 黑色背景
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 完成按钮
                  GestureDetector(
                    onTap: () async {
                      // 获取当前图片状态
                      final state = gestureKey.currentState;
                      if (state != null) {
                        // 获取图片文件
                        final File imageFile = File(widget.imagePath);
                        final Uint8List imageBytes = await imageFile.readAsBytes();

                        // 获取手势状态
                        final Rect displayRect = state.gestureDetails?.destinationRect ?? Rect.zero;
                        final double scale = state.gestureDetails?.totalScale ?? 1.0;

                        // 计算裁剪区域
                        final Offset center = Offset(screenSize.width / 2, screenSize.height / 2);
                        final double radius = cropSize / 2;
                        final Rect cropRect = Rect.fromCircle(center: center, radius: radius);

                        // 计算实际裁剪区域在原图中的位置
                        final Rect actualCropRect = calculateActualCropRect(
                          imageBytes: imageBytes,
                          displayRect: displayRect,
                          cropRect: cropRect,
                          scale: scale,
                        );

                        // 裁剪图片
                        final Uint8List? croppedData = await cropImageData(
                          imageBytes: imageBytes,
                          cropRect: actualCropRect,
                        );

                        if (croppedData != null) {
                          Navigator.pop(context, croppedData);
                        }
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '完成',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 计算实际裁剪区域
  Rect calculateActualCropRect({
    required Uint8List imageBytes,
    required Rect displayRect,
    required Rect cropRect,
    required double scale,
  }) {
    // 解码图片获取原始尺寸
    final img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return Rect.zero;

    final double imageWidth = image.width.toDouble();
    final double imageHeight = image.height.toDouble();

    // 计算显示图片与原始图片的比例
    final double widthRatio = imageWidth / displayRect.width * scale;
    final double heightRatio = imageHeight / displayRect.height * scale;

    // 计算裁剪区域相对于显示图片的位置
    final double cropLeft = (cropRect.left - displayRect.left) * widthRatio;
    final double cropTop = (cropRect.top - displayRect.top) * heightRatio;
    final double cropWidth = cropRect.width * widthRatio;
    final double cropHeight = cropRect.height * heightRatio;

    // 确保裁剪区域在图片范围内
    final double x = cropLeft.clamp(0.0, imageWidth - 1);
    final double y = cropTop.clamp(0.0, imageHeight - 1);
    final double w = cropWidth.clamp(1.0, imageWidth - x);
    final double h = cropHeight.clamp(1.0, imageHeight - y);

    return Rect.fromLTWH(x, y, w, h);
  }

  // 裁剪图片
  Future<Uint8List?> cropImageData({
    required Uint8List imageBytes,
    required Rect cropRect,
  }) async {
    // 解码图片
    final img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return null;

    // 裁剪
    final int x = cropRect.left.round();
    final int y = cropRect.top.round();
    final int w = cropRect.width.round();
    final int h = cropRect.height.round();

    // 使用命名参数
    final img.Image cropped = img.copyCrop(
      image,
      x: x,
      y: y,
      width: w,
      height: h,
    );

    // 编码为jpg
    return Uint8List.fromList(img.encodeJpg(cropped));
  }
}

// 自定义圆形遮罩绘制器
class CircleMaskPainter extends CustomPainter {
  final double cropSize;
  final Color maskColor;

  CircleMaskPainter({
    required this.cropSize,
    required this.maskColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 绘制半透明背景
    final backgroundPaint = Paint()
      ..color = maskColor
      ..style = PaintingStyle.fill;

    // 绘制圆形裁剪区域
    final circlePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    // 使用差集创建遮罩效果（整个画布减去圆形区域）
    final fullScreenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final maskPath = Path.combine(
      PathOperation.difference,
      fullScreenPath,
      circlePath,
    );

    canvas.drawPath(maskPath, backgroundPaint);

    // 绘制圆形边框
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
