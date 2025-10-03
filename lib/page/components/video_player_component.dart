import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/api/ssl_Management.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';

/// 视频播放器组件
/// 负责视频播放、控制器、弹幕、投屏等功能
class VideoPlayerComponent extends StatefulWidget {
  final int vodId;
  final int? initialEpisodeIndex;
  final String? initialPlayFrom;
  final int? initialPositionSeconds;
  final Map<String, dynamic>? videoDetail;
  final ValueChanged<bool> onFullScreenChanged;
  final VoidCallback? onCastingChanged;

  const VideoPlayerComponent({
    Key? key,
    required this.vodId,
    this.initialEpisodeIndex,
    this.initialPlayFrom,
    this.initialPositionSeconds,
    this.videoDetail,
    required this.onFullScreenChanged,
    this.onCastingChanged,
  }) : super(key: key);

  @override
  VideoPlayerComponentState createState() => VideoPlayerComponentState();
}

class VideoPlayerComponentState extends State<VideoPlayerComponent> 
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  final OvoApiManager _apiManager = OvoApiManager();
  
  // 播放器相关状态
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlayerInitializing = false;
  bool _isPlaying = false;
  bool _isFullScreen = false;
  String _currentPlayUrl = '';
  bool _videoStarted = false;
  bool _videoCompleted = false;
  bool _isLocked = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  
  // 播放源和集数
  Map<String, dynamic> _playerMap = {};
  List<String> _playFromList = [];
  int _currentPlayFromIndex = 0;
  List<List<Map<String, String>>> _playUrlsList = [];
  int _currentEpisodeIndex = 0;
  int _maxEpisodes = 0;
  
  // 进度控制
  double _videoProgress = 0.0;
  Timer? _progressUpdateTimer;
  bool _isDraggingProgress = false;
  double _dragProgressValue = 0.0;
  int _currentVideoDuration = 0;
  
  // 播放速度
  double _playbackSpeed = 1.0;
  final List<double> _speedOptions = [3.0, 2.0, 1.5, 1.25, 1.0, 0.75, 0.5];
  
  // 手势控制
  double? _horizontalDragStartPosition;
  int _seekStartPosition = 0;
  double? _verticalDragStartDy;
  bool _isVerticalDrag = false;
  bool _isLeftSide = false;
  double _brightness = 0.5;
  double _volume = 0.5;
  
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
  
  // 弹幕设置
  double _danmakuOpacity = 1.0;
  double _danmakuFontSize = 16.0;
  FontWeight _danmakuFontWeight = FontWeight.normal;
  int _danmakuDuration = 8;
  int _danmakuStaticDuration = 5;
  double _danmakuStrokeWidth = 1.0;
  bool _danmakuMassiveMode = false;
  bool _danmakuHideScroll = false;
  bool _danmakuHideTop = false;
  bool _danmakuHideBottom = false;
  bool _danmakuHideSpecial = false;
  double _danmakuSafeArea = 0.0;
  double _danmakuLineHeight = 1.2;
  
  // 倍速提示
  bool _showSpeedTip = false;
  AnimationController? _speedTipAnimController;
  Animation<double>? _speedTipAnim;
  Timer? _longPressSpeedTipTimer;
  
  // 投屏相关
  bool _isCasting = false;
  CastingInfo? _castingInfo;
  Timer? _castingUpdateTimer;
  
  // 错误和重试
  String? _errorMessage;
  bool _isLoading = true;
  int _playerInitRetryCount = 0;
  final int _maxPlayerRetries = 3;
  bool _isSwitchingEpisode = false;
  bool _isSwitchingPlayFrom = false;
  String? _lastInitializedUrl;
  
  // 其他
  bool _isDisposingResources = false;
  Completer<bool>? _playerInitializationCompleter;
  int _switchEpisodeToken = 0;
  bool _wasPortrait = true;
  Orientation _previousOrientation = Orientation.portrait;
  VolumeController? _volumeController;
  StreamSubscription<double>? _volumeSubscription;
  
  // 主题色
  Color get _primaryColor => AppTheme.primaryColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    
    // 启用屏幕常亮
    WakelockPlus.enable();
    
    // 设置状态栏为黑色
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    
    // 记录当前屏幕方向
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _previousOrientation = MediaQuery.of(context).orientation;
        _wasPortrait = _previousOrientation == Orientation.portrait;
      }
    });
    
    // 启动进度条更新定时器
    _startProgressUpdateTimer();
    
    // 初始化播放器
    if (widget.videoDetail != null) {
      _initializeVideoPlayer();
    }
  }

  @override
  void dispose() {
    print("VideoPlayerComponent dispose called");
    
    // 退出时断开投屏
    if (_isCasting) {
      _exitCasting();
    }
    
    // 强制重置投屏状态，防止下次进入残留
    _isCasting = false;
    _castingInfo = null;
    
    // 取消所有定时器
    _controlsTimer?.cancel();
    _danmakuTimer?.cancel();
    _progressUpdateTimer?.cancel();
    _longPressSpeedTipTimer?.cancel();
    _castingUpdateTimer?.cancel();
    
    // 释放播放器资源
    _disposeAllPlayers();
    
    // 禁用屏幕常亮
    WakelockPlus.disable();
    
    // 恢复系统UI设置为默认状态
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    
    // 确保退出全屏并恢复竖屏
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    
    _volumeSubscription?.cancel();
    
    // 清理音量控制器
    try {
      if (_volumeController != null) {
        print('✅ 音量控制器已清理');
      }
    } catch (e) {
      print('❌ 清理音量控制器失败: $e');
    }
    
    _speedTipAnimController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    
    super.dispose();
  }

  /// 初始化亮度控制
  Future<void> _initBrightness() async {
    try {
      final brightness = await ScreenBrightness().current;
      setState(() {
        _brightness = brightness;
      });
    } catch (e) {
      print('获取屏幕亮度失败: $e');
    }
  }

  /// 初始化音量控制器
  Future<void> _initVolumeController() async {
    try {
      _volumeController = VolumeController.instance;
      final volume = await _volumeController!.getVolume();
      setState(() {
        _volume = volume;
      });
      
      // 音量已经在上面获取了
    } catch (e) {
      print('初始化音量控制器失败: $e');
    }
  }

  /// 构建视频播放器Stack
  Widget buildStackedVideoPlayer() {
    return Stack(
      children: [
        // 1. 黑色背景
        Container(color: Colors.black),
        
        // 2. 视频画面
        if (_chewieController != null) 
          Chewie(controller: _chewieController!),
        
        // 3. 弹幕控件（直接填满视频区域，无Padding）
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
                  duration: _danmakuDuration.toDouble(),
                  strokeWidth: _danmakuStrokeWidth,
                  lineHeight: _danmakuLineHeight,
                ),
              ),
            ),
          ),
        
        // 4. 加载指示器，始终居中 - 优化为更小更圆滑
        if (_isLoading)
          Positioned.fill(
            child: Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/image/vodloading.gif',
                    width: 48,
                    height: 48,
                  ),
                ),
              ),
            ),
          ),
          
        // 5. 错误提示
        if (_errorMessage != null)
          Positioned.fill(
            child: Center(
              child: Container(
                margin: EdgeInsets.all(20),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '播放失败',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _retryInitPlayer,
                      child: Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 6. 手势检测层
        Positioned.fill(
          child: GestureDetector(
            onTap: _toggleControlsVisibility,
            onDoubleTap: _togglePlayPause,
            onLongPressStart: _onLongPressStart,
            onLongPressEnd: _onLongPressEnd,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Container(color: Colors.transparent),
          ),
        ),

        // 7. 投屏遮罩层
        if (_isCasting) _buildCastingMask(),

        // 8. 顶部控制栏
        if (!_isLocked && _showControls && !_isLoading && _errorMessage == null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildPlayerTopBar(),
          ),

        // 9. 底部控制栏
        if (!_isLocked && _showControls && !_isLoading && _errorMessage == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildPlayerBottomBar(),
          ),

        // 10. 隐藏时底部进度条
        if (!_isLocked &&
            !_showControls &&
            !_isLoading &&
            _errorMessage == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
              child: LinearProgressIndicator(
                value: _videoProgress,
                backgroundColor: Colors.black.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
                minHeight: 3,
              ),
            ),
          ),

        // 11. 长按2倍速提示
        if (_showSpeedTip && _speedTipAnim != null)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Builder(
              builder: (context) {
                final isLandscape =
                    MediaQuery.of(context).orientation == Orientation.landscape;
                final double fontSize = isLandscape ? 18 : 15;
                final EdgeInsets padding =
                    isLandscape
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
                          '长按 2x 倍速播放',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
            ),
          ),

        // 12. 锁定指示器
        if (_isLocked)
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isLocked = false;
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.lock,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 构建顶部控制栏
  Widget _buildPlayerTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 返回按钮
            IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (_isFullScreen) {
                  _toggleFullScreen();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
            
            // 标题（如果有的话）
            Expanded(
              child: Text(
                widget.videoDetail?['vod_name'] ?? '',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // 投屏按钮
            IconButton(
              icon: Image.asset(
                'assets/icon/touping.png',
                width: 20,
                height: 20,
                color: Colors.white,
              ),
              onPressed: _showCastScreenPopup,
              splashRadius: 18,
            ),
            
            // 画中画按钮（仅Android）
            if (Platform.isAndroid)
              IconButton(
                tooltip: '画中画',
                onPressed: () async {
                  if (MediaQuery.of(context).orientation ==
                      Orientation.landscape) {
                    // 横屏：直接锁定并进入画中画
                    setState(() {
                      _isLocked = true;
                    });
                    await _enterPiP();
                  } else {
                    // 竖屏：先切横屏再锁定再进入画中画
                    _toggleFullScreen(); // 进入横屏
                    await Future.delayed(Duration(milliseconds: 400)); // 等待动画
                    setState(() {
                      _isLocked = true;
                    });
                    await _enterPiP();
                  }
                },
                icon: Icon(
                  Icons.picture_in_picture_outlined,
                  color: Colors.white,
                  size:
                      MediaQuery.of(context).orientation == Orientation.portrait
                          ? 20
                          : 24,
                ),
                splashRadius:
                    MediaQuery.of(context).orientation == Orientation.portrait
                        ? 18
                        : 22,
              ),
              
            // "更多"按钮，仅横屏显示
            if (MediaQuery.of(context).orientation == Orientation.landscape)
              IconButton(
                icon: Image.asset(
                  'assets/icon/more.png',
                  width: 24,
                  height: 24,
                  color: Colors.white,
                ),
                onPressed: _showLandscapeAspectRatioPopup,
                splashRadius: 18,
              ),
              
            // 锁定按钮，仅横屏显示
            if (MediaQuery.of(context).orientation == Orientation.landscape)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _isLocked ? Icons.lock : Icons.lock_open,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _isLocked = !_isLocked;
                      });
                    },
                    splashRadius: 18,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 构建底部控制栏
  Widget _buildPlayerBottomBar() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    
    final isPlaying = _videoPlayerController?.value.isPlaying ?? false;
    final position = _videoPlayerController?.value.position ?? Duration.zero;
    final duration = _videoPlayerController?.value.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0 
        ? position.inMilliseconds / duration.inMilliseconds 
        : 0.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
      child: SafeArea(
        child: isLandscape ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 第一行：进度条
            Row(
              children: [
                Text(
                  _formatDurationHMS(position.inMilliseconds),
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                SizedBox(width: 4),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                        disabledThumbRadius: 6,
                        elevation: 0,
                        pressedElevation: 0,
                      ),
                      overlayShape: RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Slider(
                      value: progress,
                      onChanged: (v) {
                        final seekTo =
                            (duration.inMilliseconds * v).toInt();
                        _videoPlayerController?.seekTo(
                          Duration(milliseconds: seekTo),
                        );
                      },
                      activeColor: Theme.of(context).primaryColor,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  _formatDurationHMS(duration.inMilliseconds),
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 0),
            // 第二行：功能按钮
            _buildPlayerControlsRow(
              isPlaying,
              position,
              duration,
            ),
          ],
        ) : 
        // 竖屏：单行布局
        Row(
          children: [
            // 播放/暂停按钮
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 24,
              ),
              onPressed: _togglePlayPause,
            ),
            
            // 当前时间
            Text(
              _formatDurationHMS(position.inMilliseconds),
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            
            // 进度条
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                    disabledThumbRadius: 6,
                    elevation: 0,
                    pressedElevation: 0,
                  ),
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                ),
                child: Slider(
                  value: progress,
                  onChanged: (v) {
                    final seekTo = (duration.inMilliseconds * v).toInt();
                    _videoPlayerController?.seekTo(
                      Duration(milliseconds: seekTo),
                    );
                  },
                  activeColor: Theme.of(context).primaryColor,
                  inactiveColor: Colors.white24,
                ),
              ),
            ),
            
            // 总时长
            Text(
              _formatDurationHMS(duration.inMilliseconds),
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            
            // 全屏按钮
            IconButton(
              icon: Icon(
                _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
                size: 24,
              ),
              onPressed: _toggleFullScreen,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建播放器控制按钮行（横屏模式）
  Widget _buildPlayerControlsRow(
    bool isPlaying,
    Duration position,
    Duration duration,
  ) {
    return Row(
      children: [
        // 播放/暂停按钮
        IconButton(
          icon: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 32,
          ),
          onPressed: _togglePlayPause,
        ),
        
        SizedBox(width: 8),
        
        // 上一集按钮
        IconButton(
          icon: Icon(Icons.skip_previous, color: Colors.white, size: 24),
          onPressed: _currentEpisodeIndex > 0 ? _playPreviousEpisode : null,
        ),
        
        // 下一集按钮
        IconButton(
          icon: Icon(Icons.skip_next, color: Colors.white, size: 24),
          onPressed: _currentEpisodeIndex < _maxEpisodes - 1 ? _playNextEpisode : null,
        ),
        
        Spacer(),
        
        // 倍速按钮
        GestureDetector(
          onTap: _showSpeedPopup,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${_playbackSpeed}x',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        
        SizedBox(width: 8),
        
        // 画质按钮（如果有多个播放源）
        if (_playFromList.length > 1)
          GestureDetector(
            onTap: _showPlayFromPopup,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _playFromList.isNotEmpty ? _playFromList[_currentPlayFromIndex] : '画质',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          
        SizedBox(width: 8),
        
        // 全屏按钮
        IconButton(
          icon: Icon(
            _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
            color: Colors.white,
            size: 24,
          ),
          onPressed: _toggleFullScreen,
        ),
      ],
    );
  }

  /// 构建投屏遮罩层
  Widget _buildCastingMask() {
    final info = _castingInfo!;
    double maxSeconds =
        info.duration.inSeconds > 0 ? info.duration.inSeconds.toDouble() : 1.0;
    double currentSeconds = info.position.inSeconds.toDouble();
    double progress = maxSeconds > 0 ? (currentSeconds / maxSeconds).clamp(0.0, 1.0) : 0.0;

    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 投屏设备名称
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cast_connected, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '投屏至 ${info.deviceName}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // 播放控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 上一集
                IconButton(
                  icon: Icon(Icons.skip_previous, color: Colors.white, size: 36),
                  onPressed: _currentEpisodeIndex > 0 ? _playPreviousEpisode : null,
                ),

                SizedBox(width: 24),

                // 播放/暂停
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      info.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: _toggleCastingPlayPause,
                  ),
                ),

                SizedBox(width: 24),

                // 下一集
                IconButton(
                  icon: Icon(Icons.skip_next, color: Colors.white, size: 36),
                  onPressed: _currentEpisodeIndex < _maxEpisodes - 1 ? _playNextEpisode : null,
                ),
              ],
            ),

            SizedBox(height: 32),

            // 进度信息
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  // 进度条
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  ),
                  
                  SizedBox(height: 8),
                  
                  // 时间信息
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDurationHMS(info.position.inMilliseconds),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        _formatDurationHMS(info.duration.inMilliseconds),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // 断开投屏按钮
            TextButton.icon(
              onPressed: _exitCasting,
              icon: Icon(Icons.cast_connected, color: Colors.white70),
              label: Text(
                '断开投屏',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== 播放器控制方法 ==========
  
  /// 切换播放/暂停
  void _togglePlayPause() {
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      if (_videoPlayerController!.value.isPlaying) {
        _videoPlayerController!.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        _videoPlayerController!.play();
        setState(() {
          _isPlaying = true;
        });
      }
    }
  }

  /// 切换全屏
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
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    
    widget.onFullScreenChanged(_isFullScreen);
  }

  /// 切换控制器显示/隐藏
  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });
    
    if (_showControls) {
      _startControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  /// 开始控制器自动隐藏定时器
  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  /// 启动进度更新定时器
  void _startProgressUpdateTimer() {
    _progressUpdateTimer?.cancel();
    _progressUpdateTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (!mounted || _videoPlayerController == null) return;
      
      if (_videoPlayerController!.value.isInitialized && !_isDraggingProgress) {
        final position = _videoPlayerController!.value.position;
        final duration = _videoPlayerController!.value.duration;
        
        if (duration.inMilliseconds > 0) {
          setState(() {
            _videoProgress = position.inMilliseconds / duration.inMilliseconds;
            _currentVideoPosition = position.inSeconds;
            _currentVideoDuration = duration.inMilliseconds;
          });
        }
      }
    });
  }

  // ========== 手势控制方法 ==========
  
  /// 长按开始
  void _onLongPressStart(LongPressStartDetails details) {
    if (_videoPlayerController != null && _videoPlayerController!.value.isPlaying) {
      _videoPlayerController!.setPlaybackSpeed(2.0);
      setState(() {
        _showSpeedTip = true;
      });
      _speedTipAnimController?.forward();
      
      // 5秒后自动隐藏提示
      _longPressSpeedTipTimer?.cancel();
      _longPressSpeedTipTimer = Timer(Duration(seconds: 5), () {
        if (mounted) {
          _speedTipAnimController?.reverse().then((_) {
            if (mounted) {
              setState(() {
                _showSpeedTip = false;
              });
            }
          });
        }
      });
    }
  }

  /// 长按结束
  void _onLongPressEnd(LongPressEndDetails details) {
    if (_videoPlayerController != null) {
      _videoPlayerController!.setPlaybackSpeed(_playbackSpeed);
      _longPressSpeedTipTimer?.cancel();
      _speedTipAnimController?.reverse().then((_) {
        if (mounted) {
          setState(() {
            _showSpeedTip = false;
          });
        }
      });
    }
  }

  /// 拖拽开始
  void _onPanStart(DragStartDetails details) {
    if (_isLocked) return;
    
    _horizontalDragStartPosition = details.localPosition.dx;
    _verticalDragStartDy = details.localPosition.dy;
    _isVerticalDrag = false;
    
    final screenWidth = MediaQuery.of(context).size.width;
    _isLeftSide = details.localPosition.dx < screenWidth / 2;
    
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      _seekStartPosition = _videoPlayerController!.value.position.inMilliseconds;
    }
  }

  /// 拖拽更新
  void _onPanUpdate(DragUpdateDetails details) {
    if (_isLocked) return;
    
    final deltaX = details.delta.dx;
    final deltaY = details.delta.dy;
    
    // 判断是水平拖拽还是垂直拖拽
    if (!_isVerticalDrag && deltaX.abs() > deltaY.abs() && deltaX.abs() > 10) {
      // 水平拖拽 - 调整播放进度
      _handleHorizontalDrag(deltaX);
    } else if (deltaY.abs() > deltaX.abs() && deltaY.abs() > 10) {
      // 垂直拖拽 - 调整音量/亮度
      _isVerticalDrag = true;
      _handleVerticalDrag(deltaY);
    }
  }

  /// 拖拽结束
  void _onPanEnd(DragEndDetails details) {
    if (_isLocked) return;
    
    // 重置拖拽状态
    _horizontalDragStartPosition = null;
    _verticalDragStartDy = null;
    _isVerticalDrag = false;
  }

  /// 处理水平拖拽（进度调整）
  void _handleHorizontalDrag(double deltaX) {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;
    
    final duration = _videoPlayerController!.value.duration.inMilliseconds;
    if (duration <= 0) return;
    
    // 计算进度变化（每像素代表0.1%的进度）
    final progressChange = deltaX / MediaQuery.of(context).size.width * 0.3;
    final newProgress = (_seekStartPosition / duration + progressChange).clamp(0.0, 1.0);
    final newPosition = (duration * newProgress).toInt();
    
    setState(() {
      _isDraggingProgress = true;
      _dragProgressValue = newProgress;
    });
    
    _videoPlayerController!.seekTo(Duration(milliseconds: newPosition));
  }

  /// 处理垂直拖拽（音量/亮度调整）
  void _handleVerticalDrag(double deltaY) {
    final sensitivity = 0.005; // 调整灵敏度
    
    if (_isLeftSide) {
      // 左侧：调整亮度
      _adjustBrightness(-deltaY * sensitivity);
    } else {
      // 右侧：调整音量
      _adjustVolume(-deltaY * sensitivity);
    }
  }

  /// 调整亮度
  void _adjustBrightness(double delta) async {
    try {
      final newBrightness = (_brightness + delta).clamp(0.0, 1.0);
      await ScreenBrightness().setScreenBrightness(newBrightness);
      setState(() {
        _brightness = newBrightness;
      });
    } catch (e) {
      print('调整亮度失败: $e');
    }
  }

  /// 调整音量
  void _adjustVolume(double delta) async {
    try {
      final newVolume = (_volume + delta).clamp(0.0, 1.0);
      await _volumeController?.setVolume(newVolume);
      setState(() {
        _volume = newVolume;
      });
    } catch (e) {
      print('调整音量失败: $e');
    }
  }

  // ========== 播放器初始化相关方法 ==========
  
  /// 初始化视频播放器
  Future<void> _initializeVideoPlayer() async {
    if (widget.videoDetail == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 解析播放器数据
      _parsePlayerData(widget.videoDetail!);
      
      // 初始化播放源
      await _initializePlaySources();
      
      // 开始播放
      await _playCurrentEpisode();
      
    } catch (e) {
      print('初始化播放器失败: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '初始化播放器失败: $e';
      });
    }
  }

  /// 解析播放器数据
  void _parsePlayerData(Map<String, dynamic> videoDetail) {
    final vodPlayFrom = videoDetail['vod_play_from'] ?? '';
    final vodPlayUrl = videoDetail['vod_play_url'] ?? '';
    
    if (vodPlayFrom.isEmpty || vodPlayUrl.isEmpty) {
      throw Exception('播放源数据为空');
    }
    
    _playFromList = vodPlayFrom.split('\$\$\$');
    final playUrlsList = vodPlayUrl.split('\$\$\$');
    
    if (_playFromList.length != playUrlsList.length) {
      throw Exception('播放源数据不匹配');
    }
    
    _playUrlsList.clear();
    for (String playUrls in playUrlsList) {
      final episodeList = <Map<String, String>>[];
      final episodes = playUrls.split('#');
      
      for (String episode in episodes) {
        if (episode.trim().isNotEmpty) {
          final parts = episode.split('\$');
          if (parts.length >= 2) {
            episodeList.add({
              'name': parts[0],
              'url': parts[1],
            });
          }
        }
      }
      _playUrlsList.add(episodeList);
    }
    
    // 设置最大集数
    if (_playUrlsList.isNotEmpty) {
      _maxEpisodes = _playUrlsList[0].length;
    }
  }

  /// 初始化播放源
  Future<void> _initializePlaySources() async {
    // 设置初始播放源索引
    if (widget.initialPlayFrom != null) {
      final index = _playFromList.indexOf(widget.initialPlayFrom!);
      if (index >= 0) {
        _currentPlayFromIndex = index;
      }
    }
    
    // 设置初始集数索引
    if (widget.initialEpisodeIndex != null) {
      _currentEpisodeIndex = widget.initialEpisodeIndex!.clamp(0, _maxEpisodes - 1);
    }
  }

  /// 播放当前集数
  Future<void> _playCurrentEpisode() async {
    if (_playUrlsList.isEmpty || 
        _currentPlayFromIndex >= _playUrlsList.length ||
        _currentEpisodeIndex >= _playUrlsList[_currentPlayFromIndex].length) {
      throw Exception('播放地址不存在');
    }
    
    final episode = _playUrlsList[_currentPlayFromIndex][_currentEpisodeIndex];
    final playUrl = episode['url']!;
    
    await _initializePlayer(playUrl);
  }

  /// 初始化播放器
  Future<void> _initializePlayer(String playUrl) async {
    if (playUrl == _lastInitializedUrl && _videoPlayerController != null) {
      return; // 避免重复初始化相同URL
    }
    
    setState(() {
      _isPlayerInitializing = true;
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 释放之前的播放器
      await _disposePlayer();
      
      // 创建新的播放器控制器
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(playUrl));
      
      // 监听播放器状态变化
      _videoPlayerController!.addListener(_onVideoPlayerStateChanged);
      
      // 初始化播放器
      await _videoPlayerController!.initialize();
      
      // 创建Chewie控制器
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        autoPlay: true,
        looping: false,
        showControls: false, // 使用自定义控制器
        allowFullScreen: false, // 使用自定义全屏
        allowMuting: true,
        allowPlaybackSpeedChanging: false, // 使用自定义倍速控制
      );
      
      // 设置播放速度
      await _videoPlayerController!.setPlaybackSpeed(_playbackSpeed);
      
      // 跳转到初始位置
      if (widget.initialPositionSeconds != null) {
        await _videoPlayerController!.seekTo(
          Duration(seconds: widget.initialPositionSeconds!),
        );
      }
      
      setState(() {
        _currentPlayUrl = playUrl;
        _lastInitializedUrl = playUrl;
        _isPlayerInitializing = false;
        _isLoading = false;
        _isPlaying = true;
        _videoStarted = true;
        _playerInitRetryCount = 0;
      });
      
      // 开始自动隐藏控制器
      _startControlsTimer();
      
    } catch (e) {
      print('播放器初始化失败: $e');
      setState(() {
        _isPlayerInitializing = false;
        _isLoading = false;
        _errorMessage = '播放器初始化失败: $e';
      });
      
      // 如果未达到最大重试次数，自动重试
      if (_playerInitRetryCount < _maxPlayerRetries) {
        _playerInitRetryCount++;
        print('自动重试初始化播放器 (${_playerInitRetryCount}/${_maxPlayerRetries})');
        Future.delayed(Duration(seconds: 2), () => _initializePlayer(playUrl));
      }
    }
  }

  /// 播放器状态变化监听
  void _onVideoPlayerStateChanged() {
    if (!mounted || _videoPlayerController == null) return;
    
    final value = _videoPlayerController!.value;
    
    if (value.hasError) {
      print('播放器错误: ${value.errorDescription}');
      setState(() {
        _errorMessage = '播放错误: ${value.errorDescription}';
        _isLoading = false;
      });
    }
    
    if (value.isInitialized) {
      setState(() {
        _isPlaying = value.isPlaying;
      });
      
      // 检查是否播放结束
      if (value.position >= value.duration && value.duration.inSeconds > 0) {
        _onVideoCompleted();
      }
    }
  }

  /// 视频播放完成
  void _onVideoCompleted() {
    setState(() {
      _videoCompleted = true;
    });
    
    // 如果开启自动播放下一集且还有下一集
    if (_currentEpisodeIndex < _maxEpisodes - 1) {
      _playNextEpisode();
    }
  }

  /// 播放下一集
  void _playNextEpisode() {
    if (_currentEpisodeIndex < _maxEpisodes - 1) {
      setState(() {
        _currentEpisodeIndex++;
      });
      _playCurrentEpisode();
    }
  }

  /// 播放上一集
  void _playPreviousEpisode() {
    if (_currentEpisodeIndex > 0) {
      setState(() {
        _currentEpisodeIndex--;
      });
      _playCurrentEpisode();
    }
  }

  /// 重试初始化播放器
  void _retryInitPlayer() {
    _playerInitRetryCount = 0;
    _initializeVideoPlayer();
  }

  /// 释放播放器
  Future<void> _disposePlayer() async {
    try {
      _chewieController?.dispose();
      _chewieController = null;
      
      _videoPlayerController?.removeListener(_onVideoPlayerStateChanged);
      await _videoPlayerController?.dispose();
      _videoPlayerController = null;
      
      _currentPlayUrl = '';
    } catch (e) {
      print('释放播放器失败: $e');
    }
  }

  /// 释放所有播放器资源
  Future<void> _disposeAllPlayers() async {
    if (_isDisposingResources) return;
    _isDisposingResources = true;
    
    try {
      await _disposePlayer();
    } finally {
      _isDisposingResources = false;
    }
  }

  // ========== 弹幕相关方法 ==========
  
  /// 加载弹幕数据
  Future<void> _loadDanmakuData() async {
    if (!_danmakuEnabled) return;
    
    setState(() {
      _isLoadingDanmaku = true;
      _danmakuErrorMessage = null;
    });
    
    try {
      final response = await _apiManager.get('/danmaku', queryParameters: {
        'vod_id': widget.vodId,
        'episode': _currentEpisodeIndex + 1,
      });
      
      if (response['code'] == 1) {
        final danmakuList = response['data'] as List;
        setState(() {
          _danmakuItems = danmakuList.map((item) => {
            'time': item['time'] ?? 0,
            'text': item['text'] ?? '',
            'color': item['color'] ?? Colors.white.value,
            'type': item['type'] ?? 'scroll',
          }).cast<Map<String, dynamic>>().toList();
          _isLoadingDanmaku = false;
        });
        
        _startDanmakuTimer();
      } else {
        setState(() {
          _isLoadingDanmaku = false;
          _danmakuErrorMessage = response['msg'] ?? '加载弹幕失败';
        });
      }
    } catch (e) {
      print('加载弹幕失败: $e');
      setState(() {
        _isLoadingDanmaku = false;
        _danmakuErrorMessage = '加载弹幕失败: $e';
      });
    }
  }

  /// 启动弹幕定时器
  void _startDanmakuTimer() {
    _danmakuTimer?.cancel();
    _danmakuTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted || _danmakuController == null || !_danmakuRunning) return;
      
      // 发送当前时间的弹幕
      final currentTime = _currentVideoPosition;
      for (final danmaku in _danmakuItems) {
        final time = danmaku['time'] as int;
        if (time == currentTime) {
          _danmakuController!.addDanmaku(DanmakuContentItem(
            danmaku['text'] as String,
            color: Color(danmaku['color'] as int),
          ));
        }
      }
    });
  }

  /// 获取弹幕类型（简化版）
  // canvas_danmaku包不支持type参数，保留此方法作为占位符
  String _getDanmakuType(String type) {
    return type; // 简化返回
  }

  /// 发送弹幕
  Future<void> sendDanmaku(String content, {Color? color, String type = 'scroll'}) async {
    if (content.trim().isEmpty) return;
    
    try {
      final user = UserStore().user;
      if (user == null) {
        throw Exception('请先登录');
      }
      
      final response = await _apiManager.post('/danmaku/send', data: {
        'vod_id': widget.vodId,
        'episode': _currentEpisodeIndex + 1,
        'time': _currentVideoPosition,
        'text': content.trim(),
        'color': (color ?? Colors.white).value,
        'type': type,
      });
      
      if (response['code'] == 1) {
        // 立即显示发送的弹幕
        _danmakuController?.addDanmaku(DanmakuContentItem(
          content.trim(),
          color: color ?? Colors.white,
        ));
        
        // 添加到本地弹幕列表
        _danmakuItems.add({
          'time': _currentVideoPosition,
          'text': content.trim(),
          'color': (color ?? Colors.white).value,
          'type': type,
        });
      } else {
        throw Exception(response['msg'] ?? '发送弹幕失败');
      }
    } catch (e) {
      print('发送弹幕失败: $e');
      throw e;
    }
  }

  // ========== 投屏相关方法 ==========
  
  /// 显示投屏选择弹窗
  void _showCastScreenPopup() {
    // 实现投屏设备选择弹窗
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 200,
        child: Center(
          child: Text(
            '投屏功能开发中...',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  /// 切换投屏播放/暂停
  void _toggleCastingPlayPause() {
    // 实现投屏播放控制
    if (_castingInfo != null) {
      setState(() {
        _castingInfo!.isPlaying = !_castingInfo!.isPlaying;
      });
    }
  }

  /// 退出投屏
  void _exitCasting() {
    setState(() {
      _isCasting = false;
      _castingInfo = null;
    });
    _castingUpdateTimer?.cancel();
    widget.onCastingChanged?.call();
  }

  // ========== 其他控制弹窗方法 ==========
  
  /// 显示倍速选择弹窗
  void _showSpeedPopup() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '播放速度',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: _speedOptions.map((speed) => GestureDetector(
                onTap: () {
                  setState(() {
                    _playbackSpeed = speed;
                  });
                  _videoPlayerController?.setPlaybackSpeed(speed);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _playbackSpeed == speed ? _primaryColor : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${speed}x',
                    style: TextStyle(
                      color: _playbackSpeed == speed ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示播放源选择弹窗
  void _showPlayFromPopup() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '选择画质',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Column(
              children: _playFromList.asMap().entries.map((entry) {
                final index = entry.key;
                final playFrom = entry.value;
                return ListTile(
                  title: Text(playFrom),
                  trailing: _currentPlayFromIndex == index 
                    ? Icon(Icons.check, color: _primaryColor)
                    : null,
                  onTap: () {
                    if (_currentPlayFromIndex != index) {
                      setState(() {
                        _currentPlayFromIndex = index;
                      });
                      _playCurrentEpisode();
                    }
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示横屏画面比例弹窗
  void _showLandscapeAspectRatioPopup() {
    // 实现画面比例选择弹窗
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 200,
        child: Center(
          child: Text(
            '画面设置开发中...',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  /// 进入画中画模式
  Future<void> _enterPiP() async {
    try {
      // 实现画中画功能
      print('进入画中画模式');
    } catch (e) {
      print('进入画中画失败: $e');
    }
  }

  // ========== 工具方法 ==========
  
  /// 格式化时长为 HH:MM:SS 格式
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

  @override
  Widget build(BuildContext context) {
    return buildStackedVideoPlayer();
  }
}

/// 投屏信息类
class CastingInfo {
  final String deviceName;
  final dynamic upnpTransport;
  Duration position;
  Duration duration;
  bool isPlaying;

  CastingInfo({
    required this.deviceName,
    required this.upnpTransport,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
  });
}
