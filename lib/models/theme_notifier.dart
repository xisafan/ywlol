import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 主题变化通知器
class ThemeNotifier extends ChangeNotifier {
  static final ThemeNotifier _instance = ThemeNotifier._internal();
  factory ThemeNotifier() => _instance;
  ThemeNotifier._internal();

  ThemeColor _currentTheme = AppTheme.currentTheme;

  ThemeColor get currentTheme => _currentTheme;
  Color get primaryColor => AppTheme.getThemeColor(_currentTheme);

  /// 切换主题
  Future<void> setTheme(ThemeColor theme) async {
    _currentTheme = theme;
    await AppTheme.setTheme(theme);
    notifyListeners();
  }

  /// 更新当前主题（用于初始化）
  void updateCurrentTheme() {
    _currentTheme = AppTheme.currentTheme;
    notifyListeners();
  }
}
