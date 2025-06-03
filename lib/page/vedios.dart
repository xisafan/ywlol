import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ovofun/services/api/ssl_Management.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:ovofun/page/models/Videostreaming.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:castscreen/castscreen.dart';
import 'package:ovofun/models/user_model.dart';
import 'package:ovofun/page/models/color_models.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:ovofun/page/download_page.dart';
import 'package:ovofun/services/download_manager.dart';
enum AspectRatioMode { auto, stretch, cover, ratio16_9, ratio4_3 }
class VideoBlurbDetailPage extends StatelessWidget {
  final String title;
  final String blurb;

  const VideoBlurbDetailPage({
    Key? key,
    required this.title,
    required this.blurb,
  }) : super(key: key);
  //101
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: TextStyle(color: Colors.black87, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Text(
          blurb,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class VideoDetailPage extends StatefulWidget {
  final int vodId;
  final int? initialEpisodeIndex;
  final String? initialPlayFrom;
  final int? initialPositionSeconds;

  const VideoDetailPage({
    Key? key,
    required this.vodId,
    this.initialEpisodeIndex,
    this.initialPlayFrom,
    this.initialPositionSeconds,
  }) : super(key: key);

  @override
  _VideoDetailPageState createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> with TickerProviderStateMixin {
  final OvoApiManager _apiManager = OvoApiManager();
  final ScrollController _episodeScrollController = ScrollController();
  final ScrollController _mainScrollController = ScrollController();


  bool _isPipAvailable = false;

  // 视频详情数据1
  Map<String, dynamic>? _videoDetail;
  bool _isLoading = true;
  String? _errorMessage;

  // 视频播放器相关1
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlayerInitializing = false;
  bool _isPlaying = false;
  bool _isFullScreen = false;
  String _currentPlayUrl = '';
  bool _videoStarted = false;

  // 新增：播放器信息map
  Map<String, dynamic> _playerMap = {};

  // 新增：自动播放下一集标志
  bool _autoPlayNextEpisode = true;

  // 新增：视频播放完成标志
  bool _videoCompleted = false;

  // 播放源和选集相关
  List<String> _playFromList = []; 
  int _currentPlayFromIndex = 0;

  List<List<Map<String, String>>> _playUrlsList = []; // 所有播放源的播放地址列表
  int _currentEpisodeIndex = 0; // 当前选中的集数索引
  int _maxEpisodes = 0; // 最大集数

  // 选集弹窗控制
  bool _showEpisodePopup = false;
  bool _isReverseSort = false;

  // 详情展开控制
  bool _isDetailExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // 评论相关
  bool _isLoadingComments = false;
  List<dynamic> _commentList = [];
  String? _commentErrorMessage;

  // 当前选中的标签（简介/评论）
  String _currentTab = '简介';

  // 播放器高度
  final double _playerHeight = 220.0;

  // 控制器显示状态
  bool _showControls = true;
  Timer? _controlsTimer;

  // 主题色
  final Color _primaryColor = kPrimaryColor;
  final Color _backgroundColor = kBackgroundColor;
  final Color _cardColor = Color(0xFFFFFFFF);
  final Color _textColor = kTextColor;
  final Color _secondaryTextColor = kSecondaryTextColor;

  // 弹幕相关
  DanmakuController? _danmakuController;
  bool _danmakuEnabled = true;
  bool _isLoadingDanmaku = false;
  String? _danmakuErrorMessage;
  List<Map<String, dynamic>> _danmakuItems = [];
  int _currentVideoPosition = 0;
  Timer? _danmakuTimer;
  final GlobalKey _danmuKey = GlobalKey();
  bool _danmakuRunning = true;

  // 播放器错误重试计数
  int _playerInitRetryCount = 0;
  final int _maxPlayerRetries = 3;

  // 异步操作取消标记
  bool _isSwitchingEpisode = false;
  bool _isSwitchingPlayFrom = false;

  // 防止重复初始化
  String? _lastInitializedUrl;

  // 全屏状态监听
  bool _wasPortrait = true;
  Orientation _previousOrientation = Orientation.portrait;

  // 自定义进度条
  double _videoProgress = 0.0; // 视频进度比例 0.0-1.0
  Timer? _progressUpdateTimer;

  // 自定义控制器拖动进度
  bool _isDraggingProgress = false;
  double _dragProgressValue = 0.0;

  // 视频总时长缓存
  int _currentVideoDuration = 0;

  // 新增：资源释放锁，防止多次释放
  bool _isDisposingResources = false;

  // 新增：播放器初始化锁，防止并发初始化
  Completer<bool>? _playerInitializationCompleter;

  // 新增：播放速度
  double _playbackSpeed = 1.0;
  final List<double> _speedOptions = [1.0, 2.0, 3.0, 4.0];

  // 手势相关变量
  double? _horizontalDragStartPosition;
  int _seekStartPosition = 0;
  double? _verticalDragStartDy;
  bool _isVerticalDrag = false;
  bool _isLeftSide = false;
  double _brightness = 0.5;
  double _volume = 0.5;

  // 在 _VideoDetailPageState 类中添加：
  int _switchEpisodeToken = 0;
  bool _isLiked = false;
  int _zanCount = 0;

  // 新增：画面设置模式枚举
  AspectRatioMode _aspectRatioMode = AspectRatioMode.auto;

  // 控件锁定状态
  bool _isLocked = false;

  // 在_VideoDetailPageState中添加变量
  double _brightnessValue = 0.5;
  double _volumeValue = 0.5;
  bool _brightnessIndicator = false;
  bool _volumeIndicator = false;
  Timer? _brightnessTimer;
  Timer? _volumeTimer;
  String? _gestureType;
  Offset _initialFocalPoint = Offset.zero;
  bool _showBackwardButton = false;
  bool _showForwardButton = false;
  Timer? _backwardTimer;
  Timer? _forwardTimer;
  late final VolumeController _volumeController;
  StreamSubscription<double>? _volumeSubscription;

  // 横向拖动快进/快退相关变量
  double? _horizontalDragStartDx;
  int _seekOffsetSeconds = 0;
  bool _showSeekIndicator = false;

  // 新增：提前解析下集url
  String? _preResolvedNextUrl;
  int? _preResolvedNextIndex;

  // 长按2倍速相关
  bool _showSpeedTip = false;
  double _lastPlaybackSpeed = 1.0;
  AnimationController? _speedTipAnimController;
  Animation<double>? _speedTipAnim;

  // 自动切集标志,暂时没用1
  bool _hasAutoSwitched = false;


  bool _danmakuMassiveMode = true;
  double _danmakuOpacity = 1.0;
  double _danmakuFontSize = 19;
  final int _danmakuFontWeight = 7;
  bool _danmakuHideScroll = false;
  bool _danmakuHideTop = false;
  bool _danmakuHideBottom = false;
  bool _danmakuHideSpecial = false;
  bool _danmakuSafeArea = false;
  double _danmakuStrokeWidth = 0.8;
  double _danmakuDuration = 10.0;
  double _danmakuStaticDuration = 5.0;
  double _danmakuLineHeight = 1.5;
  // Timer? _danmakuTimer;
  int _danmakuSec = 0;

  // 投屏相关变量
  List<Device> _castDevices = [];
  bool _isLoadingDevices = false;
  String? _castError;

  late final PageController _pageController;
  double _tabIndicatorPosition = 0.0; // 0为简介，1为评论1

  double? _averageScore;
  bool _isLoadingScore = false;

  int? _initEpisodeIndex;
  String? _initPlayFrom;
  int? _initPositionSeconds;

  // 新增：首次播放标志
  bool _isFirstPlay = true;

  final Battery _battery = Battery();
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.full;
  String _currentTime = '';
  Timer? _batteryTimer;

  int? _watchingCount;
  Timer? _watchingTimer;

  double _danmakuDurationOrigin = 10.0; // 记录原始弹幕速度

  bool _isFavorited = false;

  OverlayEntry? _downloadOverlayEntry;
  Timer? _downloadOverlayTimer;

  // 1. state加字段
  Map<String, String> _downloadedEpisodes = {};

  void _clearDanmaku() {
    _danmakuController?.clear();
  }

  // 更新弹幕参数
  void _updateDanmakuOption({double? opacity, double? fontSize, double? duration, bool? showStroke, bool? massiveMode, bool? safeArea, double? strokeWidth, double? staticDuration, double? lineHeight}) {
    _danmakuController?.updateOption(
      _danmakuController!.option.copyWith(
        opacity: opacity ?? _danmakuOpacity,
        fontSize: fontSize ?? _danmakuFontSize,
        duration: duration ?? _danmakuDuration,
        staticDuration: staticDuration ?? _danmakuStaticDuration,
        strokeWidth: strokeWidth ?? _danmakuStrokeWidth,
        massiveMode: massiveMode ?? _danmakuMassiveMode,
        hideScroll: _danmakuHideScroll,
        hideTop: _danmakuHideTop,
        hideBottom: _danmakuHideBottom,
        safeArea: safeArea ?? _danmakuSafeArea,
        lineHeight: lineHeight ?? _danmakuLineHeight,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // 历史记录检测：如果未传递初始参数，则自动检测历史记录
    if (widget.initialEpisodeIndex == null && widget.initialPlayFrom == null && widget.initialPositionSeconds == null) {
      final list = UserStore().watchHistory
          .where((item) => item.videoId == widget.vodId.toString())
          .toList();
      final history = list.isNotEmpty ? list.first : null;
      if (history != null) {
        _initEpisodeIndex = history.episodeIndex;
        _initPlayFrom = history.playFrom;
        _initPositionSeconds = history.positionSeconds;
      } else {
        _initEpisodeIndex = null;
        _initPlayFrom = null;
        _initPositionSeconds = null;
      }
    } else {
      _initEpisodeIndex = widget.initialEpisodeIndex;
      _initPlayFrom = widget.initialPlayFrom;
      _initPositionSeconds = widget.initialPositionSeconds;
    }
    _pageController = PageController(initialPage: _currentTab == '简介' ? 0 : 1);
    _tabIndicatorPosition = _currentTab == '简介' ? 0.0 : 1.0;
    _pageController.addListener(() {
      setState(() {
        _tabIndicatorPosition = _pageController.page ?? 0.0;
      });
    });
    _fetchVideoDetail();
    _fetchAverageScore();

    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // 启用屏幕常亮1
    WakelockPlus.enable();

    // 设置状态栏为透明
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // 记录当前屏幕方向
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _previousOrientation = MediaQuery.of(context).orientation;
        _wasPortrait = _previousOrientation == Orientation.portrait;
      }
    });

    // 启动进度条更新定时器
    _startProgressUpdateTimer();
    _initBrightness();
    _initVolumeController();

    _speedTipAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    _speedTipAnim = CurvedAnimation(
      parent: _speedTipAnimController!,
      curve: Curves.easeInOut,
    );

    _initBatteryAndTime();
    _fetchWatchingCount();
    _watchingTimer = Timer.periodic(Duration(minutes: 4), (_) => _fetchWatchingCount());
    _checkDownloadedEpisodes();
  }

  void _checkDownloadedEpisodes() {
    final vodIdStr = widget.vodId.toString();
    final list = DownloadHelper.getDownloadedEpisodesByVodId(vodIdStr);
    _downloadedEpisodes = { for (var e in list) e['episode']!: e['localPath']! };
    print('本地已下载集数:  _downloadedEpisodes');
  }

  Future<void> _fetchLikeStatus() async {
    final vodId = int.tryParse(_videoDetail?['vod_id']?.toString() ?? '') ?? 0;
    if (vodId > 0) {
      final liked = await _apiManager.isVideoLiked(vodId);
      setState(() {
        _isLiked = liked;
      });
    }
  }

  Future<void> _toggleLike() async {
    final vodId = int.tryParse(_videoDetail?['vod_id']?.toString() ?? '') ?? 0;
    if (vodId == 0) return;
    final newLike = !_isLiked;
    final result = await _apiManager.likeVideo(vodId, newLike);
    setState(() {
      _isLiked = result['zan'] == true;
      _videoDetail?['vod_up'] = result['vod_up'].toString();
    });
  }

  Future<void> _fetchFavoriteStatus() async {
    final vodId = int.tryParse(_videoDetail?['vod_id']?.toString() ?? '') ?? 0;
    if (vodId > 0) {
      final favorited = await _apiManager.isVideoFavorited(vodId);
      setState(() {
        _isFavorited = favorited;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final vodId = int.tryParse(_videoDetail?['vod_id']?.toString() ?? '') ?? 0;
    if (vodId == 0) return;
    bool success = false;
    if (_isFavorited) {
      success = await _apiManager.removeVideoFavorite(vodId);
    } else {
      success = await _apiManager.addVideoFavorite(vodId);
    }
    if (success) {
      setState(() {
        _isFavorited = !_isFavorited;
      });
    }
  }

  void _initBatteryAndTime() {
    _updateBatteryAndTime();
    _batteryTimer = Timer.periodic(Duration(seconds: 20), (_) => _updateBatteryAndTime());
  }

  Future<void> _updateBatteryAndTime() async {
    final level = await _battery.batteryLevel;
    final state = await _battery.batteryState;
    final now = DateTime.now();
    setState(() {
      _batteryLevel = level;
      _batteryState = state;
      _currentTime = _formatTime(now);
    });
  }

  String _formatTime(DateTime dt) {
    String hour = dt.hour.toString().padLeft(2, '0');
    String minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _initVolumeController() {
    _volumeController = VolumeController.instance;
    _volumeSubscription = _volumeController.addListener((volume) {
      setState(() {
        _volumeValue = volume;
      });
    }, fetchInitialVolume: true);
  }

  Future<void> _initBrightness() async {
    try {
      _brightnessValue = await ScreenBrightness().current;
    } catch (e) {
      print('获取亮度失败: $e');
    }
  }

  Future<void> _initVolume() async {
    try {
      _volumeValue = await _volumeController.getVolume();
    } catch (e) {
      print('获取音量失败: $e');
    }
  }

  Future<void> _setBrightness(double value) async {
    value = value.clamp(0.0, 1.0);
    try {
      await ScreenBrightness().setScreenBrightness(value);
      setState(() {
        _brightnessValue = value;
        _brightnessIndicator = true;
      });
      _brightnessTimer?.cancel();
      _brightnessTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _brightnessIndicator = false;
          });
        }
      });
    } catch (e) {
      print('设置亮度失败: $e');
    }
  }

  Future<void> _setVolume(double value) async {
    value = value.clamp(0.0, 1.0);
    try {
      await _volumeController.setVolume(value);
      setState(() {
        _volumeValue = value;
        _volumeIndicator = true;
      });
      _volumeTimer?.cancel();
      _volumeTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _volumeIndicator = false;
          });
        }
      });
    } catch (e) {
      print('设置音量失败: $e');
    }
  }

  void _onDoubleTapSeekBackward() {
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      final pos = _videoPlayerController!.value.position;
      final newPos = pos - Duration(seconds: 10);
      _videoPlayerController!.seekTo(newPos > Duration.zero ? newPos : Duration.zero);
    }
    setState(() {
      _showBackwardButton = true;
    });
    _backwardTimer?.cancel();
    _backwardTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showBackwardButton = false;
        });
      }
    });
  }

  void _onDoubleTapSeekForward() {
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      final pos = _videoPlayerController!.value.position;
      final dur = _videoPlayerController!.value.duration;
      final newPos = pos + Duration(seconds: 10);
      _videoPlayerController!.seekTo(newPos < dur ? newPos : dur);
    }
    setState(() {
      _showForwardButton = true;
    });
    _forwardTimer?.cancel();
    _forwardTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showForwardButton = false;
        });
      }
    });
  }

  void _onDoubleTapCenter() {
    _togglePlay();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.globalPosition.dx;
    if (tapPosition < screenWidth / 3) {
      _onDoubleTapSeekBackward();
    } else if (tapPosition > screenWidth * 2 / 3) {
      _onDoubleTapSeekForward();
    } else {
      _onDoubleTapCenter();
    }
  }

  /// 启动进度条更新定时器
  void _startProgressUpdateTimer() {
    print('进入_startProgressUpdateTimer');
    _progressUpdateTimer?.cancel();
    _progressUpdateTimer = Timer.periodic(Duration(milliseconds: 200), (timer) {
      if (!mounted ||
          _videoPlayerController == null ||
          !_videoPlayerController!.value.isInitialized) {
        return;
      }

      if (_isDraggingProgress) return;

      _updateVideoProgress();
    });
  }
  void _updateVideoProgress() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;

    final position = _videoPlayerController!.value.position;
    final Duration duration = _videoPlayerController!.value.duration;

    // 检查视频是否真正加载完成（通过检查总时长是否大于0）
    bool isVideoLoaded = duration.inMilliseconds > 0;

    // 检查视频是否真正开始播放（确保视频已加载且开始播放）
    if (!_videoStarted &&
        isVideoLoaded &&
        position.inMilliseconds > 0 &&
        _videoPlayerController!.value.isPlaying) {
      print('视频开始播放，设置 _videoStarted = true');
      _videoStarted = true;

      // 清空之前可能已经发送的弹幕状态
      _danmakuItems.forEach((item) => item['sent'] = false);

      // 清空弹幕屏幕
      if (_danmakuController != null) {
        print('清空弹幕屏幕');
        _danmakuController!.clear();
      }

      // 确保弹幕控制器处于运行状态
      if (_danmakuController != null) {
        print('恢复弹幕控制器运行');
        _danmakuController!.resume();
        _danmakuRunning = true;
      }
    }

    if (isVideoLoaded) {
      final double progress = position.inMilliseconds / duration.inMilliseconds;
      if (mounted && progress != _videoProgress) {
        setState(() {
          _videoProgress = progress.clamp(0.0, 1.0);
          _currentVideoPosition = position.inMilliseconds;
          _currentVideoDuration = duration.inMilliseconds;
        });
      }

      // ====== 新增：5/8时提前解析下一集 ======
      if (_playUrlsList.isNotEmpty && _currentPlayFromIndex < _playUrlsList.length) {
        final nextIndex = _currentEpisodeIndex + 1;
        if (nextIndex < _playUrlsList[_currentPlayFromIndex].length) {
          final nextRawUrl = _playUrlsList[_currentPlayFromIndex][nextIndex]['url'] ?? '';
          // 只在5/8时且未提前解析过才触发
          if (_preResolvedNextIndex != nextIndex && progress >= 5 / 8 && nextRawUrl.isNotEmpty) {
            _preResolvedNextIndex = nextIndex;
            _preResolvedNextUrl = null;
            _resolvePlayUrl(nextRawUrl, _playFromList[_currentPlayFromIndex]).then((result) {
              if (mounted && _preResolvedNextIndex == nextIndex) {
                _preResolvedNextUrl = result['url'] as String?;
              }
            }).catchError((e) {
              // 解析失败不影响主流程
              print('提前解析下一集失败: $e');
            });
          }
        }
      }
      // ====== END ======

      // 同步弹幕控制器状态
      _syncDanmakuControllerState();

      // 处理弹幕显示
      _handleDanmakuDisplay(position);
    }
  }
  /// 彻底释放所有播放器资源
  Future<void> _disposeAllPlayers() async {
    // 防止重复释放
    if (_isDisposingResources) return;
    _isDisposingResources = true;

    print('释放所有播放器资源');

    try {
      // 停止所有定时器
      _progressUpdateTimer?.cancel();
      _danmakuTimer?.cancel();
      _controlsTimer?.cancel();

      // 移除监听器 - 必须在dispose之前
      _videoPlayerController?.removeListener(_onVideoPositionChanged);
      _chewieController?.removeListener(_onChewieControllerUpdate);

      // 暂停播放
      if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        try {
          await _videoPlayerController!.pause();
        } catch (e) {
          print('暂停播放失败: $e');
        }
      }

      // 释放 Chewie
      if (_chewieController != null) {
        try {
          _chewieController!.dispose();
        } catch (e) {
          print('释放 ChewieController 失败: $e');
        } finally {
          _chewieController = null;
        }
      }

      // 释放 VideoPlayer
      if (_videoPlayerController != null) {
        try {
          await _videoPlayerController!.dispose();
        } catch (e) {
          print('释放 VideoPlayerController 失败: $e');
        } finally {
          _videoPlayerController = null;
        }
      }

      // 强制垃圾回收
      await Future.delayed(Duration(milliseconds: 300));
    } catch (e) {
      print('释放播放器资源时发生异常: $e');
    } finally {
      _isDisposingResources = false;
    }
  }

  @override
  void dispose() {
    print("VideoDetailPage dispose called");
    // 取消所有定时器
    _controlsTimer?.cancel();
    _danmakuTimer?.cancel();
    _progressUpdateTimer?.cancel();

    // 新增：保存观看历史
    _saveWatchHistory();

    // 释放播放器资源
    _disposeAllPlayers();

    // 释放其他资源
    _animationController.dispose();
    _episodeScrollController.dispose();
    _mainScrollController.dispose();

    // 禁用屏幕常亮
    WakelockPlus.disable();

    // 恢复系统UI设置
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    // 确保退出全屏并恢复竖屏
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    // 移除错误的 disable 调用
    // _floating.disable().catchError((e) => print('退出PiP失败: $e'));

    _volumeSubscription?.cancel();
    _speedTipAnimController?.dispose();
    _pageController.dispose();
    _batteryTimer?.cancel();
    _watchingTimer?.cancel();
    super.dispose();
  }

  // 新增：保存观看历史方法
  void _saveWatchHistory() {
    try {
      if (_videoDetail != null && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        final String videoId = (_videoDetail?['vod_id'] ?? '').toString();
        final int episodeIndex = _currentEpisodeIndex;
        final int positionSeconds = _videoPlayerController!.value.position.inSeconds;
        final String playFrom = (_playFromList.isNotEmpty && _currentPlayFromIndex < _playFromList.length)
            ? _playFromList[_currentPlayFromIndex]
            : '';
        final String videoTitle = (_videoDetail?['vod_name'] ?? '').toString();
        final String videoCover = (_videoDetail?['vod_pic'] ?? '').toString();
        final item = WatchHistoryItem(
          videoId: videoId,
          episodeIndex: episodeIndex,
          positionSeconds: positionSeconds,
          playFrom: playFrom,
          timestamp: DateTime.now(),
          videoTitle: videoTitle,
          videoCover: videoCover,
        );
        UserStore().addWatchHistory(item);
        // 新增：自动上传到云端
        if (UserStore().user != null && (UserStore().user?.token?.isNotEmpty ?? false)) {
          UserStore().addCloudHistoryRecord(
            vodId: int.tryParse(videoId) ?? 0,
            episodeIndex: episodeIndex,
            playSource: playFrom,
            playUrl: videoCover, // 如有真实播放地址可传
            playProgress: positionSeconds,
          );
        }
      }
    } catch (e) {
      print('保存观看历史失败: $e');
    }
  }

  /// 获取视频详情
  Future<void> _fetchVideoDetail() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 获取视频详情数据
      final dynamic result = await _apiManager.getVideoDetail(widget.vodId);

      if (!mounted) return;

      if (result is Map<String, dynamic>) {
        setState(() {
          _videoDetail = result;
          _isLoading = false;
        });
        // 优先并发请求点赞和收藏状态，保证按钮尽早显示
        _fetchLikeStatus();
        _fetchFavoriteStatus();
        // 新增：详情获取后主动请求一次正在观看人数
        _fetchWatchingCount();

        // 解析播放源和播放地址
        _parsePlaySources();

        // 解析player_list
        _parsePlayerList();

        // 支持初始集数/播放源/进度跳转
        int playFromIndex = 0;
        int episodeIndex = 0;
        if (_initPlayFrom != null && _playFromList.isNotEmpty) {
          final idx = _playFromList.indexOf(_initPlayFrom!);
          if (idx != -1) playFromIndex = idx;
        }
        if (_initEpisodeIndex != null) {
          episodeIndex = _initEpisodeIndex!;
        }
        if (_playFromList.isNotEmpty && _playUrlsList.isNotEmpty && _playUrlsList[playFromIndex].isNotEmpty) {
          final String rawUrl = _playUrlsList[playFromIndex][episodeIndex]['url'] ?? '';
          if (rawUrl.isNotEmpty) {
            try {
              final result = await _resolvePlayUrl(rawUrl, _playFromList[playFromIndex]);
              final realUrl = result['url'] as String;
              final headers = (result['headers'] as Map<String, String>?) ?? {};
              await _initializePlayer(realUrl, rawUrl: rawUrl, episodeIndex: episodeIndex, playFromIndex: playFromIndex, headers: headers);
            } catch (e) {
              print('初始化播放器失败: $e');
              await _initializePlayer(rawUrl, rawUrl: rawUrl, episodeIndex: episodeIndex, playFromIndex: playFromIndex);
            }
            setState(() {
              _currentPlayFromIndex = playFromIndex;
              _currentEpisodeIndex = episodeIndex;
            });
            // seek到指定进度
            if (_initPositionSeconds != null && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
              _videoPlayerController!.seekTo(Duration(seconds: _initPositionSeconds!));
            } else {
              // 如果播放器还没初始化，延迟seek
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (_initPositionSeconds != null && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
                  _videoPlayerController!.seekTo(Duration(seconds: _initPositionSeconds!));
                }
              });
            }
          }
        }

        // 获取评论
        _fetchComments();
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = '获取视频详情失败: 数据格式错误';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('获取视频详情失败: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '获取视频详情失败: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  /// 解析播放源和播放地址
  void _parsePlaySources() {
    if (_videoDetail == null || !mounted) return;

    // 解析播放源
    final String playFrom = _videoDetail!['vod_play_from'] ?? '';
    if (playFrom.isNotEmpty) {
      _playFromList = playFrom.split('\$\$\$');
    }

    // 解析播放地址
    final String playUrl = _videoDetail!['vod_play_url'] ?? '';
    if (playUrl.isNotEmpty) {
      // 分割不同播放源的地址
      final List<String> playUrlsBySource = playUrl.split('\$\$\$');

      _playUrlsList = [];
      _maxEpisodes = 0; // Reset max episodes

      // 处理每个播放源的地址
      for (var i = 0; i < playUrlsBySource.length; i++) {
        final String sourceUrl = playUrlsBySource[i];
        final List<Map<String, String>> episodes = [];

        // 分割每一集
        final List<String> episodeItems = sourceUrl.split('#');

        for (var episodeItem in episodeItems) {
          // 分割集数名称和URL
          final List<String> parts = episodeItem.split('\$');
          if (parts.length == 2) {
            episodes.add({
              'name': parts[0],
              'url': parts[1].replaceAll(r'\/', '/'),
            });
          }
        }
        _playUrlsList.add(episodes);
        // Update max episodes count
        if (episodes.length > _maxEpisodes) {
          _maxEpisodes = episodes.length;
        }
      }
    }

    print('播放源: $_playFromList');
    print('播放地址列表: $_playUrlsList');
    print('最大集数: $_maxEpisodes');
  }

  /// 解析player_list
  void _parsePlayerList() {
    final playerList = _videoDetail?['player_list'];
    if (playerList is List) {
      for (var item in playerList) {
        if (item is Map<String, dynamic> && item['player'] != null) {
          _playerMap[item['player']] = item;
        }
      }
    }
  }

  /// 根据player_list自动处理url
  Future<Map<String, dynamic>> _resolvePlayUrl(String rawUrl, String playFrom) async {
    try {
      final playerInfo = _playerMap[playFrom];
      String referer = playerInfo?['referer'] ?? '';
      Map<String, String> headers = {};
      if (referer.isNotEmpty) {
        headers['Referer'] = referer;
      }

      // 判断是否为直链
      bool isDirectLink(String url) {
        final lower = url.toLowerCase();
        return lower.endsWith('.mp4') ||
            lower.endsWith('.m3u8') ||
            lower.endsWith('.flv') ||
            lower.endsWith('.mov') ||
            lower.endsWith('.mkv') ||
            lower.endsWith('.avi') ||
            lower.endsWith('.wmv') ||
            url.contains('cdn') ||
            url.contains('stream') ||
            url.contains('video') ||
            url.contains('media') ||
            url.contains('pitaya') ||
            url.contains('alisg') ||
            url.contains('tos-') ||
            url.contains('obj/');
      }

      String realUrl = rawUrl;
      if (playerInfo != null && playerInfo['type'] == 'json' && !isDirectLink(rawUrl)) {
        final apiUrl = playerInfo['url'] + Uri.encodeComponent(rawUrl);
        print('解析URL: $apiUrl');

        final resp = await http.get(Uri.parse(apiUrl));
        if (resp.statusCode == 200) {
          try {
            final data = json.decode(resp.body);
            if (data is Map && data['url'] != null && data['url'].toString().isNotEmpty) {
              realUrl = data['url'];
              print('解析成功，真实URL: $realUrl');
            } else {
              print('JSON解析失败: 返回数据不包含url字段');
              throw Exception('json解析视频地址失败: 返回数据不包含url字段');
            }
          } catch (e) {
            print('JSON解析异常: $e');
            print('响应内容: ${resp.body}');
            throw Exception('json解析视频地址失败: $e');
          }
        } else {
          print('HTTP请求失败: ${resp.statusCode}');
          throw Exception('json解析视频地址失败: HTTP ${resp.statusCode}');
        }
      }

      return {
        'url': realUrl,
        'headers': headers,
      };
    } catch (e) {
      print('解析播放URL失败: $e');
      rethrow; // 重新抛出异常，让调用者处理
    }
  }

  /// 检查URL是否为HTML页面 - 放宽检查条件，支持无扩展名视频URL
  bool _isHtmlPage(String url) {
    // 明确的HTML页面标记
    if (url.contains('.html') || url.contains('/play/')) {
      return true;
    }

    // 明确的视频扩展名，直接返回false
    if (url.toLowerCase().endsWith('.mp4') ||
        url.toLowerCase().endsWith('.m3u8') ||
        url.toLowerCase().endsWith('.flv') ||
        url.toLowerCase().endsWith('.mov') ||
        url.toLowerCase().endsWith('.mkv') ||
        url.toLowerCase().endsWith('.avi') ||
        url.toLowerCase().endsWith('.wmv')) {
      return false;
    }

    // 对于没有扩展名的URL，不再直接判定为HTML页面
    // 而是通过其他特征判断

    // 常见的视频CDN或流媒体特征
    if (url.contains('cdn') ||
        url.contains('stream') ||
        url.contains('video') ||
        url.contains('media') ||
        url.contains('pitaya') ||
        url.contains('alisg') ||
        url.contains('tos-') ||
        url.contains('obj/')) {
      return false;
    }

    // 默认认为不是HTML页面，交给播放器尝试播放
    return false;
  }

  /// 初始化播放器
  Future<void> _initializePlayer(String url, {String? rawUrl, int? episodeIndex, int? playFromIndex, int? customSeekSeconds, Map<String, String>? headers}) async {
    // 防止重复初始化同一个URL
    if (_isPlayerInitializing || url == _lastInitializedUrl) {
      print('播放器正在初始化或URL未改变，跳过');
      return;
    }

    // 如果当前有正在进行的初始化，等待它完成
    if (_playerInitializationCompleter != null && !_playerInitializationCompleter!.isCompleted) {
      print('等待上一个播放器初始化完成...');
      await _playerInitializationCompleter!.future;
    }

    // 创建新的Completer
    _playerInitializationCompleter = Completer<bool>();

    if (!mounted) {
      _playerInitializationCompleter!.complete(false);
      return;
    }

    setState(() {
      _isPlayerInitializing = true;
      _isLoading = true;
      _errorMessage = null;
      _videoCompleted = false;
      _currentPlayUrl = url;
      _lastInitializedUrl = url;
      _playerInitRetryCount = 0;
    });

    // 释放旧的播放器资源
    await _disposeAllPlayers();

    print('开始初始化播放器: $url');

    try {
      // 检查是否为HTML页面
      if (_isHtmlPage(url)) {
        throw Exception('URL是HTML页面，无法直接播放');
      }

      // 确保 headers 里有 User-Agent
      headers = headers ?? {};
      if (!headers.containsKey('User-Agent')) {
        headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:138.0) Gecko/20100101 Firefox/138.0';
      }
      print('初始化播放器url: ' + url);
      print('初始化播放器headers: ' + (headers?.toString() ?? '{}'));
      // 初始化VideoPlayerController
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        httpHeaders: headers,
      );

      // 添加监听器
      _videoPlayerController!.addListener(_onVideoPositionChanged);

      // 初始化VideoPlayerController
      await _videoPlayerController!.initialize();
      print('播放器初始化成功');
      _startProgressUpdateTimer();

      if (!mounted) {
        _playerInitializationCompleter!.complete(false);
        return;
      }

      // 初始化ChewieController
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false, // 先不自动播放
        looping: false,
        showControls: false, // 使用自定义控件
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      );

      // 添加Chewie监听器
      _chewieController!.addListener(_onChewieControllerUpdate);

      setState(() {
        _isPlayerInitializing = false;
        _isLoading = false;
        _isPlaying = true;
        _videoProgress = 0.0;
        _videoStarted = false;
        _danmakuRunning = false;
        _currentVideoDuration = _videoPlayerController!.value.duration.inMilliseconds;
      });

      // 重置弹幕状态
      if (_danmakuController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _danmakuController != null) {
            _danmakuController!.pause();
            _danmakuController!.clear();
          }
        });
      }
      _danmakuItems = [];

      // 获取弹幕数据
      _fetchDanmaku(rawUrl ?? url); // 弹幕异步加载，不阻塞视频播放

      // ========== 优化历史记录跳转体验 ==========
      int? targetSeconds;
      // 只在首次播放时用入口参数或历史
      if (_isFirstPlay) {
        if (_initPositionSeconds != null) {
          targetSeconds = _initPositionSeconds;
        } else {
          // 查本地历史（当前视频、当前集）
          final list = UserStore().watchHistory.where((item) =>
            item.videoId == (widget.vodId.toString()) &&
            (episodeIndex != null ? item.episodeIndex == episodeIndex : true)
          ).toList();
          if (list.isNotEmpty) {
            targetSeconds = list.first.positionSeconds;
          } else {
            targetSeconds = 0;
          }
        }
        _isFirstPlay = false;
      } else if (customSeekSeconds != null) {
        targetSeconds = customSeekSeconds;
      } else if (episodeIndex != null) {
        // 切集时查找该集的历史
        final list = UserStore().watchHistory.where((item) =>
          item.videoId == (widget.vodId.toString()) && item.episodeIndex == episodeIndex
        ).toList();
        if (list.isNotEmpty) {
          targetSeconds = list.first.positionSeconds;
        } else {
          targetSeconds = 0;
        }
      } else {
        targetSeconds = 0;
      }
      if (targetSeconds != null && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        await _videoPlayerController!.seekTo(Duration(seconds: targetSeconds));
      }
      await _videoPlayerController?.play();
      // ========== END ==========

      // 标记初始化成功
      _playerInitializationCompleter!.complete(true);

    } catch (e) {
      print('播放器初始化失败: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '播放器初始化失败: ${e.toString()}';
          _isPlayerInitializing = false;
          _isLoading = false;
        });
      }
      // 标记初始化失败
      _playerInitializationCompleter!.complete(false);
    }
  }

  /// 视频位置变化监听
  void _onVideoPositionChanged() {
    if (!mounted || _videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return;
    }

    final bool isPlaying = _videoPlayerController!.value.isPlaying;
    final bool isVideoLoaded = _videoPlayerController!.value.duration.inMilliseconds > 0;

    // 检测播放状态变化
    if (isPlaying != _isPlaying) {
      print('视频播放状态变化: [32m${isPlaying ? "播放" : "暂停"}[0m');
      setState(() {
        _isPlaying = isPlaying;
      });

      // 如果暂停播放，重置弹幕发送状态，已完成
      if (!isPlaying) {
        print('视频暂停，暂停弹幕发送');
        _danmakuController?.pause();
        _danmakuRunning = false;
      } else if (isVideoLoaded) {
        print('视频播放，恢复弹幕发送');
        _danmakuController?.resume();
        _danmakuRunning = true;
      }
    }

    // ===== 自动切换下一集（无感切换） =====
    final position = _videoPlayerController!.value.position;
    final duration = _videoPlayerController!.value.duration;
    if (_autoPlayNextEpisode &&
        !_isSwitchingEpisode &&
        duration.inMilliseconds > 0 &&
        (position.inMilliseconds >= duration.inMilliseconds - 500) && // 容差0.5秒
        _currentPlayFromIndex < _playUrlsList.length &&
        _currentEpisodeIndex + 1 < _playUrlsList[_currentPlayFromIndex].length) {
      _switchEpisode(_currentEpisodeIndex + 1);
    }
    // ===== END =====
  }

  /// Chewie控制器更新监听
  void _onChewieControllerUpdate() {
    if (!mounted || _chewieController == null) return;

    // 处理全屏状态变化
    if (_chewieController!.isFullScreen != _isFullScreen) {
      setState(() {
        _isFullScreen = _chewieController!.isFullScreen;
      });
    }
  }

  /// 切换播放源
  Future<void> _switchPlayFrom(int index) async {
    if (_isSwitchingPlayFrom || index == _currentPlayFromIndex || index >= _playFromList.length) {
      return;
    }

    setState(() {
      _isSwitchingPlayFrom = true;
      _currentPlayFromIndex = index;
      _currentEpisodeIndex = 0; // 切换播放源后默认从第一集开始
      _isLoading = true;
      _errorMessage = null;
    });

    // 清空弹幕
    _danmakuController?.clear();
    _danmakuItems = [];

    try {
      if (_playUrlsList.length > index && _playUrlsList[index].isNotEmpty) {
        final String url = _playUrlsList[index][0]['url'] ?? '';
        if (url.isNotEmpty) {
          try {
            // 尝试解析URL
            final result = await _resolvePlayUrl(url, _playFromList[index]);
            final realUrl = result['url'] as String;
            final headers = (result['headers'] as Map<String, String>?) ?? {};
            await _initializePlayer(realUrl, headers: headers);
          } catch (e) {
            print('初始化播放器失败: $e');
            // 直接使用原始URL初始化
            await _initializePlayer(url);
          }
        }
      }
    } catch (e) {
      print('切换播放源失败: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '切换播放源失败: ${e.toString()}';
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingPlayFrom = false;
        });
      }
    }
  }

  /// 切换集数
  Future<void> _switchEpisode(int index) async {
    if (_isSwitchingEpisode ||
        _currentPlayFromIndex >= _playUrlsList.length ||
        index >= _playUrlsList[_currentPlayFromIndex].length ||
        index == _currentEpisodeIndex) {
      return;
    }
    final int token = ++_switchEpisodeToken;
    _isSwitchingEpisode = true;
    _danmakuController?.clear();
    _danmakuItems = [];
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final String rawUrl = _playUrlsList[_currentPlayFromIndex][index]['url'] ?? '';
      final String episodeName = _playUrlsList[_currentPlayFromIndex][index]['name'] ?? '';
      // 优先本地
      String? localPath = _downloadedEpisodes[episodeName];
      if (localPath != null && localPath.isNotEmpty) {
        print('使用本地已下载: ' + localPath);
        await _initializePlayer(localPath, rawUrl: localPath, episodeIndex: index, playFromIndex: _currentPlayFromIndex);
        setState(() {
          _currentEpisodeIndex = index;
          _isLoading = false;
        });
        return;
      }
      // ...原有网络逻辑...
      if (_preResolvedNextIndex == index && _preResolvedNextUrl != null && _preResolvedNextUrl!.isNotEmpty) {
        int? seekSeconds;
        final list = UserStore().watchHistory.where((item) =>
          item.videoId == (widget.vodId.toString()) && item.episodeIndex == index
        ).toList();
        if (list.isNotEmpty) {
          seekSeconds = list.first.positionSeconds;
        }
        await _initializePlayer(_preResolvedNextUrl!, rawUrl: rawUrl, episodeIndex: index, playFromIndex: _currentPlayFromIndex, customSeekSeconds: seekSeconds);
      } else if (rawUrl.isNotEmpty) {
        try {
          if (token != _switchEpisodeToken || !mounted) return;
          final result = await _resolvePlayUrl(rawUrl, _playFromList[_currentPlayFromIndex]);
          final realUrl = result['url'] as String;
          final headers = (result['headers'] as Map<String, String>?) ?? {};
          if (token != _switchEpisodeToken || !mounted) return;
          int? seekSeconds;
          final list = UserStore().watchHistory.where((item) =>
            item.videoId == (widget.vodId.toString()) && item.episodeIndex == index
          ).toList();
          if (list.isNotEmpty) {
            seekSeconds = list.first.positionSeconds;
          }
          await _initializePlayer(realUrl, rawUrl: rawUrl, episodeIndex: index, playFromIndex: _currentPlayFromIndex, customSeekSeconds: seekSeconds, headers: headers);
        } catch (e) {
          print('初始化播放器失败: $e');
          if (token != _switchEpisodeToken || !mounted) return;
          int? seekSeconds;
          final list = UserStore().watchHistory.where((item) =>
            item.videoId == (widget.vodId.toString()) && item.episodeIndex == index
          ).toList();
          if (list.isNotEmpty) {
            seekSeconds = list.first.positionSeconds;
          }
          await _initializePlayer(rawUrl, rawUrl: rawUrl, episodeIndex: index, playFromIndex: _currentPlayFromIndex, customSeekSeconds: seekSeconds);
        }
      }
      if (_preResolvedNextIndex == index) {
        _preResolvedNextUrl = null;
        _preResolvedNextIndex = null;
      }
      if (mounted && token == _switchEpisodeToken) {
        setState(() {
          _currentEpisodeIndex = index;
          _isLoading = false;
        });
        _saveWatchHistory();
      }
    } catch (e) {
      print('切换集数失败: $e');
      if (mounted && token == _switchEpisodeToken) {
        setState(() {
          _isLoading = false;
          _errorMessage = '切换集数失败: ${e.toString()}';
        });
      }
    } finally {
      if (token == _switchEpisodeToken) {
        _isSwitchingEpisode = false;
      }
    }
  }

  /// 同步弹幕位置
  void _syncDanmakuPosition(int position) {
    // 实现弹幕位置同步逻辑
  }

  /// 获取评论
  Future<void> _fetchComments() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoadingComments = true;
        _commentErrorMessage = null;
      });

      // 调用API获取评论
      final dynamic result = await _apiManager.getVideoComments(widget.vodId);

      if (!mounted) return;

      if (result is Map<String, dynamic> && result.containsKey('list') && result['list'] is List) {
        setState(() {
          _commentList = result['list'] as List<dynamic>;
          _isLoadingComments = false;
        });
      } else {
        setState(() {
          _commentErrorMessage = '获取评论失败: 数据格式错误';
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      print('获取评论列表异常: $e');
      if (mounted) {
        setState(() {
          _commentErrorMessage = '获取评论失败: ${e.toString()}';
          _isLoadingComments = false;
        });
      }
    }
  }

  /// 带重试的获取评论
  Future<void> _fetchCommentsWithRetry({int retryCount = 0}) async {
    if (retryCount >= 3 || !mounted) {
      if (mounted) {
        setState(() {
          _commentList = [];
          _isLoadingComments = false;
          _commentErrorMessage = '获取评论失败，请稍后再试';
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoadingComments = true;
          _commentErrorMessage = null;
        });
      }

      // 调用API获取评论
      final dynamic result = await _apiManager.getVideoComments(widget.vodId);

      if (!mounted) return;

      if (result is Map<String, dynamic> && result.containsKey('list') && result['list'] is List) {
        if (mounted) {
          setState(() {
            _commentList = result['list'] as List<dynamic>;
            _isLoadingComments = false;
          });
        }
      } else {
        // 如果返回数据格式不正确，等待后重试
        await Future.delayed(Duration(seconds: 1 * (retryCount + 1)));
        if (mounted) {
          _fetchCommentsWithRetry(retryCount: retryCount + 1);
        }
      }
    } catch (e) {
      print('获取评论失败: $e');
      // 出错后等待后重试
      await Future.delayed(Duration(seconds: 1 * (retryCount + 1)));
      if (mounted) {
        _fetchCommentsWithRetry(retryCount: retryCount + 1);
      }
    }
  }

  /// 获取弹幕数据
  Future<void> _fetchDanmaku(String videoUrl) async {
    print('准备请求弹幕: $videoUrl');
    if (!_danmakuEnabled || !mounted) {
      print('弹幕未启用或组件已卸载');
      return;
    }
    setState(() {
      _isLoadingDanmaku = true;
      _danmakuErrorMessage = null;
    });

    try {
      final apiUrl = 'http://8.130.176.84:4269/abidb2/?&&douban_id=0&url=' + Uri.encodeComponent(videoUrl);
      print('请求弹幕API: $apiUrl');
      final dio = Dio();
      final resp = await dio.get(apiUrl, options: Options(responseType: ResponseType.plain)).timeout(Duration(seconds: 8));
      print('弹幕API响应状态码: ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final data = json.decode(resp.data);
        if (data is Map && data['danmuku'] is List) {
          print('收到弹幕数据条数: ${data['danmuku'].length}');

          List<Map<String, dynamic>> parsedItems = [];
          for (var item in data['danmuku']) {
            if (item is List && item.length >= 5) {
              final double time = (item[0] is num) ? item[0].toDouble() : double.tryParse(item[0].toString()) ?? 0.0;
              final String typeStr = item[1]?.toString() ?? 'right';
              final DanmakuItemType type = typeStr == 'bottom'
                  ? DanmakuItemType.bottom
                  : typeStr == 'top'
                  ? DanmakuItemType.top
                  : DanmakuItemType.scroll;
              final String colorStr = item[2] ?? '#ffffff'; // 默认使用白色
              final Color color = _convertDanmakuColor(colorStr);
              final String text = item[4]?.toString() ?? '';

              parsedItems.add({
                'time': time,
                'type': type,
                'color': colorStr,
                'parsedColor': color,
                'text': text,
                'sent': false,
              });
            }
          }

          if (mounted) {
            setState(() {
              _isLoadingDanmaku = false;
              _danmakuItems = parsedItems;
              print('弹幕数据已保存，共 ${_danmakuItems.length} 条');

              // 打印前5条弹幕数据作为示例
              for (var i = 0; i < math.min(5, _danmakuItems.length); i++) {
                final item = _danmakuItems[i];
                print('弹幕示例 $i: {time: ${item['time']}, type: ${item['type']}, color: ${item['color']}, text: ${item['text']}}');
              }
            });
          }
        } else {
          throw Exception('弹幕数据格式错误');
        }
      } else {
        throw Exception('弹幕接口请求失败: ${resp.statusCode}');
      }
    } catch (e) {
      print('获取弹幕失败: $e');
      if (mounted) {
        setState(() {
          _danmakuErrorMessage = '获取弹幕失败: ${e.toString()}';
          _isLoadingDanmaku = false;
        });
      }
    }
  }

  // 添加弹幕到控制器
  void _addDanmaku(String text, Color color, {DanmakuItemType type = DanmakuItemType.scroll}) {
    if (_danmakuController == null || !mounted) return;
    
    try {
      _danmakuController!.addDanmaku(
        DanmakuContentItem(
          text,
          color: color,
          type: type,
        ),
      );
    } catch (e) {
      print('添加弹幕失败: $e');
    }
  }

  // 在视频播放位置变化时处理弹幕显示1
  void _handleDanmakuDisplay(Duration position) {
    if (!_danmakuEnabled ||
        _danmakuItems.isEmpty ||
        _danmakuController == null ||
        !_videoPlayerController!.value.isPlaying) {
      return;
    }

    final double currentTime = position.inMilliseconds / 1000.0;

    for (var item in _danmakuItems) {
      if (!(item['sent'] ?? false)) {
        final double itemTime = item['time'] as double;
        // 使用较小的容差范围，确保弹幕显示更精确
        final double tolerance = 0.3;

        if (itemTime <= currentTime + tolerance && itemTime >= currentTime - tolerance) {
          _addDanmaku(
            item['text'],
            item['parsedColor'] ?? Colors.white,
            type: item['type'] ?? DanmakuItemType.scroll,
          );
          item['sent'] = true;
        }
      }
    }
  }

  // 解析弹幕颜色
  Color _convertDanmakuColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        String hexColor = colorStr.substring(1);
        if (hexColor.length == 6) {
          return Color(int.parse('0xFF$hexColor'));
        }
      }
    } catch (e) {
      print('解析颜色失败: $colorStr, $e');
    }
    return Colors.white; // 默认白色
  }

  // 在视频播放状态变化时同步弹幕控制器状态
  void _syncDanmakuControllerState() {
    if (_danmakuController == null) {
      print('弹幕控制器未初始化');
      return;
    }

    if (_videoPlayerController != null && _videoPlayerController!.value.isPlaying) {
      if (!_danmakuRunning) {
        print('视频播放中，恢复弹幕控制器');
        _danmakuController!.resume();
        _danmakuRunning = true;
      }
    } else {
      if (_danmakuRunning) {
        print('视频已暂停，暂停弹幕控制器');
        _danmakuController!.pause();
        _danmakuRunning = false;
      }
    }
  }

  /// 显示控制层（临时）
  void _showControlsTemporarily() {
    if (!mounted) return;

    _controlsTimer?.cancel();
    _controlsTimer = Timer(Duration(seconds: 3), () {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  /// 横屏专用：右侧弹出选集弹窗
  void _showLandscapeEpisodePopup() {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: "关闭",
      transitionDuration: Duration(milliseconds: 250),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(1, 0),
            end: Offset(0, 0),
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (context, anim1, anim2) {
        final double popupWidth = MediaQuery.of(context).size.width * 0.45;
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: popupWidth,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.7),
                  child: Column(
                    children: [
                      // 标题（无关闭按钮）
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 8, top: 18, bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '视频选集',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // 播放源横向滚动，固定顶部1
                      Container(
                        height: 45,
                        padding: EdgeInsets.only(left: 4),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _playFromList.length,
                          itemBuilder: (context, index) {
                            final isSelected = _currentPlayFromIndex == index;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: isSelected ? _primaryColor : Colors.white10,
                                  side: BorderSide(
                                    color: isSelected ? _primaryColor : Colors.white24,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  minimumSize: Size(0, 40),
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                ),
                                onPressed: () {
                                  if (_currentPlayFromIndex != index) {
                                    Navigator.of(context).pop();
                                    _switchPlayFrom(index);
                                  }
                                },
                                child: Text(
                                  _playFromList[index],
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // 选集列表
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16),
                          child: _currentPlayFromIndex < _playUrlsList.length
                              ? GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 2.5,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _playUrlsList[_currentPlayFromIndex].length,
                            itemBuilder: (context, index) {
                              final episode = _playUrlsList[_currentPlayFromIndex][index];
                              final isSelected = _currentEpisodeIndex == index;
                              return OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: isSelected ? _primaryColor : Colors.white10,
                                  side: BorderSide(
                                    color: isSelected ? _primaryColor : Colors.white24,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  minimumSize: Size(0, 40),
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  if (_currentEpisodeIndex != index) {
                                    _switchEpisode(index);
                                  }
                                },
                                child: Text(
                                  episode['name'] ?? '第${index + 1}集',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          )
                              : Center(
                            child: Text('无可用剧集', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 修改选集弹窗调用逻辑：横屏用右侧弹窗，竖屏用原有弹窗
  void _showPlaySourcePopup() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      _showLandscapeEpisodePopup();
    } else {
      // 原有竖屏弹窗逻辑
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    // 标题栏
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '选择播放源和剧集',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: Colors.grey.withOpacity(0.3)),

                    // 播放源选择1
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Text(
                            '播放源:',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(
                                  _playFromList.length,
                                  (index) => Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _currentPlayFromIndex = index;
                                        });
                                      },
                                      child: Container(
                                        width: 70,
                                        alignment: Alignment.center,
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _currentPlayFromIndex == index ? _primaryColor : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          _playFromList[index],
                                          style: TextStyle(
                                            color: _currentPlayFromIndex == index ? Colors.white : Colors.black87,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // 排序控制
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '剧集列表:',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '排序:',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isReverseSort = !_isReverseSort;
                                  });
                                },
                                child: Row(
                                  children: [
                                    Text(
                                      _isReverseSort ? '倒序' : '正序',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Icon(
                                      _isReverseSort
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      color: Colors.black,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),

                    // 剧集列表
                    Expanded(
                      child: _currentPlayFromIndex < _playUrlsList.length
                          ? GridView.builder(
                        padding: EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _playUrlsList[_currentPlayFromIndex].length,
                        itemBuilder: (context, index) {
                          final actualIndex = _isReverseSort
                              ? _playUrlsList[_currentPlayFromIndex].length - 1 - index
                              : index;
                          final episode = _playUrlsList[_currentPlayFromIndex][actualIndex];
                          final isSelected = _currentEpisodeIndex == actualIndex;

                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected
                                  ? _primaryColor
                                  : Colors.grey.withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              if (_currentEpisodeIndex != actualIndex) {
                                this.setState(() {
                                  _currentEpisodeIndex = actualIndex;
                                });
                                _switchEpisode(actualIndex);
                              }
                            },
                            child: Text(
                              episode['name'] ?? '第${actualIndex + 1}集',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      )
                          : Center(
                        child: Text(
                          '无可用剧集',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  /// 横屏专用：右侧弹出倍速选择弹窗
  void _showLandscapeSpeedPopup() {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: "关闭",
      transitionDuration: Duration(milliseconds: 250),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(1, 0),
            end: Offset(0, 0),
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (context, anim1, anim2) {
        final double popupWidth = MediaQuery.of(context).size.width * 3 / 16;
        final double popupHeight = MediaQuery.of(context).size.height;
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: popupWidth,
                  height: popupHeight,
                  color: Colors.black.withOpacity(0.7),
                  child: Column(
                    children: [
                      // 标题（无关闭按钮）
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 8, top: 18, bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '视频倍速',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // 倍速选项
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          itemCount: _speedOptions.length,
                          itemBuilder: (context, index) {
                            final speed = _speedOptions[index];
                            final isSelected = _playbackSpeed == speed;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: isSelected ? _primaryColor : Colors.white10,
                                  side: BorderSide(
                                    color: isSelected ? _primaryColor : Colors.white24,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  minimumSize: Size(0, 40),
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
                                    _videoPlayerController!.setPlaybackSpeed(speed);
                                    setState(() {
                                      _playbackSpeed = speed;
                                      // 同步弹幕速度
                                      _danmakuDuration = _danmakuDurationOrigin / speed;
                                      _updateDanmakuOption(duration: _danmakuDuration);
                                    });
                                  }
                                },
                                child: Text(
                                  '${speed}x',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 显示播放速度选择弹窗
  void _showPlaybackSpeedPopup() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      _showLandscapeSpeedPopup();
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '播放速度',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Divider(color: Colors.grey.withOpacity(0.3)),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.center,
                  children: _speedOptions.map((speed) {
                    final isSelected = _playbackSpeed == speed;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? _primaryColor
                              : Colors.grey.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
                            _videoPlayerController!.setPlaybackSpeed(speed);
                            setState(() {
                              _playbackSpeed = speed;
                              // 同步弹幕速度
                              _danmakuDuration = _danmakuDurationOrigin / speed;
                              _updateDanmakuOption(duration: _danmakuDuration);
                            });
                          }
                        },
                        child: Text(
                          '${speed}x',
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    }
  }

  /// 切换弹幕开关
  void _toggleDanmaku() {
    setState(() {
      _danmakuEnabled = !_danmakuEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isFullScreen) {
          _toggleFullScreen();
          return false;
        }
        return true;
      },
      child: _isFullScreen
          ? Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: _buildStackedVideoPlayer(),
        ),
      )
          : Scaffold(
        backgroundColor: _backgroundColor,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: _playerHeight,
                width: double.infinity,
                child: _buildStackedVideoPlayer(),
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  // 新增：重构后的视频播放器区域（Stack+Positioned）
  Widget _buildStackedVideoPlayer() {
    return Stack(
      children: [
        // 黑色背景，始终在最底层
        Container(color: Colors.black),
        // 1. 视频画面
        if (_chewieController != null)
          Chewie(controller: _chewieController!),
        // 2. 弹幕控件（直接填满视频区域，无Padding）
        if (_danmakuEnabled)
          Positioned.fill(
            child: IgnorePointer(
              child: DanmakuScreen(
                key: _danmuKey,
                createdController: (DanmakuController e) {
                  _danmakuController = e;
                },
                option: DanmakuOption(
                  opacity: _danmakuOpacity,
                  fontSize: _danmakuFontSize,
                  fontWeight: _danmakuFontWeight,
                  duration: _danmakuDuration,
                  staticDuration: _danmakuStaticDuration,
                  strokeWidth: _danmakuStrokeWidth,
                  massiveMode: _danmakuMassiveMode,
                  hideScroll: _danmakuHideScroll,
                  hideTop: _danmakuHideTop,
                  hideBottom: _danmakuHideBottom,
                  hideSpecial: _danmakuHideSpecial,
                  safeArea: _danmakuSafeArea,
                  lineHeight: _danmakuLineHeight,
                ),
              ),
            ),
          ),
        // 3. 加载指示器，始终居中
        if (_isLoading)
          Positioned.fill(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
            ),
          ),
        // 4. 错误提示
        if (_errorMessage != null && !_isLoading)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 42),
                SizedBox(height: 8),
                Text(_errorMessage!, style: TextStyle(color: Colors.white)),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_currentPlayUrl.isNotEmpty) {
                      _initializePlayer(_currentPlayUrl);
                    }
                  },
                  child: Text('重试'),
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                ),
              ],
            ),
          ),
        // 手势区域
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _showControls = !_showControls;
            });
            if (_showControls) _showControlsTemporarily();
          },
          onDoubleTap: () {
            _togglePlay();
          },
          onLongPressStart: (_) async {
            if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
              _lastPlaybackSpeed = _videoPlayerController!.value.playbackSpeed;
              await _videoPlayerController!.setPlaybackSpeed(2.0);
              // 弹幕速度同步加快
              _danmakuDurationOrigin = _danmakuDuration;
              setState(() {
                _danmakuDuration = _danmakuDurationOrigin / 2.0;
                _updateDanmakuOption(duration: _danmakuDuration);
                _showSpeedTip = true;
              });
              _speedTipAnimController?.forward(from: 0);
            }
          },
          onLongPressEnd: (_) async {
            if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
              await _videoPlayerController!.setPlaybackSpeed(_lastPlaybackSpeed);
              // 恢复弹幕速度
              setState(() {
                _danmakuDuration = _danmakuDurationOrigin;
                _updateDanmakuOption(duration: _danmakuDuration);
              });
              _speedTipAnimController?.reverse();
              Future.delayed(Duration(milliseconds: 200), () {
                if (mounted) {
                  setState(() {
                    _showSpeedTip = false;
                  });
                }
              });
            }
          },
          // 横向拖动快进/快退
          onHorizontalDragStart: (details) {
            if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
              _horizontalDragStartDx = details.globalPosition.dx;
              _seekStartPosition = _videoPlayerController!.value.position.inSeconds;
              _seekOffsetSeconds = 0;
              setState(() {
                _showSeekIndicator = true;
              });
            }
          },
          onHorizontalDragUpdate: (details) {
            if (_horizontalDragStartDx != null && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
              final dx = details.globalPosition.dx - _horizontalDragStartDx!;
              // 每50像素快进/快退5秒
              _seekOffsetSeconds = (dx / 50 * 5).round();
              setState(() {});
            }
          },
          onHorizontalDragEnd: (details) {
            if (_horizontalDragStartDx != null && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
              final int duration = _videoPlayerController!.value.duration?.inSeconds ?? 0;
              int target = _seekStartPosition + _seekOffsetSeconds;
              if (target < 0) target = 0;
              if (target > duration) target = duration;
              _videoPlayerController!.seekTo(Duration(seconds: target));
              setState(() {
                _showSeekIndicator = false;
                _seekOffsetSeconds = 0;
              });
            }
            _horizontalDragStartDx = null;
          },
          // 缩小亮度/音量调节区域
          onVerticalDragStart: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            final dx = details.globalPosition.dx;
            if (dx < screenWidth / 4) {
              _gestureType = 'brightness';
              _initialFocalPoint = details.globalPosition;
            } else if (dx > screenWidth * 3 / 4) {
              _gestureType = 'volume';
              _initialFocalPoint = details.globalPosition;
            } else {
              _gestureType = null;
            }
          },
          onVerticalDragUpdate: (details) {
            if (_gestureType == null) return;
            final delta = _initialFocalPoint.dy - details.globalPosition.dy;
            final screenHeight = MediaQuery.of(context).size.height;
            final change = delta / (screenHeight / 2);
            if (_gestureType == 'brightness') {
              _setBrightness(_brightnessValue + change);
            } else if (_gestureType == 'volume') {
              _setVolume(_volumeValue + change);
            }
            _initialFocalPoint = details.globalPosition;
          },
          onVerticalDragEnd: (details) {
            _gestureType = null;
          },
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        // 拖动快进/快退指示器
        if (_showSeekIndicator && _seekOffsetSeconds != 0)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_seekOffsetSeconds > 0 ? Icons.fast_forward : Icons.fast_rewind, color: Colors.white, size: 32),
                  SizedBox(width: 8),
                  Text('${_seekOffsetSeconds > 0 ? '快进' : '快退'}${_seekOffsetSeconds.abs()}秒', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ),
        // 亮度指示器
        if (_brightnessIndicator)
          Positioned(
            left: 20,
            top: MediaQuery.of(context).size.height / 2 - 50,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Icon(Icons.brightness_6, color: Colors.white),
                  const SizedBox(height: 5),
                  Text('${(_brightnessValue * 100).toInt()}%', style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        // 音量指示器1
        if (_volumeIndicator)
          Positioned(
            right: 20,
            top: MediaQuery.of(context).size.height / 2 - 50,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Icon(Icons.volume_up, color: Colors.white),
                  const SizedBox(height: 5),
                  Text('${(_volumeValue * 100).toInt()}%', style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        // 快退按钮
        if (_showBackwardButton)
          Positioned(
            left: MediaQuery.of(context).size.width / 6,
            top: MediaQuery.of(context).size.height / 2 - 30,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                children: [
                  Icon(Icons.fast_rewind, color: Colors.white, size: 30),
                  SizedBox(width: 5),
                  Text('10秒', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ),
        // 快进按钮
        if (_showForwardButton)
          Positioned(
            right: MediaQuery.of(context).size.width / 6,
            top: MediaQuery.of(context).size.height / 2 - 30,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                children: [
                  Text('10秒', style: TextStyle(color: Colors.white, fontSize: 16)),
                  SizedBox(width: 5),
                  Icon(Icons.fast_forward, color: Colors.white, size: 30),
                ],
              ),
            ),
          ),
        // 锁头按钮（横屏时右侧中间，距离右边16px）
        if (MediaQuery.of(context).orientation == Orientation.landscape && _showControls)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height / 2 - 28,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isLocked = !_isLocked;
                  if (_isLocked) {
                    _showControls = false;
                  }
                });
              },
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.black.withOpacity(0.5),
                child: Image.asset(
                  _isLocked ? 'assets/icon/suooff.png' : 'assets/icon/suoon.png',
                  color: Colors.white,
                  width: 24,
                  height: 24,
                ),
              ),
            ),
          ),
        // 顶部控制栏（只显示顶部一行）
        if (!_isLocked && _showControls && !_isLoading && _errorMessage == null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildPlayerTopBar(),
          ),
        // 底部控制栏（横屏两行/竖屏一行）
        if (!_isLocked && _showControls && !_isLoading && _errorMessage == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedPadding(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.only(bottom: 0),
              child: _buildPlayerBottomBar(),
            ),
          ),
        // 隐藏时底部进度条
        if (!_isLocked && !_showControls && !_isLoading && _errorMessage == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
              child: LinearProgressIndicator(
                value: _videoProgress,
                backgroundColor: Colors.black.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                minHeight: 3,
              ),
            ),
          ),
        // 长按2倍速提示
        if (_showSpeedTip && _speedTipAnim != null)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Builder(
              builder: (context) {
                final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                final double fontSize = isLandscape ? 18 : 15;
                final EdgeInsets padding = isLandscape
                    ? EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                    : EdgeInsets.symmetric(horizontal: 8, vertical: 5);
                final double borderRadius = isLandscape ? 18 : 14;
                return FadeTransition(
                  opacity: _speedTipAnim!,
                  child: ScaleTransition(
                    scale: _speedTipAnim!,
                    child: Center(
                      child: Container(
                        padding: padding,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        child: Text(
                          '2倍加速中',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // 新增：顶部控制栏（原Column顶部一行）1
  Widget _buildPlayerTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (_isFullScreen) {
                _toggleFullScreen();
              } else {
                Navigator.of(context).pop();
              }
            },
            splashRadius: 22,
          ),
          Expanded(
            child: Text(
              _videoDetail?['vod_name'] ?? '',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Image.asset(
              'assets/icon/touping.png',
              width: 24,
              height: 24,
            ),
            onPressed: () {
              // 投屏逻辑
            },
            splashRadius: 22,
          ),
          // 新增"更多"按钮，仅横屏显示
          if (MediaQuery.of(context).orientation == Orientation.landscape)
            IconButton(
              icon: Image.asset(
                'assets/icon/more.png',
                width: 24,
                height: 24,
              ),
              onPressed: _showLandscapeAspectRatioPopup,
              splashRadius: 22,
            ),
          if (MediaQuery.of(context).orientation == Orientation.landscape)
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center, // 关键：让内容紧凑居1
              children: [
                if (MediaQuery.of(context).orientation == Orientation.landscape)
                  SizedBox(
                    width: 36,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Image.asset(
                            _getBatteryIcon(),
                            width: 36,
                            height: 24,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Text(
                            _currentTime,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // 新增：底部控制栏（横屏两行/竖屏一行）1
  Widget _buildPlayerBottomBar() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (_videoPlayerController == null) {
      return SizedBox.shrink();
    }
    if (isLandscape) {
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _videoPlayerController!,
        builder: (context, value, child) {
          final position = value.position;
          final duration = value.duration;
          final isPlaying = value.isPlaying;
          final progress = duration.inMilliseconds > 0
              ? position.inMilliseconds / duration.inMilliseconds
              : 0.0;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 第一行：时间+进度条+总时长
                Row(
                  children: [
                    Text(
                      _formatDurationHMS(position.inMilliseconds),
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                        ),
                        child: Slider(
                          value: progress,
                          onChanged: (v) {
                            final seekTo = (duration.inMilliseconds * v).toInt();
                            _videoPlayerController?.seekTo(Duration(milliseconds: seekTo));
                          },
                          activeColor: _primaryColor,
                          inactiveColor: Colors.white24,
                        ),
                      ),
                    ),
                    Text(
                      _formatDurationHMS(duration.inMilliseconds),
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(height: 0),
                // 第二行：功能按钮（复用原有Row）
                _buildPlayerControlsRow(isPlaying, position, duration, progress),
              ],
            ),
          );
        },
      );
    }
    // 竖屏也用ValueListenableBuilder
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _videoPlayerController!,
      builder: (context, value, child) {
        final position = value.position;
        final duration = value.duration;
        final isPlaying = value.isPlaying;
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              // 播放/暂停
              IconButton(
                icon: Image.asset(
                  isPlaying ? 'assets/icon/off.png' : 'assets/icon/on.png',
                  width: 20,
                  height: 20,
                ),
                onPressed: () {
                  if (isPlaying) {
                    _videoPlayerController?.pause();
                  } else {
                    _videoPlayerController?.play();
                  }
                },
                splashRadius: 22,
              ),
              // 已播放时间
              Text(
                _formatDurationHMS(position.inMilliseconds),
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              // 进度条
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (v) {
                      final seekTo = (duration.inMilliseconds * v).toInt();
                      _videoPlayerController?.seekTo(Duration(milliseconds: seekTo));
                    },
                    activeColor: _primaryColor,
                    inactiveColor: Colors.white24,
                  ),
                ),
              ),
              // 总时长
              Text(
                _formatDurationHMS(duration.inMilliseconds),
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              // 全屏
              IconButton(
                icon: Image.asset(
                  _isFullScreen ? 'assets/icon/suoxiao.png' : 'assets/icon/quanping.png',
                  width: 24,
                  height: 24,
                ),
                onPressed: _toggleFullScreen,
                splashRadius: 22,
              ),
            ],
          ),
        );
      },
    );
  }

  // 新增：横屏底部功能按钮行（原横屏第二行Row）
  Widget _buildPlayerControlsRow(bool isPlaying, Duration position, Duration duration, double progress) {
    return AnimatedPadding(
      duration: Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: 0),
      child: Row(
        children: [
          // 播放/暂停
          IconButton(
            icon: Image.asset(
              isPlaying ? 'assets/icon/off.png' : 'assets/icon/on.png',
              width: 20,
              height: 20,
            ),
            onPressed: () {
              if (isPlaying) {
                _videoPlayerController?.pause();
              } else {
                _videoPlayerController?.play();
              }
            },
            splashRadius: 22,
          ),
          // 下一集
          IconButton(
            icon: Image.asset(
              'assets/icon/next.png',
              width: 24,
              height: 24,
            ),
            onPressed: (_currentPlayFromIndex < _playUrlsList.length &&
                _currentEpisodeIndex + 1 < _playUrlsList[_currentPlayFromIndex].length)
                ? () => _switchEpisode(_currentEpisodeIndex + 1)
                : null,
            splashRadius: 22,
          ),
          // 弹幕显示开关
          IconButton(
            icon: Image.asset(
              _danmakuEnabled ? 'assets/icon/danmuon.png' : 'assets/icon/danmuoff.png',
              width: 24,
              height: 24,
            ),
            onPressed: _toggleDanmaku,
            splashRadius: 22,
          ),
          // 中间弹幕设置+输入框（用Expanded包裹）或Spacer
          if (_danmakuEnabled)
            Expanded(
              child: Row(
                children: [
                  // 弹幕设置
                  // 弹幕设置
                  IconButton(
                    icon: Image.asset(
                      'assets/icon/danmusetting.png',
                      width: 24,
                      height: 24,
                    ),
                    onPressed: _danmakuEnabled ? _showLandscapeDanmakuSettingPopup : null,
                    splashRadius: 22,
                  ),
                  // 输入框
                  Expanded(
                    child: Container(
                      height: 32,
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        enabled: _danmakuEnabled,
                        style: TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: '发送弹幕',
                          hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                          filled: true,
                          fillColor: Colors.black26,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.send, color: Colors.white, size: 18),
                            onPressed: _danmakuEnabled ? () {/*发送弹幕逻辑*/} : null,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _showControls = true;
                          });
                        },
                        onSubmitted: _danmakuEnabled ? (text) {/*发送弹幕逻辑*/} : null,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            const Spacer(),
          // 右侧功能按钮组
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 倍速按钮（只显示"倍速"二字，点击弹出右侧倍速选择弹窗）0
              TextButton(
                onPressed: _showPlaybackSpeedPopup,
                child: Text(
                  '倍速',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size(0, 40),
                ),
              ),
              // 选集按钮
              TextButton(
                onPressed: _showPlaySourcePopup,
                child: Text(
                  '选集',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size(0, 40),
                ),
              ),
              // 全屏
              IconButton(
              icon: Image.asset(
                _isFullScreen ? 'assets/icon/suoxiao.png' : 'assets/icon/quanping.png',
                width: 20,
                height: 20,
                ),
                onPressed: _toggleFullScreen,
                splashRadius: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建内容区域
  Widget _buildContent() {
    return Expanded(
      child: Column(
        children: [
          _buildDanmakuTabBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentTab = index == 0 ? '简介' : '评论';
                });
              },
              children: [
                SingleChildScrollView(
        controller: _mainScrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoInfo(),
            _buildRelatedVideos(),
          ],
        ),
                ),
                _buildComments(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建视频信息区域
  Widget _buildVideoInfo() {
    if (_videoDetail == null) {
      return SizedBox.shrink();
    }

    final String title = _videoDetail!['vod_name'] ?? '';
    final String remarks = _videoDetail!['vod_remarks'] ?? '';
    final String year = _videoDetail!['vod_year'] ?? '';
    final String director = _videoDetail!['vod_director'] ?? '';
    final String type = _videoDetail?['type_name'] ?? _videoDetail?['type'] ?? _videoDetail?['typeName'] ?? '';
    final String status = _videoDetail!['vod_remarks'] ?? '';
    final String zan = _videoDetail!['vod_up'] ?? '';
    final String content = _videoDetail!['vod_content'] ?? '';

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和追番按钮
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (type.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(right: 8),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(0x332B7BFF), // 蓝色20%透明度
                    borderRadius: BorderRadius.circular(16), // 圆角长方形
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icon/type.png',
                        width: 15,
                        height: 15,
                      ),
                      SizedBox(width: 4),
                      Text(
                        type,
                        style: TextStyle(
                          color: Color(0xFF000D16), // #000D16
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              if (type.isNotEmpty)
                SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 追番按钮
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: GestureDetector(
                  onTap: _toggleFavorite,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    constraints: BoxConstraints(minHeight: 24),
                    decoration: BoxDecoration(
                      color: _isFavorited ? Color(0xFFF2F3F5) : _primaryColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _primaryColor, width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          _isFavorited ? 'assets/icon/zhuion.png' : 'assets/icon/zhuioff.png',
                          width: 15,
                          height: 15,
                        ),
                        SizedBox(width: 4),
                        Text(
                          _isFavorited ? '已追番' : '追番',
                          style: TextStyle(
                            color: _isFavorited ? Color(0xFF94999F) : Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          // vod_remarks 总集数 语言 + 正在观看人数同行居中0
          Builder(
            builder: (context) {
              List<Widget> infoWidgets = [];
              if (remarks.isNotEmpty) infoWidgets.add(Text(remarks, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w400)));
              if (_maxEpisodes > 0) {
                if (infoWidgets.isNotEmpty) infoWidgets.add(SizedBox(width: 6));
                infoWidgets.add(Text('共${_maxEpisodes}集', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w400)));
              }
              if (infoWidgets.isEmpty && _watchingCount == null && (_averageScore == null || _isLoadingScore)) return SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 0.0, bottom: 2.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ...infoWidgets,
                    if (_watchingCount != null) ...[
                      SizedBox(width: 6),
                      Row(
                        children: [
                          Icon(Icons.remove_red_eye, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 0),
                          Text(
                            '${_watchingCount}人在看',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ],
                    if (!_isLoadingScore && _averageScore != null) ...[
                      SizedBox(width: 6),
                      Text(
                        '${_averageScore!.toStringAsFixed(1)}分',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    Spacer(),
                    GestureDetector(
                      onTap: () => _showBlurbDetailBottomSheet(title, content, year, director, status, type, _averageScore),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('简介', style: TextStyle(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // 操作图标行1
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 点赞
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleLike,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/icon/zan.png',
                          width: 28,
                          height: 28,
                          color: _isLiked ? _primaryColor : null,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('${_videoDetail?['vod_up'] ?? '0'}', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    ],
                  ),
                ),
                // 下载
                Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _showDownloadSheet, // 新增：弹出下载弹窗
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/icon/down.png',
                          width: 28,
                          height: 28,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('下载', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
                // 催更
                Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        // 催更方法后续补充
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/icon/updates.png',
                          width: 28,
                          height: 28,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('催更', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
                // 反馈
                Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        // 反馈方法后续补充
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/icon/Feedback.png',
                          width: 28,
                          height: 28,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('反馈', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
                // 分享
                Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        // 分享方法后续补充
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/icon/Share.png',
                          width: 28,
                          height: 28,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('分享', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 第一行：播放源标题
                Text('播放源', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                // 第二行：播放源横向滚动选择
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _playFromList.length,
                    separatorBuilder: (_, __) => SizedBox(width: 10),
                    itemBuilder: (context, idx) {
                      final selected = idx == _currentPlayFromIndex;
                      return GestureDetector(
                        onTap: () {
                          if (!selected) _switchPlayFrom(idx);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? _primaryColor : Colors.grey[200],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _playFromList[idx],
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 2),
                // 第三行：选集+更多
                Row(
                  children: [
                    Text('选集', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Spacer(),
                    GestureDetector(
                      onTap: _showEpisodeMoreSheet,
                      child: Container(
                        margin: EdgeInsets.only(right: 0),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('更多', style: TextStyle(fontSize: 13, color: Colors.black54)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 5),
                // 第四行：横向滚动选集（每行3个，超出可右滑）1
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _currentPlayFromIndex < _playUrlsList.length ? _playUrlsList[_currentPlayFromIndex].length : 0,
                    separatorBuilder: (_, __) => SizedBox(width: 10),
                    itemBuilder: (context, idx) {
                      final selected = idx == _currentEpisodeIndex;
                      final episode = _playUrlsList[_currentPlayFromIndex][idx];
                      return GestureDetector(
                        onTap: () {
                          if (!selected) _switchEpisode(idx);
                        },
                        child: Container(
                          width: 70,
                          alignment: Alignment.center,
                          padding: EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? _primaryColor : Colors.grey[200],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            episode['name'] ?? '第${idx + 1}集',
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEpisodeMoreSheet() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 8, top: 16, bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '全部剧集',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, color: Colors.black54, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: ClampingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.6,
                  ),
                  itemCount: _currentPlayFromIndex < _playUrlsList.length ? _playUrlsList[_currentPlayFromIndex].length : 0,
                  itemBuilder: (context, idx) {
                    final selected = idx == _currentEpisodeIndex;
                    final episode = _playUrlsList[_currentPlayFromIndex][idx];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        if (!selected) _switchEpisode(idx);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected ? _primaryColor : Colors.grey[100],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          episode['name'] ?? '第${idx + 1}集',
                          style: TextStyle(color: selected ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );
}
  // 简介详情弹窗
  void _showBlurbDetailBottomSheet(String title, String content, String year, String director, String status, String type, double? score) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
        decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部标题和关闭按钮
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 评分
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Row(
                      children: [
                        Text('评分：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Icon(Icons.star, color: Color(0xFFF2C6B4), size: 18),
                        SizedBox(width: 4),
                        Text(
                          score != null ? score.toStringAsFixed(1) : '-',
                          style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  // 年份
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Row(
                      children: [
                        Text('年份：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(year, style: TextStyle(fontSize: 15, color: Colors.black87)),
                      ],
                    ),
                  ),
                  // 状态
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Row(
                      children: [
                        Text('状态：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(status, style: TextStyle(fontSize: 15, color: Colors.black87)),
                      ],
                    ),
                  ),
                  // 分类
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Row(
                      children: [
                        Text('分类：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(type, style: TextStyle(fontSize: 15, color: Colors.black87)),
                      ],
                    ),
                  ),
                  // 简介标题
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Text('简介', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      ],
                    ),
                  ),
                  // 简介内容
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      children: [
                        Text(
                          content.isNotEmpty ? content : '暂无简介',
                          style: TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 构建标签内容
  Widget _buildTabContent() {
    if (_currentTab == '简介') {
      return SizedBox.shrink();
    } else {
      return _buildComments();
    }
  }

  // 构建评论内容
  Widget _buildComments() {
    if (_isLoadingComments) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
        ),
      );
    }

    if (_commentErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_commentErrorMessage!, style: TextStyle(color: Colors.red)),
        ),
      );
    }

    if (_commentList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('暂无评论', style: TextStyle(color: _secondaryTextColor)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _commentList.length,
      itemBuilder: (context, index) {
        final comment = _commentList[index];
        final String? portraitUrl = comment['user_portrait'];
        return ListTile(
          leading: CircleAvatar(
            child: portraitUrl != null && portraitUrl.isNotEmpty && portraitUrl != "null"
                ? CachedNetworkImage(
              imageUrl: portraitUrl,
              placeholder: (context, url) => CircularProgressIndicator(),
              errorWidget: (context, url, error) => Icon(Icons.person),
              fit: BoxFit.cover,
            )
                : Icon(Icons.person),
          ),
          title: Text(comment['comment_name'] ?? '匿名用户'),
          subtitle: Text(comment['comment_content'] ?? ''),
          trailing: Text(
            _formatCommentTime(comment['comment_time'] ?? 0),
            style: TextStyle(fontSize: 12, color: _secondaryTextColor),
          ),
        );
      },
    );
  }

  // 构建相关推荐
  Widget _buildRelatedVideos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            '相关推荐',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
        ),
        SizedBox(height: 0),
        VideoStreaming(
          currentVideoId: _videoDetail?['vod_id'] != null ? int.tryParse(_videoDetail!['vod_id'].toString()) : null,
          typeId: _videoDetail?['type_id'] != null ? int.tryParse(_videoDetail!['type_id'].toString()) : null,
        ),
      ],
    );
  }

  // 格式化评论时间
  String _formatCommentTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  // 添加必要的方法
  void _togglePlay() {
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      if (_isPlaying) {
        _videoPlayerController!.pause();
      } else {
        _videoPlayerController!.play();
      }
      setState(() {
        _isPlaying = !_isPlaying;
      });
    }
  }

  Future<void> _seekTo(int milliseconds) async {
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      await _videoPlayerController!.seekTo(Duration(milliseconds: milliseconds));

      // 重置当前时间点之前的弹幕发送状态
      final double seekTime = milliseconds / 1000.0;
      for (var item in _danmakuItems) {
        if (item['time'] as double <= seekTime) {
          item['sent'] = true;
        } else {
          item['sent'] = false;
        }
      }
      print('跳转到 ${seekTime}s，重置弹幕发送状态');
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  String _formatDurationHMS(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  // 新增：画面设置弹窗
  void _showLandscapeAspectRatioPopup() {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: "关闭",
      transitionDuration: Duration(milliseconds: 250),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(1, 0),
            end: Offset(0, 0),
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (context, anim1, anim2) {
        final double popupWidth = MediaQuery.of(context).size.width * 5 / 16;
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: popupWidth,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.7),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 8, top: 18, bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '画面设置',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          children: [
                            _buildAspectOption('自适应', AspectRatioMode.auto),
                            _buildAspectOption('拉伸', AspectRatioMode.stretch),
                            _buildAspectOption('铺满', AspectRatioMode.cover),
                            _buildAspectOption('16:9', AspectRatioMode.ratio16_9),
                            _buildAspectOption('4:3', AspectRatioMode.ratio4_3),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAspectOption(String label, AspectRatioMode mode) {
    final isSelected = _aspectRatioMode == mode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? _primaryColor : Colors.white10,
          side: BorderSide(
            color: isSelected ? _primaryColor : Colors.white24,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: Size(0, 40),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        ),
        onPressed: () {
          Navigator.of(context).pop();
          setState(() {
            _aspectRatioMode = mode;
          });
          _updatePlayerAspectRatio();
        },
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // 新增：根据_aspectRatioMode刷新播放器显示模式
  void _updatePlayerAspectRatio() {
    if (_chewieController != null && _videoPlayerController != null) {
      double aspectRatio = 16 / 9;
      BoxFit? fit;
      switch (_aspectRatioMode) {
        case AspectRatioMode.auto:
          aspectRatio = _videoPlayerController!.value.aspectRatio;
          fit = BoxFit.contain;
          break;
        case AspectRatioMode.stretch:
          aspectRatio = _playerHeight > 0 ? MediaQuery.of(context).size.width / _playerHeight : 16 / 9;
          fit = BoxFit.fill;
          break;
        case AspectRatioMode.cover:
          aspectRatio = _videoPlayerController!.value.aspectRatio;
          fit = BoxFit.cover;
          break;
        case AspectRatioMode.ratio16_9:
          aspectRatio = 16 / 9;
          fit = BoxFit.contain;
          break;
        case AspectRatioMode.ratio4_3:
          aspectRatio = 4 / 3;
          fit = BoxFit.contain;
          break;
      }
      _chewieController!.dispose();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        showControls: false,
        aspectRatio: aspectRatio,
        allowFullScreen: false,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        customControls: null,
        // 通过自定义BoxFit实现拉伸/铺满等
        additionalOptions: (context) => [],
        placeholder: Container(color: Colors.black),
        materialProgressColors: ChewieProgressColors(
          playedColor: _primaryColor,
          handleColor: _primaryColor,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
        // 通过fit参数传递给Chewie（需自定义控件时用）
      );
      setState(() {});
    }
  }

  Future<void> loadDanmakuFromJson(String path) async {
    String data = await rootBundle.loadString(path);
    var jsonMap = json.decode(data);
    if (jsonMap is Map && jsonMap['comments'] is List) {
      for (var item in jsonMap['comments']) {
        _danmakuController?.addDanmaku(
          DanmakuContentItem(
            item['m'] ?? '',
            color: Colors.white,
          ),
        );
      }
    }
  }

  // 修改视频切换时的重置逻辑
  void _resetVideoState() {
    _videoStarted = false;
    _danmakuRunning = false;
    if (_danmakuController != null) {
      // 使用 addPostFrameCallback 来安全地调用 pause 和 clear
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _danmakuController != null) {
          _danmakuController!.pause();
          _danmakuController!.clear();
        }
      });
    }
    _danmakuItems.forEach((item) => item['sent'] = false);
  }

  // 添加新的辅助方法
  void _addTestDanmaku(String text, Color color, {DanmakuItemType type = DanmakuItemType.scroll}) {
    if (mounted && _danmakuController != null && _videoStarted) {
      _addDanmaku(text, color, type: type);
    }
  }

  // 横屏弹幕设置弹窗
  void _showLandscapeDanmakuSettingPopup() {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: "关闭",
      transitionDuration: Duration(milliseconds: 250),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(1, 0),
            end: Offset(0, 0),
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (context, anim1, anim2) {
        final double popupWidth = MediaQuery.of(context).size.width * 0.45;
        // 离散档位
        final areaValues = [0.0, 0.25, 0.5, 0.75, 1.0];
        final areaLabels = ['0%', '1/4', '1/2', '3/4', '全屏'];
        final sizeValues = [16.0, 17.0, 18.0, 19.0, 20.0, 21.0];
        final sizeLabels = ['16', '17', '18', '19', '20', '21'];
        final strokeValues = [0.8, 1.0, 1.5];
        final strokeLabels = ['纤细', '适中', '粗体'];
        final speedValues = [18.0, 14.0, 10.0, 7.0, 5.0];
        final speedLabels = ['缓慢', '较慢', '适中', '较快', '极快'];
        // 本地变量副本，声明在StatefulBuilder外部
        double areaValue = _danmakuLineHeight; // 用作显示区域，实际可映射到弹幕区域参数
        double sizeValue = _danmakuFontSize;
        double strokeValue = _danmakuStrokeWidth;
        double speedValue = _danmakuDuration;
        double opacity = _danmakuOpacity;
        bool massiveMode = _danmakuMassiveMode;
        // 取最近档位
        int _nearestIndex(List<double> values, double v) {
          double minDiff = (values[0] - v).abs();
          int idx = 0;
          for (int i = 1; i < values.length; i++) {
            double diff = (values[i] - v).abs();
            if (diff < minDiff) {
              minDiff = diff;
              idx = i;
            }
          }
          return idx;
        }
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return Container(
                      width: popupWidth,
                      height: double.infinity,
                      color: Colors.black.withOpacity(0.7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 顶部标题区
                          Padding(
                            padding: const EdgeInsets.only(left: 20, right: 8, top: 18, bottom: 8),
                            child: Row(
                              children: [
                                Text(
                                  '弹幕模式',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '推荐在精简模式下观影',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 13,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 模式切换区
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        massiveMode = false;
                                      });
                                      this.setState(() {
                                        _danmakuMassiveMode = false;
                                        _updateDanmakuOption(massiveMode: false);
                                      });
                                    },
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: !massiveMode ? _primaryColor : Colors.transparent,
                                        border: Border.all(
                                          color: !massiveMode ? _primaryColor : Colors.white.withOpacity(0.3),
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '精简模式',
                                        style: TextStyle(
                                          color: !massiveMode ? Colors.white : Colors.white70,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        massiveMode = true;
                                      });
                                      this.setState(() {
                                        _danmakuMassiveMode = true;
                                        _updateDanmakuOption(massiveMode: true);
                                      });
                                    },
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: massiveMode ? _primaryColor : Colors.transparent,
                                        border: Border.all(
                                          color: massiveMode ? _primaryColor : Colors.white.withOpacity(0.3),
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '海量模式',
                                        style: TextStyle(
                                          color: massiveMode ? Colors.white : Colors.white70,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // "弹幕设置"标题
                          Padding(
                            padding: const EdgeInsets.only(left: 20, top: 16, bottom: 8),
                            child: Text(
                              '弹幕设置',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // 弹幕设置区
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 显示区域
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 80, child: Text('显示区域', style: TextStyle(color: Colors.white))),
                                        Expanded(
                                          child: Slider(
                                            value: _nearestIndex(areaValues, areaValue).toDouble(),
                                            min: 0,
                                            max: (areaValues.length - 1).toDouble(),
                                            divisions: areaValues.length - 1,
                                            onChanged: (v) {
                                              int idx = v.round();
                                              setState(() {
                                                areaValue = areaValues[idx];
                                              });
                                              this.setState(() {
                                                _danmakuLineHeight = areaValues[idx];
                                                _updateDanmakuOption(lineHeight: areaValues[idx]);
                                              });
                                            },
                                            activeColor: _primaryColor,
                                            inactiveColor: Colors.white24,
                                          ),
                                        ),
                                        Text(areaLabels[_nearestIndex(areaValues, areaValue)], style: TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                  // 不透明度（连续）
                                  _buildSliderRowSB('不透明度', opacity, 0.2, 1.0, (v) {
                                    setState(() {
                                      opacity = v;
                                    });
                                    this.setState(() {
                                      _danmakuOpacity = v;
                                      _updateDanmakuOption(opacity: v);
                                    });
                                  }, suffix: '${(opacity * 100).toInt()}%'),
                                  // 弹幕大小
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 80, child: Text('弹幕大小', style: TextStyle(color: Colors.white))),
                                        Expanded(
                                          child: Slider(
                                            value: _nearestIndex(sizeValues, sizeValue).toDouble(),
                                            min: 0,
                                            max: (sizeValues.length - 1).toDouble(),
                                            divisions: sizeValues.length - 1,
                                            onChanged: (v) {
                                              int idx = v.round();
                                              setState(() {
                                                sizeValue = sizeValues[idx];
                                              });
                                              this.setState(() {
                                                _danmakuFontSize = sizeValues[idx];
                                                _updateDanmakuOption(fontSize: sizeValues[idx]);
                                              });
                                            },
                                            activeColor: _primaryColor,
                                            inactiveColor: Colors.white24,
                                          ),
                                        ),
                                        Text(sizeLabels[_nearestIndex(sizeValues, sizeValue)], style: TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                  // 弹幕粗细
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 80, child: Text('弹幕粗细', style: TextStyle(color: Colors.white))),
                                        Expanded(
                                          child: Slider(
                                            value: _nearestIndex(strokeValues, strokeValue).toDouble(),
                                            min: 0,
                                            max: (strokeValues.length - 1).toDouble(),
                                            divisions: strokeValues.length - 1,
                                            onChanged: (v) {
                                              int idx = v.round();
                                              setState(() {
                                                strokeValue = strokeValues[idx];
                                              });
                                              this.setState(() {
                                                _danmakuStrokeWidth = strokeValues[idx];
                                                _updateDanmakuOption(strokeWidth: strokeValues[idx]);
                                              });
                                            },
                                            activeColor: _primaryColor,
                                            inactiveColor: Colors.white24,
                                          ),
                                        ),
                                        Text(strokeLabels[_nearestIndex(strokeValues, strokeValue)], style: TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                  // 弹幕速度
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 80, child: Text('弹幕速度', style: TextStyle(color: Colors.white))),
                                        Expanded(
                                          child: Slider(
                                            value: _nearestIndex(speedValues, speedValue).toDouble(),
                                            min: 0,
                                            max: (speedValues.length - 1).toDouble(),
                                            divisions: speedValues.length - 1,
                                            onChanged: (v) {
                                              int idx = v.round();
                                              setState(() {
                                                speedValue = speedValues[idx];
                                              });
                                              this.setState(() {
                                                _danmakuDuration = speedValues[idx];
                                                _updateDanmakuOption(duration: speedValues[idx]);
                                              });
                                            },
                                            activeColor: _primaryColor,
                                            inactiveColor: Colors.white24,
                                          ),
                                        ),
                                        Text(speedLabels[_nearestIndex(speedValues, speedValue)], style: TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliderRowSB(String label, double value, double min, double max, ValueChanged<double> onChanged, {String? suffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: Colors.white))),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
              activeColor: _primaryColor,
              inactiveColor: Colors.white24,
            ),
          ),
          if (suffix != null)
            Text(suffix, style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  // 投屏弹窗,待实现
  void _showCastScreenPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _buildCastScreenSheet();
      },
    );
  }

  Widget _buildCastScreenSheet() {
    return StatefulBuilder(
      builder: (context, setState) {
        Future<void> refreshDevices() async {
          if (!context.mounted) return;
          setState(() {
            _isLoadingDevices = true;
            _castError = null;
          });
          try {
            final devices = await CastScreen.discoverDevice(
              timeout: const Duration(seconds: 3),
              onError: (e) => print('error: $e'),
            );
            if (!context.mounted) return;
            setState(() {
              _castDevices = devices;
              _isLoadingDevices = false;
            });
          } catch (e) {
            if (!context.mounted) return;
            setState(() {
              _castError = '发现设备失败: $e';
              _isLoadingDevices = false;
            });
          }
        }

        // 首次进入自动刷新
        if (_castDevices.isEmpty && !_isLoadingDevices) {
          refreshDevices();
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部栏
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            '投屏',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                          ),
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1),
                // 设备列表
                if (_isLoadingDevices)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
                  )
                else if (_castError != null)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(_castError!, style: TextStyle(color: Colors.red)),
                  )
                else if (_castDevices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('未发现可用设备', style: TextStyle(color: Colors.black54)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    itemCount: _castDevices.length,
                    separatorBuilder: (_, __) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      final device = _castDevices[index];
                      return ListTile(
                        leading: Icon(Icons.tv, color: _primaryColor),
                        title: Text(device.toString()),
                        onTap: () async {
                          Navigator.pop(context);
                          await _castToDevice(device);
                        },
                      );
                    },
                  ),
                // 刷新按钮
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    icon: Icon(Icons.refresh, color: Colors.white),
                    label: Text('刷新设备', style: TextStyle(color: Colors.white)),
                    onPressed: () => refreshDevices(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  // 司马东西1
  Future<void> _castToDevice(Device device) async {
    try {
      final url = _currentPlayUrl;
      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('当前无可用视频地址')));
        return;
      }
      if (device.avTransportService != null) {
        await device.avTransportService!.invokeMap('SetAVTransportURI', {
          'CurrentURI': url,
          'CurrentURIMetaData': '',
        });
        await device.avTransportService!.invokeMap('Play', {
          'Speed': '1',
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已投屏到设备')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('该设备不支持投屏')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('投屏失败: $e')));
    }
  }

  // 新增：弹幕输入框+开关条+
  Widget _buildDanmakuInputBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 36,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.13),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextField(
                enabled: _danmakuEnabled,
                style: TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '发送弹幕',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onSubmitted: _danmakuEnabled ? (text) {
                  // 这里可以添加弹幕发送逻辑
                } : null,
              ),
            ),
          ),
          Container(
            height: 36,
            child: Switch(
              value: _danmakuEnabled,
              onChanged: (v) {
                setState(() {
                  _danmakuEnabled = v;
                });
              },
              activeColor: _primaryColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  // 弹幕输入框+开关+tab一行
  Widget _buildDanmakuTabBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      margin: EdgeInsets.only(top: 4),
      child: Row(
        children: [
          _buildTabButton('简介', 0),
          SizedBox(width: 16),
          _buildTabButton('评论', 1),
          if (_commentList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                '(${_commentList.length})',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ),
          Spacer(),
          // 右侧弹幕输入框+开关始终显示
          Align(
            alignment: Alignment.centerRight,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: 36,
              width: _danmakuEnabled
                  ? MediaQuery.of(context).size.width * 0.5
                  : 48,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.13),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: _danmakuEnabled ? MainAxisAlignment.start : MainAxisAlignment.end,
                children: [
                  // 发送弹幕和分割线只在开的时候显示
                  if (_danmakuEnabled) ...[
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          // TODO: 弹出弹幕输入框，暂时空着
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            '发送弹幕',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 20,
                      color: Colors.grey[300],
                      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    ),
                  ],
                  // 弹幕开关按钮始终显示
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0, left: 4.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _danmakuEnabled = !_danmakuEnabled;
                        });
                      },
                      child: Image.asset(
                        _danmakuEnabled
                            ? 'assets/icon/danmuon.png'
                            : 'assets/icon/danmuoff.png',
                        width: 24,
                        height: 24,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onTabTap(String tab) {
    setState(() {
      _currentTab = tab;
      _pageController.animateToPage(
        tab == '简介' ? 0 : 1,
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    });
  }

  Future<void> _fetchAverageScore() async {
    setState(() {
      _isLoadingScore = true;
    });
    try {
      final result = await OvoApiManager().getScoreAverage(widget.vodId);
      print('评分接口返回: $result');
      double? avg;
      if (result is Map && result['average_score'] != null) {
        final raw = result['average_score'];
        print('raw average_score: $raw, type: ${raw.runtimeType}');
        if (raw is num) {
          avg = raw.toDouble();
        } else if (raw is String) {
          avg = double.tryParse(raw);
        } else {
          avg = 0.0;
        }
      }
      setState(() {
        _averageScore = avg;
        _isLoadingScore = false;
      });
    } catch (e) {
      setState(() {
        _averageScore = null;
        _isLoadingScore = false;
      });
    }
  }

  // 构建标签按钮（修复缺失）
  Widget _buildTabButton(String label, int tabIndex) {
    bool isSelected = (_tabIndicatorPosition.round() == tabIndex);
    double baseFontSize = 16;
    double selectedFontSize = baseFontSize + 4;

    return GestureDetector(
      onTap: () => _onTabTap(label),
      child: Container(
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: baseFontSize,
                  end: isSelected ? selectedFontSize : baseFontSize,
                ),
                duration: Duration(milliseconds: 180),
                curve: Curves.ease,
                builder: (context, value, child) {
                  return Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? _primaryColor : _secondaryTextColor,
                      fontSize: value,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                },
              ),
            ),
            // 指示器
            AnimatedContainer(
              duration: Duration(milliseconds: 100),
              curve: Curves.ease,
              margin: EdgeInsets.only(bottom: 0),
              height: 3,
              width: _tabIndicatorPosition == tabIndex
                  ? 32
                  : (_tabIndicatorPosition - tabIndex).abs() < 1
                      ? 32 * (1 - (_tabIndicatorPosition - tabIndex).abs())
                      : 0,
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getBatteryIcon() {
    if (_batteryState == BatteryState.charging) return 'assets/icon/poweron.png';
    if (_batteryLevel < 10) return 'assets/icon/power.png';
    if (_batteryLevel < 20) return 'assets/icon/power20.png';
    if (_batteryLevel < 40) return 'assets/icon/power40.png';
    if (_batteryLevel < 70) return 'assets/icon/power70.png';
    if (_batteryLevel < 80) return 'assets/icon/power80.png';
    if (_batteryLevel < 90) return 'assets/icon/power90.png';
    if (_batteryLevel <= 100) return 'assets/icon/power100.png';
    return 'assets/icon/power100.png';
  }

  Future<void> _fetchWatchingCount() async {
    if (_videoDetail == null) return;
    final vodId = _videoDetail?['vod_id'];
    if (vodId == null) return;
    // 确保token已设置
    OvoApiManager().setToken(UserStore().user?.token ?? '');
    try {
      print('请求watching_count: vod_id=$vodId, token=[32m${UserStore().user?.token}[0m');
      final count = await _apiManager.getWatchingCount(int.tryParse(vodId.toString()) ?? 0);
      print('watching_count接口返回: $count');
      if (mounted) {
        setState(() {
          _watchingCount = count;
        });
      }
    } catch (e) {
      print('watching_count接口异常: $e');
    }
  }

  // ========== 新增：下载弹窗 ========== //
  void _showDownloadSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _buildDownloadSheet();
      },
    );
  }

  Widget _buildDownloadSheet() {
    bool isReverse = false; // 方法内变量保证状态持久
    return StatefulBuilder(
      builder: (context, setState) {
        List<Map<String, String>> episodeList = [];
        if (_currentPlayFromIndex < _playUrlsList.length) {
          episodeList = List<Map<String, String>>.from(_playUrlsList[_currentPlayFromIndex]);
          if (isReverse) episodeList = episodeList.reversed.toList();
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部栏
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 8, top: 16, bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '下载',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isReverse = !isReverse;
                          });
                        },
                        child: Row(
                          children: [
                            Icon(
                              isReverse ? Icons.arrow_downward : Icons.arrow_upward,
                              color: Colors.black54,
                              size: 20,
                            ),
                            SizedBox(width: 2),
                            Text(isReverse ? '倒序' : '正序', style: TextStyle(color: Colors.black54, fontSize: 14)),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        margin: EdgeInsets.only(right: 4),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close, color: Colors.black54, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 集数网格
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height - _playerHeight - 180,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  child: Scrollbar(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: ClampingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.6,
                      ),
                      itemCount: episodeList.length,
                      itemBuilder: (context, index) {
                        final episode = episodeList[index];
                        return GestureDetector(
                          onTap: () async {
                            final episodeName = episode['name'] ?? '第${index + 1}集';
                            final rawUrl = episode['url'] ?? '';
                            final playFrom = _playFromList[_currentPlayFromIndex];
                            final vodName = _videoDetail?['vod_name']?.toString() ?? '';
                            final vodId = _videoDetail?['vod_id']?.toString() ?? '';
                            final vodPic = _videoDetail?['vod_pic']?.toString() ?? '';
                            String referer = '';
                            String url = rawUrl;
                            String forceFormat = '';

                            bool isDirectLink(String url) {
                              final lower = url.toLowerCase();
                              return lower.endsWith('.mp4') ||
                                  lower.endsWith('.m3u8') ||
                                  lower.endsWith('.flv') ||
                                  lower.endsWith('.mov') ||
                                  lower.endsWith('.mkv') ||
                                  lower.endsWith('.avi') ||
                                  lower.endsWith('.wmv') ||
                                  url.contains('cdn') ||
                                  url.contains('stream') ||
                                  url.contains('video') ||
                                  url.contains('media') ||
                                  url.contains('pitaya') ||
                                  url.contains('alisg') ||
                                  url.contains('tos-') ||
                                  url.contains('obj/');
                            }

                            _showDownloadOverlay('正在添加到下载中', loading: true);
                            Timer? timeoutTimer;
                            timeoutTimer = Timer(Duration(seconds: 10), () {
                              _hideDownloadOverlay(); // 10秒后自动隐藏
                            });
                            await Future.delayed(Duration(milliseconds: 200)); //  确保动画显示
                            try {
                              if (!isDirectLink(rawUrl)) {
                                final result = await _resolvePlayUrl(rawUrl, playFrom);
                                url = result['url'] as String? ?? '';
                                referer = (result['headers']?['Referer'] ?? '') as String;
                                final uri = Uri.tryParse(url);
                                final lastSegment = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
                                if (!lastSegment.contains('.')) {
                                  url = url + '?.mp4';
                                  forceFormat = 'mp4';
                                }
                              } else {
                                url = rawUrl;
                                final uri = Uri.tryParse(url);
                                final lastSegment = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
                                if (!lastSegment.contains('.')) {
                                  url = url + '?.mp4';
                                  forceFormat = 'mp4';
                                }
                              }
                              await startVideoDownload(
                                vodName: vodName,
                                vodId: vodId,
                                vodPic: vodPic,
                                url: url,
                                referer: referer,
                                episode: episodeName,
                                forceFormat: forceFormat,
                              );
                              timeoutTimer?.cancel();
                              _hideDownloadOverlay(text: '添加成功', success: true);
                            } catch (e) {
                              timeoutTimer?.cancel();
                              _hideDownloadOverlay(text: '添加失败', error: true);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              episode['name'] ?? '第${index + 1}集',
                              style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // 前往下载页按钮1
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => DownloadPage()),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '前往下载页',
                        style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDownloadOverlay(String text, {bool loading = false, bool success = false}) {
    _downloadOverlayEntry?.remove();
    _downloadOverlayTimer?.cancel();
    _downloadOverlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: 0,
          bottom: 120, // 高度上移
          child: Material(
            color: Colors.transparent,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(8), right: Radius.circular(22)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text, style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
                  SizedBox(width: 10),
                  if (loading)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(_primaryColor)),
                    ),
                  if (success)
                    Icon(Icons.check_circle, color: _primaryColor, size: 22),
                ],
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context)?.insert(_downloadOverlayEntry!);
  }

  void _hideDownloadOverlay({String? text, bool success = false, bool error = false}) {
    _downloadOverlayEntry?.remove();
    _downloadOverlayEntry = null;
    if (text != null) {
      _downloadOverlayEntry = OverlayEntry(
        builder: (context) {
          return Positioned(
            left: 0,
            bottom: 120, // 高度上移0
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(8), right: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(text, style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
                    SizedBox(width: 10),
                    if (success)
                      Icon(Icons.check_circle, color: _primaryColor, size: 22),
                  ],
                ),
              ),
            ),
          );
        },
      );
      Overlay.of(context)?.insert(_downloadOverlayEntry!);
      _downloadOverlayTimer = Timer(Duration(seconds: 3), () {
        _downloadOverlayEntry?.remove();
        _downloadOverlayEntry = null;
      });
    }
  }
}
// 下载引导3次重试0

Future<void> startVideoDownload({
  required String vodName,
  required String vodId,
  required String vodPic,
  required String url,
  required String referer,
  required String episode,
  required String forceFormat,
}) async {
  DownloadManager().addAndStartTask(
    vodId: vodId,
    vodName: vodName,
    vodPic: vodPic,
    url: url,
    referer: referer,
    episode: episode,
    forceFormat: forceFormat,
  );
}