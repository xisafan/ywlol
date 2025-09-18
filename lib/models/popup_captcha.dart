import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 弹窗式验证码生成器
class PopupCaptcha {
  static final Random _random = Random();

  /// 生成图片验证码数据
  static Map<String, dynamic> generateImageCaptcha() {
    // 生成4位随机数字和字母组合
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String code = '';
    for (int i = 0; i < 4; i++) {
      code += chars[_random.nextInt(chars.length)];
    }

    return {
      'code': code,
      'noise_lines': _generateNoiseLines(),
      'noise_dots': _generateNoiseDots(),
      'colors': _generateColors(),
    };
  }

  /// 生成数学运算验证码
  static Map<String, dynamic> generateMathCaptcha() {
    int a = _random.nextInt(9) + 1; // 1-9
    int b = _random.nextInt(9) + 1; // 1-9
    int operation = _random.nextInt(3); // 0: 加法, 1: 减法, 2: 乘法

    String question;
    int answer;

    switch (operation) {
      case 0:
        question = '$a + $b = ?';
        answer = a + b;
        break;
      case 1:
        // 确保减法结果为正数
        if (a < b) {
          int temp = a;
          a = b;
          b = temp;
        }
        question = '$a - $b = ?';
        answer = a - b;
        break;
      case 2:
        // 限制乘法结果不超过50
        if (a > 5) a = _random.nextInt(5) + 1;
        if (b > 5) b = _random.nextInt(5) + 1;
        question = '$a × $b = ?';
        answer = a * b;
        break;
      default:
        question = '$a + $b = ?';
        answer = a + b;
    }

    return {
      'question': question,
      'answer': answer,
      'colors': _generateColors(),
    };
  }

  static List<Map<String, dynamic>> _generateNoiseLines() {
    List<Map<String, dynamic>> lines = [];
    for (int i = 0; i < 3; i++) {
      lines.add({
        'start': Offset(_random.nextDouble() * 150, _random.nextDouble() * 50),
        'end': Offset(_random.nextDouble() * 150, _random.nextDouble() * 50),
        'color': _getRandomColor(),
      });
    }
    return lines;
  }

  static List<Map<String, dynamic>> _generateNoiseDots() {
    List<Map<String, dynamic>> dots = [];
    for (int i = 0; i < 20; i++) {
      dots.add({
        'position': Offset(
          _random.nextDouble() * 150,
          _random.nextDouble() * 50,
        ),
        'color': _getRandomColor(),
      });
    }
    return dots;
  }

  static Map<String, Color> _generateColors() {
    List<Color> colors = [
      Colors.red.shade600,
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.purple.shade600,
      Colors.orange.shade600,
      Colors.teal.shade600,
    ];
    colors.shuffle();

    return {
      'primary': colors[0],
      'secondary': colors[1],
      'background': Colors.grey.shade100,
      'border': Colors.grey.shade400,
    };
  }

  static Color _getRandomColor() {
    List<Color> colors = [
      Colors.grey.shade400,
      Colors.grey.shade500,
      Colors.grey.shade600,
    ];
    return colors[_random.nextInt(colors.length)];
  }
}

/// 验证码绘制组件
class CaptchaPainter extends CustomPainter {
  final Map<String, dynamic> captchaData;
  final bool isImageCaptcha;

  CaptchaPainter({required this.captchaData, this.isImageCaptcha = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // 绘制背景
    paint.color = captchaData['colors']['background'];
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(8),
      ),
      paint,
    );

