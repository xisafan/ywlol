import 'dart:io';
import 'package:gt4_flutter_plugin/gt4_flutter_plugin.dart';
import 'package:gt4_flutter_plugin/gt4_session_configuration.dart';

class GeetHelper {
  static Gt4FlutterPlugin? _captcha;

  /// 初始化极验验证码插件
  static void initCaptcha() {
    if (_captcha != null) return;
    String captchaId = Platform.isAndroid
        ? 'a67218d617e49176f7cf2422f0dc13ec'
        : 'b8077537b695a0ff710c6d8bf9cb1cb3';
    GT4SessionConfiguration config = GT4SessionConfiguration();
    config.logEnable = false;
    _captcha = Gt4FlutterPlugin(captchaId, config);
  }

  /// 调用验证码弹窗
  static void verify({Function(Map<String, dynamic>)? onResult, Function(Map<String, dynamic>)? onError, Function(Map<String, dynamic>)? onShow}) {
    if (_captcha == null) {
      throw Exception('请先调用 GeetHelper.initCaptcha() 初始化验证码插件');
    }
    _captcha!.addEventHandler(
      onShow: onShow,
      onResult: onResult,
      onError: onError,
    );
    _captcha!.verify();
  }
}
