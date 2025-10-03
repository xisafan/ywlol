import 'package:flutter/material.dart';

// 颜色常量
const Color kPrimaryColor = Color(0xFF6200EA);
const Color kSecondaryColor = Color(0xFF03DAC6);
const Color kBackgroundColor = Color(0xFFF5F5F5);
const Color kSurfaceColor = Color(0xFFFFFFFF);
const Color kErrorColor = Color(0xFFB00020);

// 文字颜色
const Color kTextColor = Color(0xFF212121);
const Color kTextColorLight = Color(0xFF757575);
const Color kSecondaryTextColor = Color(0xFF9E9E9E);

// 边框和分割线颜色
const Color kDividerColor = Color(0xFFE0E0E0);
const Color kBorderColor = Color(0xFFBDBDBD);

// 状态颜色
const Color kSuccessColor = Color(0xFF4CAF50);
const Color kWarningColor = Color(0xFFFF9800);
const Color kInfoColor = Color(0xFF2196F3);

// 尺寸常量
const double kPaddingSmall = 8.0;
const double kPaddingMedium = 16.0;
const double kPaddingLarge = 24.0;

const double kBorderRadius = 8.0;
const double kBorderRadiusLarge = 16.0;

const double kElevation = 4.0;
const double kElevationLow = 2.0;
const double kElevationHigh = 8.0;

// 文字尺寸
const double kFontSizeSmall = 12.0;
const double kFontSizeMedium = 14.0;
const double kFontSizeLarge = 16.0;
const double kFontSizeXLarge = 18.0;
const double kFontSizeXXLarge = 20.0;

// 动画时长
const Duration kAnimationDuration = Duration(milliseconds: 300);
const Duration kAnimationDurationFast = Duration(milliseconds: 150);
const Duration kAnimationDurationSlow = Duration(milliseconds: 500);

// API相关常量
const int kTimeoutSeconds = 30;
const int kRetryAttempts = 3;

// 页面尺寸
const double kAppBarHeight = 56.0;
const double kBottomNavigationHeight = 60.0;
const double kTabBarHeight = 48.0;

// 视频播放器常量
const double kVideoAspectRatio = 16.0 / 9.0;
const Duration kVideoControlsTimeout = Duration(seconds: 5);
const Duration kVideoSeekDuration = Duration(seconds: 10);

// 缓存常量
const int kCacheMaxSize = 100 * 1024 * 1024; // 100MB
const Duration kCacheExpiration = Duration(days: 7);

// 分页常量
const int kPageSize = 20;
const int kMaxPageSize = 100;

// 正则表达式常量
const String kEmailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
const String kPhoneRegex = r'^1[3-9]\d{9}$';
const String kPasswordRegex = r'^(?=.*[a-zA-Z])(?=.*\d).{6,20}$';

// 路由名称
class RouteNames {
  static const String home = '/home';
  static const String login = '/login';
  static const String register = '/register';
  static const String profile = '/profile';
  static const String video = '/video';
  static const String search = '/search';
  static const String ranking = '/ranking';
  static const String history = '/history';
  static const String download = '/download';
  static const String settings = '/settings';
}

// 错误消息
class ErrorMessages {
  static const String networkError = '网络连接失败，请检查网络设置';
  static const String serverError = '服务器错误，请稍后重试';
  static const String timeoutError = '请求超时，请稍后重试';
  static const String unknownError = '未知错误，请稍后重试';
  static const String loginRequired = '请先登录';
  static const String permissionDenied = '权限不足';
  static const String dataNotFound = '数据不存在';
  static const String invalidInput = '输入格式不正确';
}

// 成功消息
class SuccessMessages {
  static const String loginSuccess = '登录成功';
  static const String registerSuccess = '注册成功';
  static const String updateSuccess = '更新成功';
  static const String deleteSuccess = '删除成功';
  static const String saveSuccess = '保存成功';
}

// 键名常量
class PrefsKeys {
  static const String isFirstLaunch = 'is_first_launch';
  static const String userToken = 'user_token';
  static const String userId = 'user_id';
  static const String selectedDomain = 'selected_domain';
  static const String themeMode = 'theme_mode';
  static const String watchHistory = 'watch_history';
  static const String searchHistory = 'search_history';
  static const String favoriteList = 'favorite_list';
  static const String downloadQuality = 'download_quality';
  static const String autoPlay = 'auto_play';
}



















