# 自定义播放器组件分析

本文档整理了项目中的自定义播放器组件相关代码，包括接口定义、实现和特殊功能。

## 1. 播放器接口定义

项目定义了一个通用播放器接口 `BasePlayerInterface`，所有播放器模块必须实现这个接口以确保与视频播放页面的兼容性。

```dart
/// 通用播放器接口
/// 所有播放器模块必须实现这个接口以确保与vedios.dart的兼容性
abstract class BasePlayerInterface {
  /// 初始化播放器
  /// [videoUrl] - 视频URL
  /// [headers] - 可选的HTTP头信息
  Future<void> initialize(String videoUrl, {Map<String, String>? headers});
  
  /// 播放视频
  Future<void> play();
  
  /// 暂停视频
  Future<void> pause();
  
  /// 释放播放器资源
  Future<void> dispose();
  
  /// 跳转到指定位置
  /// [position] - 目标位置（毫秒）
  Future<void> seekTo(int position);
  
  /// 设置音量
  /// [volume] - 音量值（0.0到1.0）
  Future<void> setVolume(double volume);
  
  /// 获取当前播放位置（毫秒）
  Future<int> getCurrentPosition();
  
  /// 获取视频总时长（毫秒）
  Future<int> getDuration();
  
  /// 获取播放器Widget
  /// 返回实际的播放器UI组件
  Widget getPlayerWidget();
  
  /// 是否正在播放
  bool isPlaying();
  
  /// 是否已初始化
  bool isInitialized();
  
  /// 进入全屏模式
  Future<void> enterFullScreen();
  
  /// 退出全屏模式
  Future<void> exitFullScreen();
  
  /// 是否处于全屏模式
  bool isFullScreen();
  
  /// 获取播放器类型名称
  String getPlayerType();
  
  /// 添加播放状态监听
  void addListener(VoidCallback listener);
  
  /// 移除播放状态监听
  void removeListener(VoidCallback listener);
  
  /// 获取播放错误信息
  String? getErrorMessage();
  
  /// 设置循环播放
  /// [looping] - 是否循环播放
  Future<void> setLooping(bool looping);
  
  /// 设置播放速度
  /// [speed] - 播放速度（1.0为正常速度）
  Future<void> setPlaybackSpeed(double speed);
}
```

## 2. 播放器组件实现

项目中的播放器组件主要在 `VideoDetailPage` 类中实现，使用了 `video_player` 和 `chewie` 两个Flutter插件来构建播放器功能。

### 2.1 播放器状态管理

```dart
// 视频播放器相关
VideoPlayerController? _videoPlayerController;
ChewieController? _chewieController;
bool _isPlayerInitializing = false;
bool _isPlaying = false;
bool _isFullScreen = false;
String _currentPlayUrl = '';
bool _videoStarted = false;

// 播放器信息map
Map<String, dynamic> _playerMap = {};

// 自动播放下一集标志
bool _autoPlayNextEpisode = true;

// 视频播放完成标志
bool _videoCompleted = false;

// 播放速度
double _playbackSpeed = 1.0;
final List<double> _speedOptions = [1.0, 2.0, 3.0, 4.0];

// 画面设置模式枚举
AspectRatioMode _aspectRatioMode = AspectRatioMode.auto;

// 控件锁定状态
bool _isLocked = false;

// 画中画状态
bool _isInPiP = false;
Floating? _floating;
```

### 2.2 播放器初始化

