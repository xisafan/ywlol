import 'package:flutter/material.dart';
import 'package:ovofun/models/user_model.dart';
import 'package:ovofun/services/api/ssl_Management.dart';
import 'package:ovofun/page/login_page.dart';

/// 全局认证帮助类
///
/// 统一处理登录状态检查、过期提示、自动登录等功能
class AuthHelper {
  static final AuthHelper _instance = AuthHelper._internal();
  factory AuthHelper() => _instance;
  AuthHelper._internal();

  /// 检查登录状态是否有效
  ///
  /// 返回 true 表示已登录且token有效，false 表示未登录或token无效
  static Future<bool> checkAuthStatus() async {
    try {
      final user = UserStore().user;
      if (user == null || user.token == null || user.token!.isEmpty) {
        print('[AuthHelper] 用户未登录或token为空');
        return false;
      }

      // 检查token是否接近过期（还有1天内过期时提前刷新）
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expireTime = user.expireTime ?? (now + 604800); // 默认7天后过期
      final remainingTime = expireTime - now;

      print(
        '[AuthHelper] Token剩余时间: ${remainingTime}秒 (${remainingTime ~/ 3600}小时)',
      );

      // 如果token在24小时内过期，尝试刷新
      if (remainingTime < 24 * 3600) {
        print('[AuthHelper] Token即将过期，尝试刷新...');
        final refreshedUser = await UserStore.refreshTokenIfNeeded();
        if (refreshedUser == null) {
          print('[AuthHelper] Token刷新失败，用户需重新登录');
          return false;
        }
        print('[AuthHelper] Token刷新成功');
        return true;
      }

      // Token还有较长时间才过期，验证其有效性
      return await _validateTokenWithServer();
    } catch (e) {
      print('[AuthHelper] 检查登录状态异常: $e');
      return false;
    }
  }

  /// 向服务器验证token有效性
  static Future<bool> _validateTokenWithServer() async {
    try {
      // 使用获取用户信息接口来验证token
      final api = OvoApiManager();
      final result = await api.get('/v1/user/profile');

      if (result != null && (result['code'] == 0 || result['code'] == 200)) {
        print('[AuthHelper] Token验证成功');
        return true;
      } else {
        print('[AuthHelper] Token验证失败: $result');
        return false;
      }
    } catch (e) {
      print('[AuthHelper] Token验证异常: $e');
      // 网络错误时认为token可能仍有效，避免不必要的登出
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        print('[AuthHelper] 网络错误，假设token有效');
        return true;
      }
      return false;
    }
  }

  /// 显示登录过期对话框
  ///
  /// [context] 当前上下文
  /// [message] 自定义消息，默认为"登录已过期，请重新登录"
  /// [onLogin] 登录成功回调
  static Future<bool?> showLoginExpiredDialog(
    BuildContext context, {
    String? message,
    VoidCallback? onLogin,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // 不允许点击外部关闭
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text(
                '登录提醒',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            message ?? '登录已过期，请重新登录',
            style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(
                '取消',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(true);
                // 显示登录页面
                final result = await _showLoginPage(context);
                if (result == true && onLogin != null) {
                  onLogin();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                '立即登录',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 显示登录页面
  static Future<bool?> _showLoginPage(BuildContext context) async {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (context) => LoginPage(
              onLoginSuccess: (userMap) {
                print('[AuthHelper] 登录成功: ${userMap['username']}');
              },
            ),
        fullscreenDialog: true,
      ),
    );
  }

  /// 检查是否需要登录并显示相应提示
  ///
  /// [context] 当前上下文
  /// [requireAuth] 是否需要强制登录
  /// [onLogin] 登录成功回调
  ///
  /// 返回 true 表示已登录或用户选择登录，false 表示未登录且用户取消
  static Future<bool> ensureAuthenticated(
    BuildContext context, {
    bool requireAuth = true,
    VoidCallback? onLogin,
    String? message,
  }) async {
    final isAuthenticated = await checkAuthStatus();

    if (isAuthenticated) {
      return true;
    }

    if (!requireAuth) {
      return false;
    }

    // 显示登录过期对话框
    final shouldLogin = await showLoginExpiredDialog(
      context,
      message: message,
      onLogin: onLogin,
    );

    return shouldLogin == true;
  }

  /// 处理认证失败的情况
  ///
  /// [context] 当前上下文
  /// [errorMessage] 错误消息
  /// [onLogin] 登录成功回调
  static Future<void> handleAuthFailure(
    BuildContext context, {
    String? errorMessage,
    VoidCallback? onLogin,
  }) async {
    // 清除本地登录状态
    await UserStore().logout();

    // 显示友好的错误提示
    final message = _parseAuthErrorMessage(errorMessage);

    if (context.mounted) {
      await showLoginExpiredDialog(context, message: message, onLogin: onLogin);
    }
  }

  /// 解析认证错误消息，返回用户友好的提示
  static String _parseAuthErrorMessage(String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) {
      return '登录已过期，请重新登录';
    }

    final lowerCase = errorMessage.toLowerCase();

    if (lowerCase.contains('过期') ||
        lowerCase.contains('expired') ||
        lowerCase.contains('timeout')) {
      return '登录已过期，请重新登录';
    }

    if (lowerCase.contains('无效') ||
        lowerCase.contains('invalid') ||
        lowerCase.contains('unauthorized')) {
      return '登录状态异常，请重新登录';
    }

    if (lowerCase.contains('网络') ||
        lowerCase.contains('network') ||
        lowerCase.contains('connection')) {
      return '网络连接异常，请检查网络后重试';
    }

    return '登录已过期，请重新登录';
  }

  /// 应用启动时的认证检查
  ///
  /// 在应用启动时调用，静默检查并处理登录状态
  static Future<void> initializeAuth() async {
    try {
      print('[AuthHelper] 应用启动，检查登录状态...');

      final user = UserStore().user;
      if (user == null || user.token == null || user.token!.isEmpty) {
        print('[AuthHelper] 用户未登录，跳过认证检查');
        return;
      }

      // 设置API Manager的token
      OvoApiManager().setToken(user.token!);

      // 静默验证token有效性
      final isValid = await checkAuthStatus();
      if (!isValid) {
        print('[AuthHelper] Token无效，清除本地登录状态');
        await UserStore().logout();
      } else {
        print('[AuthHelper] 登录状态有效');
      }
    } catch (e) {
      print('[AuthHelper] 初始化认证检查异常: $e');
    }
  }
}
