import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题颜色枚举
enum ThemeColor {
  blue, // 蓝色
  pink, // 粉色
  purple, // 紫色
  cyan, // 青色（默认）
  red, // 红色
  orange, // 橙色
  custom, // 自定义颜色
}

/// 应用主题管理器
class AppTheme {
  static const String _themeKey = 'app_theme';

  /// 主题颜色映射
  static const Map<ThemeColor, Color> _themeColors = {
    ThemeColor.blue: Color.fromARGB(238, 0, 4, 5), // 黑色
    ThemeColor.pink: Color.fromARGB(147, 242, 7, 81), // 粉色
    ThemeColor.purple: Color.fromARGB(255, 214, 2, 252), // 紫色
    ThemeColor.cyan: Color.fromARGB(255, 4, 248, 231), // 青色（默认）
    ThemeColor.red: Color.fromARGB(255, 245, 18, 2), // 红色
    ThemeColor.orange: Color.fromARGB(255, 255, 196, 0), // 橙色
    ThemeColor.custom: Color(0xFF6200EA), // 自定义（默认紫色）
  };

  /// 自定义颜色
  static Color _customColor = Color(0xFF6200EA);

  /// 主题颜色名称
  static const Map<ThemeColor, String> _themeNames = {
    ThemeColor.blue: '黑色主题',
    ThemeColor.pink: '粉色主题',
    ThemeColor.purple: '紫色主题',
    ThemeColor.cyan: '青色主题',
    ThemeColor.red: '红色主题',
    ThemeColor.orange: '橙色主题',
    ThemeColor.custom: '自定义主题',
  };

  /// 当前主题颜色
  static ThemeColor _currentTheme = ThemeColor.cyan;

  /// 获取当前主题颜色
  static Color get primaryColor =>
      _currentTheme == ThemeColor.custom
          ? _customColor
          : _themeColors[_currentTheme]!;

  /// 获取当前主题枚举
  static ThemeColor get currentTheme => _currentTheme;

  /// 获取所有主题颜色
  static List<ThemeColor> get allThemes => ThemeColor.values;

  /// 获取主题颜色
  static Color getThemeColor(ThemeColor theme) =>
      theme == ThemeColor.custom ? _customColor : _themeColors[theme]!;

  /// 获取主题名称
  static String getThemeName(ThemeColor theme) => _themeNames[theme]!;

  /// 初始化主题
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeColor.cyan.index;
    _currentTheme = ThemeColor.values[themeIndex];

    // 加载自定义颜色
    final customColorValue = prefs.getInt('customThemeColor');
    if (customColorValue != null) {
      _customColor = Color(customColorValue);
    }
  }

  /// 设置主题
  static Future<void> setTheme(ThemeColor theme) async {
    _currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, theme.index);
  }

  /// 设置自定义颜色
  static Future<void> setCustomColor(Color color) async {
    _customColor = color;
    _currentTheme = ThemeColor.custom;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('customThemeColor', color.value);
    await prefs.setInt(_themeKey, ThemeColor.custom.index);
  }

  /// 获取自定义颜色
  static Color get customColor => _customColor;

  /// 获取渐变色（用于赞助卡片）
  static LinearGradient get primaryGradient {
    final color = primaryColor;
    return LinearGradient(
      colors: [color, color.withOpacity(0.8)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }

  /// 获取浅色版本（用于背景）
  static Color get primaryLightColor => primaryColor.withOpacity(0.1);

  /// 获取深色版本（用于文字）
  static Color get primaryDarkColor {
    final hsl = HSLColor.fromColor(primaryColor);
    return hsl.withLightness(0.3).toColor();
  }
}
