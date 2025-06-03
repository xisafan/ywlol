import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:ovofun/home.dart'; // 替换为你的 HomeScreen 路径
import 'package:media_kit/media_kit.dart';
import 'package:ovofun/models/user_model.dart';
import 'package:umeng_common_sdk/umeng_common_sdk.dart';
import 'package:ovofun/services/api/ssl_Management.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:ovofun/page/models/color_models.dart';
import 'package:adaptive_theme/adaptive_theme.dart';

void main() async {
  // 确保优先初始化Flutter绑定
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // 申请权限
  await _ensurePermissions();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  MediaKit.ensureInitialized();
  await UserStore().init();
  // 启动时自动刷新用户token
  await UserStore.refreshTokenIfNeeded();

  // 异步预拉取所有分类扩展信息
  (() async {
    try {
      final api = OvoApiManager();
      final types = await api.getAllTypes();
      if (types is List) {
        for (final t in types) {
          final typeId = t['type_id'];
          if (typeId != null) {
            UserStore.fetchAndSaveExtends(int.tryParse(typeId.toString()) ?? 0);
          }
        }
      }
    } catch (e) {}
  })();

  // 友盟合规初始化
  UmengCommonSdk.initCommon('6839b337bc47b67d8377f515', '6839b82e79267e021075b52c', 'ovofun');
  UmengCommonSdk.setPageCollectionModeManual();
  UmengCommonSdk.onEvent('app_launch', {});

  // 恢复上次主题
  final savedThemeMode = await AdaptiveTheme.getThemeMode();
  runApp(MyApp(savedThemeMode: savedThemeMode));
}

Future<void> _ensurePermissions() async {
  if (Platform.isAndroid) {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        // 权限被拒绝，可以弹窗提示
        debugPrint('存储权限被拒绝，部分功能可能无法使用');
      }
    }
  }
}

class MyApp extends StatelessWidget {
  final AdaptiveThemeMode? savedThemeMode;
  const MyApp({Key? key, this.savedThemeMode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'AlibabaPuHuiTi',
        primaryColor: kPrimaryColor,
        scaffoldBackgroundColor: kBackgroundColor,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(fontWeight: FontWeight.w400),
        ),
      ),
      dark: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'AlibabaPuHuiTi',
        primaryColor: kPrimaryColor,
        scaffoldBackgroundColor: Color(0xFF1A1A1A),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(fontWeight: FontWeight.w400),
        ),
      ),
      initial: savedThemeMode ?? AdaptiveThemeMode.light,
      builder: (theme, darkTheme) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,
        home: SplashWrapper(),
      ),
    );
  }
}

class SplashWrapper extends StatefulWidget {
  @override
  _SplashWrapperState createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  bool _showNativeSplash = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    FlutterNativeSplash.remove();
    await Future.delayed(Duration(seconds: 2));
    if (mounted) {
      setState(() => _showNativeSplash = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _showNativeSplash ? _buildFullscreenSplash() : HomeScreen();
  }

  Widget _buildFullscreenSplash() {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: Colors.white),
          Positioned.fill(
            child: Image.asset(
              'assets/image/screen.png',
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}