    if (isImageCaptcha) {
      _drawImageCaptcha(canvas, size, paint);
    } else {
      _drawMathCaptcha(canvas, size, paint);
    }
  }

  void _drawImageCaptcha(Canvas canvas, Size size, Paint paint) {
    // 绘制噪点
    for (var dot in captchaData['noise_dots']) {
      paint.color = dot['color'];
      canvas.drawCircle(dot['position'], 1, paint);
    }

    // 绘制干扰线
    paint.strokeWidth = 1;
    for (var line in captchaData['noise_lines']) {
      paint.color = line['color'];
      canvas.drawLine(line['start'], line['end'], paint);
    }

    // 绘制验证码文字
    String code = captchaData['code'];
    double charWidth = size.width / code.length;

    for (int i = 0; i < code.length; i++) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: code[i],
          style: TextStyle(
            fontSize: 24 + Random().nextDouble() * 6, // 随机字体大小
            fontWeight: FontWeight.bold,
            color:
                i.isEven
                    ? captchaData['colors']['primary']
                    : captchaData['colors']['secondary'],
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // 随机位置和旋转
      double x = charWidth * i + 10 + Random().nextDouble() * 10;
      double y = 10 + Random().nextDouble() * 10;
      double rotation = (Random().nextDouble() - 0.5) * 0.3; // 小幅旋转

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      textPainter.paint(canvas, const Offset(0, 0));
      canvas.restore();
    }
  }

  void _drawMathCaptcha(Canvas canvas, Size size, Paint paint) {
    // 绘制数学题
    final textPainter = TextPainter(
      text: TextSpan(
        text: captchaData['question'],
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: captchaData['colors']['primary'],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    double x = (size.width - textPainter.width) / 2;
    double y = (size.height - textPainter.height) / 2;

    textPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

/// 弹窗验证码组件
class PopupCaptchaDialog extends StatefulWidget {
  final Function(bool) onVerified;
  final VoidCallback? onCancel;

  const PopupCaptchaDialog({Key? key, required this.onVerified, this.onCancel})
    : super(key: key);

  @override
  _PopupCaptchaDialogState createState() => _PopupCaptchaDialogState();
}

class _PopupCaptchaDialogState extends State<PopupCaptchaDialog>
    with TickerProviderStateMixin {
  late Map<String, dynamic> _captchaData;
  final TextEditingController _answerController = TextEditingController();
  String? _errorMessage;
  bool _isVerified = false;
  bool _isImageCaptcha = true;
  late AnimationController _shakeController;
  late AnimationController _fadeController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _generateNewCaptcha();

    // 抖动动画
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // 淡入动画
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  void _generateNewCaptcha() {
    setState(() {
      _captchaData =
          _isImageCaptcha
              ? PopupCaptcha.generateImageCaptcha()
              : PopupCaptcha.generateMathCaptcha();
      _answerController.clear();
      _errorMessage = null;
      _isVerified = false;
    });
  }

  void _verify() async {
    String userAnswer = _answerController.text.trim().toUpperCase();
    if (userAnswer.isEmpty) {
      _showError('请输入验证码');
      return;
    }

    bool isCorrect = false;

    if (_isImageCaptcha) {
      isCorrect = userAnswer == _captchaData['code'];
    } else {
      try {
        int answer = int.parse(userAnswer);
        isCorrect = answer == _captchaData['answer'];
      } catch (e) {
        _showError('请输入数字');
        return;
      }
    }

    if (isCorrect) {
      setState(() {
        _isVerified = true;
        _errorMessage = null;
      });

      // 添加成功反馈
      HapticFeedback.lightImpact();

      // 延迟关闭弹窗
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).pop();
        widget.onVerified(true);
      }
    } else {
      _showError(_isImageCaptcha ? '验证码错误，请重试' : '答案错误，请重试');
      _generateNewCaptcha();
      _shakeController.forward().then((_) => _shakeController.reset());
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
    HapticFeedback.mediumImpact();
  }

  void _switchCaptchaType() {
    setState(() {
      _isImageCaptcha = !_isImageCaptcha;
    });
    _generateNewCaptcha();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _shakeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              double offset =
                  _shakeAnimation.value *
                  10 *
                  (1 - _shakeAnimation.value) *
                  ((_shakeAnimation.value * 4).floor().isEven ? 1 : -1);

              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '安全验证',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _switchCaptchaType,
                        child: Text(
                          _isImageCaptcha ? '数学题' : '图片码',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 验证码显示区域
                  Container(
                    height: 60,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _captchaData['colors']['border'],
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CustomPaint(
                      painter: CaptchaPainter(
                        captchaData: _captchaData,
                        isImageCaptcha: _isImageCaptcha,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 输入区域
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _answerController,
                          keyboardType:
                              _isImageCaptcha
                                  ? TextInputType.text
                                  : TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: _isImageCaptcha ? '请输入图片中的字符' : '请输入答案',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            suffixIcon:
                                _isVerified
                                    ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                    : null,
                          ),
                          onSubmitted: (_) => _verify(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _generateNewCaptcha,
                        icon: const Icon(Icons.refresh),
                        tooltip: '刷新验证码',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),

                  // 错误提示
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // 按钮区域
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (widget.onCancel != null) {
                              widget.onCancel!();
                            }
                          },
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isVerified ? null : _verify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isVerified
                                    ? Colors.green
                                    : Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _isVerified ? '验证成功' : '确认',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 弹窗验证码帮助类
class PopupCaptchaHelper {
  /// 显示验证码弹窗
  static Future<bool> showCaptcha(BuildContext context) async {
    bool isVerified = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => PopupCaptchaDialog(
            onVerified: (verified) {
              isVerified = verified;
            },
          ),
    );

    return isVerified;
  }
}
