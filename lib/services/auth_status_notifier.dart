import 'package:flutter/foundation.dart';

/// 全局认证状态通知器
/// 
/// 用于管理登录过期、认证失败等全局状态
class AuthStatusNotifier extends ChangeNotifier {
  static final AuthStatusNotifier _instance = AuthStatusNotifier._internal();
  factory AuthStatusNotifier() => _instance;
  AuthStatusNotifier._internal();

  bool _showLoginExpiredDialog = false;
  String _expiredMessage = '登录已过期，请重新登录';
  bool _isDialogShowing = false;

  /// 是否需要显示登录过期对话框
  bool get showLoginExpiredDialog => _showLoginExpiredDialog;

  /// 过期提示消息
  String get expiredMessage => _expiredMessage;

  /// 对话框是否正在显示
  bool get isDialogShowing => _isDialogShowing;

  /// 触发登录过期提示
  /// 
  /// [message] 自定义过期消息
  /// [force] 是否强制显示（即使已经在显示）
  void triggerLoginExpired({
    String? message,
    bool force = false,
  }) {
    if (_isDialogShowing && !force) {
      print('[AuthStatusNotifier] 登录过期对话框已在显示，跳过');
      return;
    }

    print('[AuthStatusNotifier] 触发登录过期提示: ${message ?? _expiredMessage}');
    
    _expiredMessage = message ?? '登录已过期，请重新登录';
    _showLoginExpiredDialog = true;
    notifyListeners();
  }

  /// 触发线路切换登录清理提示
  /// 
  /// [message] 自定义提示消息
  void triggerLineSwitchLogout({String? message}) {
    print('[AuthStatusNotifier] 触发线路切换登录清理提示');
    
    _expiredMessage = message ?? '切换线路，请重新登录';
    _showLoginExpiredDialog = true;
    notifyListeners();
  }

  /// 重置登录过期状态
  void resetLoginExpired() {
    print('[AuthStatusNotifier] 重置登录过期状态');
    _showLoginExpiredDialog = false;
    _expiredMessage = '登录已过期，请重新登录';
    notifyListeners();
  }

  /// 设置对话框显示状态
  void setDialogShowing(bool showing) {
    _isDialogShowing = showing;
    if (!showing) {
      _showLoginExpiredDialog = false;
    }
    notifyListeners();
  }

  /// 清理所有状态
  void clear() {
    _showLoginExpiredDialog = false;
    _expiredMessage = '登录已过期，请重新登录';
    _isDialogShowing = false;
    notifyListeners();
  }
}
