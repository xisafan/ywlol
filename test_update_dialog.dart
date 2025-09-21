// 测试更新弹窗的临时文件
// 使用方法：将此代码添加到您的页面中进行测试

import 'package:flutter/material.dart';

class UpdateTestHelper {
  static void showTestUpdateDialog(BuildContext context) {
    // 模拟API返回的更新数据
    final testData = {
      'has_update': true,
      'platform': 'android',
      'version': '1.0.1',
      'current_version': '1.0.0',
      'title': 'QwQFun Android版 V2.0.8',
      'download_url': 'https://download.qwqfun.com/qwqfun-v2.0.8.apk',
      'browser_url': 'https://qwqfun.com/android-update',
      'description': '紧急修复安全漏洞，建议立即更新。优化了内存使用，提升了应用启动速度。',
      'package_size': '32.8MB',
      'force_update': false, // 设为true测试强制更新
      'update_time': '2025-09-19 20:50:38'
    };

    // 这里调用您的更新弹窗方法
    // 例如：_showNewUpdateDialog(...) 
    // 根据您的具体代码调整参数
  }

  // 测试按钮组件
  static Widget buildTestButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => showTestUpdateDialog(context),
      child: Text('测试更新弹窗'),
    );
  }
}

// 使用示例：
// 在您的页面中添加这个按钮来测试更新弹窗
// UpdateTestHelper.buildTestButton(context)