```dart
/// 初始化播放器
Future<void> _initializePlayer(String url, {String? rawUrl, int? episodeIndex, int? playFromIndex, int? customSeekSeconds, Map<String, String>? headers}) async {
  // 生成新token
  final int thisInitToken = ++_playerInitToken;

  if (url == _lastInitializedUrl) {
    print('⚠️ URL未改变，跳过 (url: $url, last: $_lastInitializedUrl)');
    return;
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
  if (thisInitToken != _playerInitToken) {
    _playerInitializationCompleter?.complete(false);
    return;
  }

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

    // 初始化VideoPlayerController with custom headers
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      httpHeaders: headers,
      formatHint: VideoFormat.other, // 明确指定视频格式
    );

    // 添加监听器
    _videoPlayerController!.addListener(_onVideoPositionChanged);

    // 初始化VideoPlayerController
    await _videoPlayerController!.initialize();
    if (thisInitToken != _playerInitToken) {
      _playerInitializationCompleter?.complete(false);
      return;
    }
    
    _startProgressUpdateTimer();

    // 切集后自动恢复上次用户设置的倍速
    try {
      await _videoPlayerController!.setPlaybackSpeed(_playbackSpeed);
      // 同步弹幕速度
      setState(() {
        _danmakuDuration = _danmakuDurationOrigin / _playbackSpeed;
        _updateDanmakuOption(duration: _danmakuDuration);
      });
    } catch (e) {
      print('设置倍速失败: $e');
    }

    if (!mounted) {
      _playerInitializationCompleter!.complete(false);
      return;
    }

    // 初始化ChewieController
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: true,
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

    // 获取弹幕数据 - 完全异步，不阻塞播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchDanmaku(rawUrl ?? url); // 弹幕异步加载，完全不阻塞视频播放
      }
    });

    // 处理历史进度跳转
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

    // 执行跳转和播放
    if (targetSeconds != null && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      await _videoPlayerController!.seekTo(Duration(seconds: targetSeconds));
    }

    // 确保播放器开始播放
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      await _videoPlayerController!.play();

      // 验证播放状态
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _videoPlayerController != null) {
          if (_videoPlayerController!.value.isPlaying) {
            _saveWatchHistory();
          }
        }
      });
    }

    // 标记初始化成功
    _playerInitializationCompleter!.complete(true);

  } catch (e) {
    print('播放器初始化失败: $e');

    // 特殊处理403错误 - 可能是headers问题
    if (e.toString().contains('403') || e.toString().contains('Response code: 403')) {
      try {
        // 尝试1: 使用更完整的浏览器headers
        Map<String, String> enhancedHeaders = {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Accept-Encoding': 'identity',
          'Connection': 'keep-alive',
          'Sec-Fetch-Dest': 'video',
          'Sec-Fetch-Mode': 'no-cors',
          'Sec-Fetch-Site': 'cross-site',
        };

        // 保留原有的Referer
        if (headers?.containsKey('Referer') == true) {
          enhancedHeaders['Referer'] = headers!['Referer']!;
        }

        _videoPlayerController?.dispose();
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          httpHeaders: enhancedHeaders,
          formatHint: VideoFormat.other,
        );

        _videoPlayerController!.addListener(_onVideoPositionChanged);
        await _videoPlayerController!.initialize();

      } catch (retryError) {
        // 最后尝试：无headers直接播放
        try {
          _videoPlayerController?.dispose();
          _videoPlayerController = VideoPlayerController.networkUrl(
            Uri.parse(url),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
            formatHint: VideoFormat.other,
          );

          _videoPlayerController!.addListener(_onVideoPositionChanged);
          await _videoPlayerController!.initialize();

        } catch (finalError) {
          if (mounted) {
            setState(() {
              _errorMessage = '播放器初始化失败: 视频源可能已失效';
              _isPlayerInitializing = false;
              _isLoading = false;
            });
          }
          _playerInitializationCompleter!.complete(false);
          return;
        }
      }
    } else {
      // 非403错误的原有处理
      if (mounted) {
        setState(() {
          _errorMessage = '播放器初始化失败: ${e.toString()}';
          _isPlayerInitializing = false;
          _isLoading = false;
        });
      }
      _playerInitializationCompleter!.complete(false);
      return;
    }

    if (!mounted) {
      _playerInitializationCompleter!.complete(false);
      return;
    }
  }

  // 添加缓冲状态监听
  _videoPlayerController?.addListener(() {
    if (!mounted) return;

    final isBuffering = _videoPlayerController?.