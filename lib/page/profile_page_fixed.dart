import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'mylike.dart';
import 'history_page.dart';
import 'download_page.dart';
import 'messages_page.dart';
import 'login_page.dart';
import 'account_settings_page.dart';
import '../theme/app_theme.dart';
import '../models/theme_notifier.dart';
import '../services/api/ssl_Management.dart';
import 'package:flutter/services.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onRefreshAllPages;

  const ProfilePage({Key? key, this.onRefreshAllPages}) : super(key: key);

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  String _appVersion = '';
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      //
    }
  }

  Widget _buildUserBlock() {
    final user = context.watch<UserStore>().user;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (user == null) {
              // 直接跳转到登录页�?              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            } else {
              // 跳转到账号设置页�?              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountSettingsPage(),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                // 头像区域 - 参考首页样�?                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child:
                        (() {
                          if (user != null &&
                              user.avatar != null &&
                              user.avatar!.isNotEmpty) {
                            // 显示用户头像（包括缓存的QQ头像�?                            String avatarUrl = user.avatar!;
                            // 如果是相对路径，转换为完整URL
                            if (avatarUrl.startsWith('/uploads/')) {
                              String baseUrl = OvoApiManager().baseUrl;
                              if (baseUrl.endsWith('/api.php')) {
                                baseUrl = baseUrl.substring(
                                  0,
                                  baseUrl.length - '/api.php'.length,
                                );
                              }
                              avatarUrl = baseUrl + avatarUrl;
                            }

                            return Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/image/touxiang.jpg',
                                  fit: BoxFit.cover,
                                );
                              },
                            );
                          } else {
                            // 如果没有头像，显示默认头�?                            return Image.asset(
                              'assets/image/touxiang.jpg',
                              fit: BoxFit.cover,
                            );
                          }
                        })(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.nickname ?? '点击登录',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color:
                              user != null
                                  ? Colors.black87
                                  : AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user != null ? '查看和编辑个人资�? : '登录后享受更多功�?,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSponsorCard() {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return Container(
          height: 50,
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                themeNotifier.primaryColor,
                themeNotifier.primaryColor.withOpacity(0.8),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'App的稳定运营离不开大家的支持~',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // TODO: 临时禁用激励广�?                  // print('激励广告功能临时不可用');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: themeNotifier.primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size(60, 26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  '赞助我们',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 登录弹窗方法已移除，现在直接跳转到登录页�?
  Widget _buildQuickActions() {
    final actions = [
      {
        'icon': 'assets/xml/heart.svg',
        'label': '我的收藏',
        'onTap': () => _navigateToFavorites(),
      },
      {
        'icon': 'assets/xml/history.svg',
        'label': '历史记录',
        'onTap': () => _navigateToHistory(),
      },
      {
        'icon': 'assets/xml/download.svg',
        'label': '离线缓存',
        'onTap': () => _navigateToDownloads(),
      },
      {
        'icon': 'assets/xml/message.svg',
        'label': '我的消息',
        'onTap': () => _navigateToMessages(),
      },
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ), // �?6减少�?
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((action) => _buildActionItem(action)).toList(),
      ),
    );
  }

  Widget _buildActionItem(Map<String, dynamic> action) {
    return GestureDetector(
      onTap: action['onTap'],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            action['icon'],
            width: 26,
            height: 26,
            colorFilter: ColorFilter.mode(Colors.grey[800]!, BlendMode.srcIn),
          ),
          const SizedBox(height: 6),
          Text(
            action['label'],
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalFeatures() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildFeatureCard(
              icon: 'assets/xml/book.svg',
              title: '入站问答',
              subtitle: '通过后才能发言�?,
              color: Colors.blue,
              onTap: () {
                _showQuizDialog();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFeatureCard(
              icon: 'assets/xml/paint.svg',
              title: '主题切换',
              subtitle: '挑选心仪的配色�?,
              color: Colors.purple,
              onTap: () {
                _showThemeDialog();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final dynamicColor = themeNotifier.primaryColor;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 70,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: dynamicColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      icon,
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                        dynamicColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 入站问答弹窗
  Future<void> _showQuizDialog() async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                SvgPicture.asset(
                  'assets/xml/book.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    Color(0xFF4ECDC4),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 8),
                Text('入站问答'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('完成入站问答后才能在评论区发言'),
                const SizedBox(height: 16),
                Text('📚 问题内容敬请期待'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('确定'),
              ),
            ],
          ),
    );
  }

  // 显示主题切换对话�?  void _showThemeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Consumer<ThemeNotifier>(
            builder:
                (context, themeNotifier, child) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: Container(
                    width: 250, // �?80缩小�?50
                    padding: EdgeInsets.all(0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14), // �?6缩小�?4
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08), // 减轻阴影
                          blurRadius: 12, // �?5缩小�?2
                          offset: Offset(0, 6), // �?缩小�?
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 标题�?                        Container(
                          padding: EdgeInsets.fromLTRB(
                            14,
                            14,
                            10,
                            10,
                          ), // 进一步缩小padding
                          child: Row(
                            children: [
                              Text(
                                '主题切换',
                                style: TextStyle(
                                  fontSize: 18, // �?0缩小�?8
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Spacer(),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 24, // �?8缩小�?4
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: themeNotifier.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14, // �?6缩小�?4
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 内容区域
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            14,
                            0,
                            14,
                            14,
                          ), // 进一步缩小padding
                          child: Column(
                            children: [
                              // 颜色选择网格布局（🌈精确对齐🔴位置）
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final totalWidth = constraints.maxWidth;
                                  final buttonWidth = 32.0;

                                  // MainAxisAlignment.spaceBetween的布局逻辑�?                                  // �?个按钮（索引0）：left = 0
                                  // �?个按钮（索引1）：left = (totalWidth - buttonWidth) * 1 / 4
                                  // �?个按钮（索引4）：left = totalWidth - buttonWidth
                                  final pinkButtonLeft =
                                      (totalWidth - buttonWidth) * 1 / 4;

                                  return Column(
                                    children: [
                                      // 第一行：5个预设颜�?                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildColorOption(
                                            ThemeColor.blue,
                                            themeNotifier,
                                          ),
                                          _buildColorOption(
                                            ThemeColor.pink,
                                            themeNotifier,
                                          ),
                                          _buildColorOption(
                                            ThemeColor.purple,
                                            themeNotifier,
                                          ),
                                          _buildColorOption(
                                            ThemeColor.cyan,
                                            themeNotifier,
                                          ),
                                          _buildColorOption(
                                            ThemeColor.red,
                                            themeNotifier,
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 14),
                                      // 第二行：🟠对齐🔵，🌈对齐🔴（粉色�?                                      SizedBox(
                                        height: 32,
                                        width: totalWidth,
                                        child: Stack(
                                          children: [
                                            // 🟠橙色按钮（与🔵蓝色对齐�?                                            Positioned(
                                              left: 0, // 与第1个位置对�?                                              child: _buildColorOption(
                                                ThemeColor.orange,
                                                themeNotifier,
                                              ),
                                            ),
                                            // 🌈自定义按钮（与🔴粉色精确对齐）
                                            Positioned(
                                              left:
                                                  pinkButtonLeft, // 与第2个位置精确对�?                                              child: _buildCustomColorOption(
                                                themeNotifier,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),

                              SizedBox(height: 20), // �?4缩小�?0
                              // 深色模式开�?                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '深色模式�?,
                                      style: TextStyle(
                                        fontSize: 14, // �?6缩小�?4
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Switch(
                                      value: false, // TODO: 实现深色模式状态管�?                                      onChanged: (value) {
                                        // TODO: 实现深色模式切换
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('深色模式功能待实�?)),
                                        );
                                      },
                                      activeColor: themeNotifier.primaryColor,
                                      inactiveThumbColor: Colors.grey[400],
                                      inactiveTrackColor: Colors.grey[300],
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 18), // �?0缩小�?8
                              // 重启按钮
                              Container(
                                width: double.infinity,
                                height: 40, // �?4缩小�?0
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showRestartDialog();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: themeNotifier.primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        10,
                                      ), // �?2缩小�?0
                                    ),
                                  ),
                                  child: Text(
                                    '重启以应用主�?,
                                    style: TextStyle(
                                      fontSize: 15, // �?6缩小�?5
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  // 构建自定义颜色选择�?  Widget _buildCustomColorOption(ThemeNotifier themeNotifier) {
    final isSelected = themeNotifier.currentTheme == ThemeColor.custom;

    return GestureDetector(
      onTap: () => _showColorPicker(themeNotifier),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border:
              isSelected
                  ? Border.all(color: Colors.white, width: 2.0)
                  : Border.all(color: Colors.grey[300]!, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
            if (isSelected)
              BoxShadow(
                color: AppTheme.customColor.withOpacity(0.25),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
          ],
        ),
        child: Stack(
          children: [
            // 彩虹渐变背景
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.red,
                    Colors.orange,
                    Colors.yellow,
                    Colors.green,
                    Colors.blue,
                    Colors.purple,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // 自定义颜色覆盖层
            if (isSelected)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.customColor,
                  shape: BoxShape.circle,
                ),
              ),
            // 图标或选中标记
            if (isSelected)
              Center(child: Icon(Icons.check, color: Colors.white, size: 16))
            else
              Center(child: Icon(Icons.palette, color: Colors.white, size: 16)),
          ],
        ),
      ),
    );
  }

  // 构建颜色选择�?  Widget _buildColorOption(ThemeColor theme, ThemeNotifier themeNotifier) {
    final color = AppTheme.getThemeColor(theme);
    final isSelected = themeNotifier.currentTheme == theme;

    return GestureDetector(
      onTap: () async {
        await themeNotifier.setTheme(theme);
      },
      child: Container(
        width: 32, // �?6缩小�?2
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border:
              isSelected
                  ? Border.all(color: Colors.white, width: 2.0)
                  : null, // �?.5缩小�?.0
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08), // 减轻阴影
              blurRadius: 6, // �?缩小�?
              offset: Offset(0, 1), // �?缩小�?
            ),
            if (isSelected)
              BoxShadow(
                color: color.withOpacity(0.25), // 减轻选中阴影
                blurRadius: 10, // �?2缩小�?0
                offset: Offset(0, 3), // �?缩小�?
              ),
          ],
        ),
        child:
            isSelected
                ? Icon(Icons.check, color: Colors.white, size: 16) // �?8缩小�?6
                : null,
      ),
    );
  }

  // 显示重启提示对话�?  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text('主题已更�?),
            content: Text('需要重启应用以完全应用新主题，是否立即重启�?),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('稍后'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _restartApp();
                },
                child: Text('立即重启'),
              ),
            ],
          ),
    );
  }

  // 重启应用
  void _restartApp() {
    exit(0);
  }

  // 显示自定义颜色选择�?  Future<void> _showColorPicker(ThemeNotifier themeNotifier) async {
    Color selectedColor = AppTheme.customColor;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(Icons.palette, color: themeNotifier.primaryColor),
                      SizedBox(width: 8),
                      Text('自定义颜�?),
                    ],
                  ),
                  content: SizedBox(
                    width: 280,
                    height: 320,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // 当前选中颜色预览
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              color: selectedColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Center(
                              child: Text(
                                '预览颜色',
                                style: TextStyle(
                                  color:
                                      selectedColor.computeLuminance() > 0.5
                                          ? Colors.black
                                          : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          // 色相�?                          _buildHueSlider(selectedColor, (color) {
                            setState(() {
                              selectedColor = color;
                            });
                          }),
                          SizedBox(height: 12),
                          // 饱和�?亮度选择面板
                          _buildSaturationLightnessPanel(selectedColor, (
                            color,
                          ) {
                            setState(() {
                              selectedColor = color;
                            });
                          }),
                          SizedBox(height: 12),
                          // 预设颜色快捷选择
                          _buildPresetColors((color) {
                            setState(() {
                              selectedColor = color;
                            });
                          }),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('取消'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await AppTheme.setCustomColor(selectedColor);
                        await themeNotifier.setTheme(ThemeColor.custom);
                        Navigator.pop(context);
                        Navigator.pop(context); // 关闭主题切换对话�?                        _showRestartDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedColor,
                        foregroundColor:
                            selectedColor.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                      ),
                      child: Text('确定'),
                    ),
                  ],
                ),
          ),
    );
  }

  // 构建色相滑块
  Widget _buildHueSlider(Color currentColor, Function(Color) onColorChanged) {
    final HSLColor hslColor = HSLColor.fromColor(currentColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('色相', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final sliderWidth = constraints.maxWidth;
            final indicatorSize = 12.0;

            return Container(
              width: double.infinity,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [
                    Colors.red,
                    Colors.yellow,
                    Colors.green,
                    Colors.cyan,
                    Colors.blue,
                    Colors.purple,
                    Colors.red,
                  ],
                ),
              ),
              child: GestureDetector(
                onTapDown: (details) {
                  final localX = details.localPosition.dx;
                  final hue = (localX / sliderWidth).clamp(0.0, 1.0) * 360;
                  final newColor = hslColor.withHue(hue).toColor();
                  onColorChanged(newColor);
                },
                onPanUpdate: (details) {
                  final localX = details.localPosition.dx;
                  final hue = (localX / sliderWidth).clamp(0.0, 1.0) * 360;
                  final newColor = hslColor.withHue(hue).toColor();
                  onColorChanged(newColor);
                },
                child: Stack(
                  children: [
                    // 指示�?                    Positioned(
                      left: (hslColor.hue / 360 * sliderWidth -
                              indicatorSize / 2)
                          .clamp(0.0, sliderWidth - indicatorSize),
                      top: (20 - indicatorSize) / 2,
                      child: Container(
                        width: indicatorSize,
                        height: indicatorSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey[600]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(
                            indicatorSize / 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 构建饱和�?亮度选择面板
  Widget _buildSaturationLightnessPanel(
    Color currentColor,
    Function(Color) onColorChanged,
  ) {
    final HSLColor hslColor = HSLColor.fromColor(currentColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '饱和度和明度',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final panelWidth = constraints.maxWidth;
            final panelHeight = 100.0;
            final indicatorSize = 12.0;

            return Container(
              width: double.infinity,
              height: panelHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onTapDown: (details) {
                    final localX = details.localPosition.dx;
                    final localY = details.localPosition.dy;

                    final saturation = (localX / panelWidth).clamp(0.0, 1.0);
                    final lightness =
                        1.0 - (localY / panelHeight).clamp(0.0, 1.0);

                    final newColor =
                        hslColor
                            .withSaturation(saturation)
                            .withLightness(lightness)
                            .toColor();
                    onColorChanged(newColor);
                  },
                  onPanUpdate: (details) {
                    final localX = details.localPosition.dx;
                    final localY = details.localPosition.dy;

                    final saturation = (localX / panelWidth).clamp(0.0, 1.0);
                    final lightness =
                        1.0 - (localY / panelHeight).clamp(0.0, 1.0);

                    final newColor =
                        hslColor
                            .withSaturation(saturation)
                            .withLightness(lightness)
                            .toColor();
                    onColorChanged(newColor);
                  },
                  child: Stack(
                    children: [
                      // 饱和度渐变背�?                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white,
                              HSLColor.fromAHSL(
                                1,
                                hslColor.hue,
                                1,
                                0.5,
                              ).toColor(),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                      // 亮度覆盖�?                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // 当前位置指示�?                      Positioned(
                        left: (hslColor.saturation * panelWidth -
                                indicatorSize / 2)
                            .clamp(0.0, panelWidth - indicatorSize),
                        top: ((1.0 - hslColor.lightness) * panelHeight -
                                indicatorSize / 2)
                            .clamp(0.0, panelHeight - indicatorSize),
                        child: Container(
                          width: indicatorSize,
                          height: indicatorSize,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.grey[600]!,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(
                              indicatorSize / 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 构建预设颜色快捷选择
  Widget _buildPresetColors(Function(Color) onColorChanged) {
    final presetColors = [
      Color(0xFFFF5722), // 深橙
      Color(0xFF9C27B0), // 紫色
      Color(0xFF3F51B5), // 靛蓝
      Color(0xFF2196F3), // 蓝色
      Color(0xFF00BCD4), // 青色
      Color(0xFF4CAF50), // 绿色
      Color(0xFFFFEB3B), // 黄色
      Color(0xFFFF9800), // 橙色
      Color(0xFFE91E63), // 粉红
      Color(0xFF795548), // 棕色
      Color(0xFF607D8B), // 蓝灰
      Color(0xFF9E9E9E), // 灰色
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '快捷选择',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              presetColors
                  .map(
                    (color) => GestureDetector(
                      onTap: () => onColorChanged(color),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }

  Future<void> refreshAvatarAndNickname() async {
    setState(() {});
  }

  Widget _buildVersion() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Center(
        child: Text(
          '版本号：$_appVersion',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ),
    );
  }

  Future<void> _handleExternalUpdate(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw '无法打开链接';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('打开链接失败: $e')));
      }
    }
  }

  Future<void> _showDownloadProgress() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text('正在下载更新'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(value: _downloadProgress),
                      SizedBox(height: 16),
                      Text('${(_downloadProgress * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildSettingsGroup1() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingItem({
            'icon': 'assets/xml/feedback.svg',
            'title': '建议反馈',
            'onTap': () => _showFeedbackDialog(),
          }),
          Divider(height: 1, color: Colors.grey[200]),
          _buildSettingItem({
            'icon': 'assets/xml/share.svg',
            'title': '分享应用',
            'onTap': () => _shareApp(),
          }),
          Divider(height: 1, color: Colors.grey[200]),
          _buildSettingItem({
            'icon': 'assets/xml/line.svg',
            'title': '切换线路',
            'onTap': () => _switchLineRoute(),
          }),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup2() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingItem({
            'icon': 'assets/xml/disclaimer.svg',
            'title': '免责声明',
            'onTap': () => _showDisclaimerDialog(),
          }),
          Divider(height: 1, color: Colors.grey[200]),
          _buildSettingItem({
            'icon': 'assets/xml/update.svg',
            'title': '检测更�?,
            'onTap': () => _checkForUpdates(),
          }),
          Divider(height: 1, color: Colors.grey[200]),
          _buildSettingItem({
            'icon': 'assets/xml/settings.svg',
            'title': '数据恢复',
            'onTap': () => _showComingSoon('数据恢复功能'),
          }),
        ],
      ),
    );
  }

  Widget _buildSettingItem(Map<String, dynamic> setting) {
    return InkWell(
      onTap: setting['onTap'],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SvgPicture.asset(
              setting['icon'],
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(Colors.grey[600]!, BlendMode.srcIn),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                setting['title'],
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    // 显示检查更新加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 200,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade600,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '正在检查更�?..',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 调用更新检查API
      final api = OvoApiManager();
      final resp = await api.get(
        '/v1/check_update',
        queryParameters: {
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'version': currentVersion,
        },
      );

      // 关闭加载对话�?      if (mounted) {
        Navigator.pop(context);
      }

      if (resp is Map && resp['code'] == 0) {
        final data = resp['data'] as Map;
        final bool hasUpdate = data['has_update'] == true;
        final bool forceUpdate = data['force_update'] == true;
        final String updateUrl = data['download_url'] as String? ?? '';
        final String browserUrl = data['browser_url'] as String? ?? '';
        final String serverVersion = data['version'] as String? ?? '';
        final String description = data['description'] as String? ?? '';

        if (hasUpdate && mounted) {
          // 确定更新方式
          String finalUpdateUrl = updateUrl.isNotEmpty ? updateUrl : browserUrl;
          String updateMethod =
              browserUrl.isNotEmpty && updateUrl.isEmpty
                  ? 'external'
                  : 'direct';

          final String packageSize = data['package_size'] as String? ?? '未知';
          final String updateTime = data['update_time'] as String? ?? '未知';
          final String appTitle =
              data['title'] as String? ?? '发现新版�?v$serverVersion';

          await _showNewUpdateDialog(
            title: appTitle,
            content:
                description.isNotEmpty
                    ? description
                    : '发现新版本，建议立即更新以获得更好的使用体验�?,
            updateUrl: finalUpdateUrl,
            updateMethod: updateMethod,
            barrierDismissible: !forceUpdate,
            showCancelButton: !forceUpdate,
            onCancel:
                forceUpdate
                    ? () {
                      if (Platform.isAndroid) {
                        SystemNavigator.pop();
                      } else if (Platform.isIOS) {
                        exit(0);
                      }
                    }
                    : null,
            forceUpdate: forceUpdate,
            currentVersion: currentVersion,
            newVersion: serverVersion,
            packageSize: packageSize,
            updateTime: updateTime,
            browserUrl: browserUrl.isNotEmpty ? browserUrl : null,
          );
        } else if (mounted) {
          // 当前已是最新版�?          _showNoUpdateDialog();
        }
      } else {
        // API调用失败
        if (mounted) {
          _showUpdateErrorDialog('检查更新失败，请稍后重�?);
        }
      }
    } catch (e) {
      // 关闭加载对话�?      if (mounted) {
        Navigator.pop(context);
        _showUpdateErrorDialog('网络错误，请检查网络连�?);
      }
    }
  }

  // 显示无更新对话框
  void _showNoUpdateDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 头部
                  Container(
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(color: Colors.green.shade600),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 32,
                          color: Colors.white,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '已是最新版�?,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 内容
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          '您当前使用的已经是最新版本，无需更新�?,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(0),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              '好的',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // 显示更新错误对话�?  void _showUpdateErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 头部
                  Container(
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(color: Colors.orange.shade600),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning_outlined,
                          size: 32,
                          color: Colors.white,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '检查更新失�?,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 内容
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(0),
                                  ),
                                  foregroundColor: Colors.black87,
                                ),
                                child: Text(
                                  '取消',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _checkForUpdates(); // 重试
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(0),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  '重试',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // 显示更新对话�?  Future<void> _showNewUpdateDialog({
    required String title,
    required String content,
    required String updateUrl,
    required String updateMethod,
    bool barrierDismissible = true,
    bool showCancelButton = true,
    VoidCallback? onCancel,
    bool forceUpdate = false,
    String? currentVersion,
    String? newVersion,
    String? packageSize,
    String? updateTime,
    String? browserUrl,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        // 弹窗内局部状�?        bool isDownloading = false;
        double downloadProgress = 0.0;
        bool downloadComplete = false;
        String downloadedPath = '';

        // 辅助方法
        String getCurrentVersion() => currentVersion ?? '未知版本';
        String getNewVersion() => newVersion ?? '未知版本';
        String getPackageSize() => packageSize ?? '未知大小';
        String getUpdateTime() => updateTime ?? '未知时间';
        String getBrowserUrl() => browserUrl ?? updateUrl;

        Widget _buildInfoRow(String label, String value) {
          return Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 80,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Future<void> handleDownload(StateSetter setState) async {
          if (isDownloading) return;
          setState(() {
            isDownloading = true;
            downloadProgress = 0;
            downloadComplete = false;
            downloadedPath = '';
          });

          final dio = Dio();
          dio.options.connectTimeout = const Duration(seconds: 30);
          dio.options.receiveTimeout = const Duration(seconds: 30);

          try {
            final dir = await getExternalStorageDirectory();
            if (dir == null) throw '无法获取存储目录';
            final savePath = '${dir.path}/app-update.apk';

            await dio.download(
              updateUrl,
              savePath,
              onReceiveProgress: (received, total) {
                if (total != -1) {
                  setState(() {
                    downloadProgress = received / total;
                  });
                }
              },
              options: Options(
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Android) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                },
                followRedirects: true,
                validateStatus: (status) => status != null && status < 500,
              ),
            );

            setState(() {
              isDownloading = false;
              downloadComplete = true;
              downloadedPath = savePath;
            });
          } catch (e) {
            setState(() {
              isDownloading = false;
              downloadProgress = 0;
              downloadComplete = false;
              downloadedPath = '';
            });
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('下载失败: $e')));
            }
          }
        }

        Future<void> handleInstall() async {
          if (downloadedPath.isEmpty) return;
          if (Platform.isAndroid) {
            final status = await Permission.requestInstallPackages.status;
            if (!status.isGranted) {
              final result = await Permission.requestInstallPackages.request();
              if (!result.isGranted) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('需要安装权限才能继�?)));
                }
                return;
              }
            }
          }
          try {
            final result = await OpenFile.open(downloadedPath);
            if (result.type != ResultType.done) {
              throw '安装失败: ${result.message}';
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('安装失败: ${e.toString()}')));
            }
          }
        }

        return StatefulBuilder(
          builder:
              (context, setState) => WillPopScope(
                onWillPop: () async => barrierDismissible,
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(0), // 矩形设计
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 头部区域 - 参考热门新番样�?                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Stack(
                            children: [
                              // 版本更新标题 - 参考热门新番样�?                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    children: <Widget>[
                                      Positioned(
                                        left: 0.0,
                                        top: 0.0,
                                        bottom: 1.4,
                                        width: 28.0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.primaryColor.withOpacity(0.58),
                                                AppTheme.primaryColor.withOpacity(0.0),
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          4.0,
                                          0.6,
                                          0.0,
                                          0.0,
                                        ),
                                        child: Text(
                                          '版本更新',
                                          style: const TextStyle(
                                            fontFamily: 'FZLanTingHeiS-EB-GB',
                                            fontSize: 18,
                                            color: Color(0xff000000),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          softWrap: false,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // 关闭按钮 - 只有在非强制更新时显�?                              if (barrierDismissible)
                                Positioned(
                                  top: -8,
                                  right: -8,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      if (onCancel != null) onCancel();
                                    },
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.black54,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // 内容区域
                        Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 应用标题（不显示图标�?                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryLightColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '最新版�?,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: 20),
                              
                              // 版本信息
                              _buildInfoRow('版本更新', '${getCurrentVersion()} �?${getNewVersion()}'),
                              _buildInfoRow('文件大小', getPackageSize()),
                              _buildInfoRow('更新时间', getUpdateTime()),
                              
                              SizedBox(height: 16),
                              
                              // 更新内容
                              Text(
                                '更新内容',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  content.isNotEmpty ? content : '修复已知问题，提升用户体验�?,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                ),
                              ),

                              SizedBox(height: 24),
                              
                              // 按钮区域
                              Row(
                                children: [
                                  // 浏览器打开按钮
                                  Expanded(
                                    child: Container(
                                      height: 48,
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          try {
                                            final uri = Uri.parse(getBrowserUrl());
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(
                                                uri,
                                                mode: LaunchMode.externalApplication,
                                              );
                                            } else {
                                              throw '无法打开链接';
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('打开链接失败: $e')),
                                            );
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: AppTheme.primaryColor,
                                            width: 1.5,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          foregroundColor: AppTheme.primaryColor,
                                        ),
                                        child: Text(
                                          '浏览器打开',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  SizedBox(width: 12),

                                  // 立即更新按钮
                                  Expanded(
                                    child: Container(
                                      height: 48,
                                      child: Stack(
                                        children: [
                                          // 背景容器
                                          Container(
                                            height: 48,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: downloadComplete
                                                  ? Colors.green
                                                  : (!isDownloading && !downloadComplete)
                                                  ? AppTheme.primaryColor
                                                  : Colors.grey.shade300,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          
                                          // 下载进度�?                                          if (isDownloading)
                                            AnimatedContainer(
                                              duration: Duration(milliseconds: 300),
                                              height: 48,
                                              width: MediaQuery.of(context).size.width * 
                                                     0.9 * 0.4 * downloadProgress,
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor.withOpacity(0.8),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                          
                                          // 按钮
                                          SizedBox(
                                            height: 48,
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: isDownloading
                                                  ? null
                                                  : downloadComplete
                                                  ? handleInstall
                                                  : () => handleDownload(setState),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                foregroundColor: Colors.white,
                                                shadowColor: Colors.transparent,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: Text(
                                                downloadComplete
                                                    ? '立即安装'
                                                    : isDownloading
                                                    ? '下载�?${(downloadProgress * 100).toInt()}%'
                                                    : '立即更新',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFeedbackDialog() async {
    final TextEditingController feedbackController = TextEditingController();
    final TextEditingController contactController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SvgPicture.asset(
                'assets/xml/feedback.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  Colors.orange,
                  BlendMode.srcIn,
                ),
              ),
            ),
            SizedBox(width: 12),
            Text('建议反馈'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '您的意见对我们很重要，我们会认真对待每一条反馈�?,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '反馈内容',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: feedbackController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '请描述您遇到的问题或建议...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.orange),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '联系方式（选填�?,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: contactController,
                decoration: InputDecoration(
                  hintText: 'QQ/微信/邮箱等联系方�?,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.orange),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final feedback = feedbackController.text.trim();
              final contact = contactController.text.trim();

              if (feedback.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('请输入反馈内�?),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('反馈功能待实现，感谢您的意见�?),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('网络错误，请稍后再试'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('提交反馈'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildUserBlock(),
              _buildSponsorCard(),
              _buildQuickActions(),
              _buildAdditionalFeatures(),
              _buildSettingsGroup1(),
              _buildSettingsGroup2(),
              SizedBox(height: 20),
              _buildVersion(),
              SizedBox(height: 30),
            ]),
          ),
        ],
      ),
    );
}
