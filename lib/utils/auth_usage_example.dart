import 'package:flutter/material.dart';
import 'package:ovofun/utils/auth_helper.dart';

/// AuthHelper使用示例
///
/// 这个文件展示了如何在不同场景下使用AuthHelper
class AuthUsageExample {
  /// 示例1: 在需要登录的功能中使用
  static Future<void> exampleRequireLogin(BuildContext context) async {
    // 检查并确保用户已登录
    final isAuthenticated = await AuthHelper.ensureAuthenticated(
      context,
      requireAuth: true,
      message: '请登录后再使用此功能',
      onLogin: () {
        print('用户登录成功，可以继续执行功能');
      },
    );

    if (isAuthenticated) {
      // 用户已登录，执行需要认证的操作
      print('执行需要登录的功能...');
      // 在这里添加具体的业务逻辑
    } else {
      // 用户拒绝登录
      print('用户未登录，无法执行功能');
    }
  }

  /// 示例2: 在应用启动时检查登录状态
  static Future<void> exampleStartupCheck() async {
    final isAuthenticated = await AuthHelper.checkAuthStatus();

    if (isAuthenticated) {
      print('用户已登录，token有效');
      // 可以预加载用户相关数据
    } else {
      print('用户未登录或token无效');
      // 显示登录提示或引导用户登录
    }
  }

  /// 示例3: 处理API请求中的认证失败
  static Future<void> exampleHandleApiError(
    BuildContext context,
    String errorMessage,
  ) async {
    if (errorMessage.contains('登录已过期') || errorMessage.contains('认证失败')) {
      // 使用AuthHelper处理认证失败
      await AuthHelper.handleAuthFailure(
        context,
        errorMessage: errorMessage,
        onLogin: () {
          print('用户重新登录成功');
          // 可以重新发起之前失败的请求
        },
      );
    }
  }

  /// 示例4: 在Widget中使用认证检查
  static Widget exampleAuthWidget(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthHelper.checkAuthStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }

        final isAuthenticated = snapshot.data ?? false;

        if (isAuthenticated) {
          return Column(
            children: [
              Text('用户已登录'),
              ElevatedButton(
                onPressed: () async {
                  // 执行需要认证的操作
                  await exampleRequireLogin(context);
                },
                child: Text('执行认证功能'),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              Text('用户未登录'),
              ElevatedButton(
                onPressed: () async {
                  final result = await AuthHelper.showLoginExpiredDialog(
                    context,
                    message: '请先登录',
                  );
                  if (result == true) {
                    print('用户选择登录');
                  }
                },
                child: Text('立即登录'),
              ),
            ],
          );
        }
      },
    );
  }
}

/// 在现有页面中集成AuthHelper的示例
///
/// 这个mixin可以被添加到任何需要认证功能的页面中
mixin AuthMixin<T extends StatefulWidget> on State<T> {
  /// 确保用户已登录后执行操作
  Future<void> requireAuthThen(VoidCallback action) async {
    final isAuthenticated = await AuthHelper.ensureAuthenticated(
      context,
      requireAuth: true,
      onLogin: () {
        // 登录成功后执行原本的操作
        if (mounted) {
          action();
        }
      },
    );

    if (isAuthenticated) {
      action();
    }
  }

  /// 检查登录状态并显示相应UI
  Future<bool> checkAuthStatus() async {
    return await AuthHelper.checkAuthStatus();
  }

  /// 处理认证错误
  Future<void> handleAuthError(String errorMessage) async {
    await AuthHelper.handleAuthFailure(
      context,
      errorMessage: errorMessage,
      onLogin: () {
        if (mounted) {
          setState(() {
            // 刷新页面状态
          });
        }
      },
    );
  }
}
