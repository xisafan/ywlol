import 'package:flutter/material.dart';
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ovofun/page/base_player_interface.dart';
import 'package:synchronized/synchronized.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';

/// MediaKit播放器模块实现
class MediaKitPlayer implements BasePlayerInterface {
  /// MediaKit播放器实例
  late Player _player;
  late VideoController _controller;
  
  /// 播放器状态
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isFullScreen = false;
  String? _errorMessage;
  
  /// 视频信息
  String _currentUrl = '';
  
  /// 监听器列表
  final List<VoidCallback> _listeners = [];
  
  /// 资源锁，确保资源操作的互斥性
  final Lock _resourceLock = Lock();
  
  /// 资源释放标志和完成器
  bool _isDisposing = false;
  Completer<bool>? _disposeCompleter;
  
  /// 切换令牌，用于防止并发切换导致的问题
  int _switchToken = 0;
  
  /// 切换超时定时器
  Timer? _switchTimeoutTimer;
  
  /// 播放位置更新定时器
  Timer? _positionUpdateTimer;
  
  /// 构造函数
  MediaKitPlayer() {
    _initPlayer();
  }
  
  /// 初始化播放器
  void _initPlayer() {
    _player = Player();
    _controller = VideoController(_player);
    _setupEventListeners();
    _startPositionUpdateTimer();
  }
  
  /// 设置事件监听
  void _setupEventListeners() {
    _player.stream.playing.listen((playing) {
      _isPlaying = playing;
      _notifyListeners();
    });
    
    _player.stream.completed.listen((completed) {
      if (completed) {
        _isPlaying = false;
        _notifyListeners();
      }
    });
    
    _player.stream.error.listen((error) {
      _errorMessage = "播放错误: $error";
      _isPlaying = false;
      _notifyListeners();
    });
    
    _player.stream.duration.listen((duration) {
      // 视频时长更新
      _notifyListeners();
    });
    
    _player.stream.position.listen((position) {
      _notifyListeners();
    });
  }
  
  /// 启动播放位置更新定时器
  void _startPositionUpdateTimer() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_isInitialized && _isPlaying) {
        final position = _player.state.position;
      }
    });
  }
  
  /// 通知所有监听器
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
  
  @override
  Future<void> initialize(String videoUrl, {Map<String, String>? headers}) async {
    // 生成新的切换令牌
    final token = ++_switchToken;
    
    // 设置超时定时器，防止切换过程卡死
    _switchTimeoutTimer?.cancel();
    _switchTimeoutTimer = Timer(const Duration(seconds: 10), () {
      print('初始化超时，强制重置状态');
    });
    
    // 先释放旧资源
    await _releaseResources();
    
    // 检查令牌是否仍然有效
    if (token != _switchToken) {
      print('令牌已过期，取消初始化');
      return;
    }
    
    await _resourceLock.synchronized(() async {
      _currentUrl = videoUrl;
      _isInitialized = false;
      _isPlaying = false;
      _errorMessage = null;
      
      try {
        // 创建媒体源
        Media media;
        if (headers != null && headers.isNotEmpty) {
          media = Media(
            videoUrl,
            httpHeaders: headers,
          );
        } else {
          media = Media(videoUrl);
        }
        
        // 打开媒体源
        await _player.open(media);
        
        // 标记为已初始化
        _isInitialized = true;
        _notifyListeners();
      } catch (e) {
        _errorMessage = '初始化播放器失败: $e';
        print(_errorMessage);
        _notifyListeners();
      } finally {
        _switchTimeoutTimer?.cancel();
      }
    });
  }
  
  /// 释放资源
  Future<void> _releaseResources() async {
    // 如果已经在释放中，等待释放完成
    if (_isDisposing) {
      if (_disposeCompleter != null) {
        await _disposeCompleter!.future;
      }
      return;
    }
    
    // 设置释放锁和完成器
    _isDisposing = true;
    _disposeCompleter = Completer<bool>();
    
    await _resourceLock.synchronized(() async {
      try {
        // 暂停播放
        if (_isInitialized) {
          try {
            await _player.pause();
          } catch (e) {
            print('暂停播放失败: $e');
          }
        }
        
        // 确保资源完全释放
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('释放资源时发生异常: $e');
      } finally {
        _isDisposing = false;
        _disposeCompleter?.complete(true);
        _disposeCompleter = null;
      }
    });
  }
  
  @override
  Future<void> play() async {
    if (!_isInitialized) {
      _errorMessage = '播放器未初始化';
      return;
    }
    
    await _resourceLock.synchronized(() async {
      try {
        await _player.play();
        _isPlaying = true;
        _notifyListeners();
      } catch (e) {
        _errorMessage = '播放失败: $e';
        print(_errorMessage);
        _notifyListeners();
      }
    });
  }
  
  @override
  Future<void> pause() async {
    if (!_isInitialized) return;
    
    await _resourceLock.synchronized(() async {
      try {
        await _player.pause();
        _isPlaying = false;
        _notifyListeners();
      } catch (e) {
        print('暂停失败: $e');
      }
    });
  }
  
  @override
  Future<void> dispose() async {
    // 如果已经在释放中，等待释放完成
    if (_isDisposing) {
      if (_disposeCompleter != null) {
        await _disposeCompleter!.future;
      }
      return;
    }
    
    // 设置释放锁和完成器
    _isDisposing = true;
    _disposeCompleter = Completer<bool>();
    
    await _resourceLock.synchronized(() async {
      try {
        _listeners.clear();
        
        // 取消定时器
        _switchTimeoutTimer?.cancel();
        _positionUpdateTimer?.cancel();
        
        // 释放播放器
        try {
          await _player.dispose();
        } catch (e) {
          print('释放播放器资源失败: $e');
        }
        
        _isInitialized = false;
        _isPlaying = false;
        
        // 确保资源完全释放
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('释放资源时发生异常: $e');
      } finally {
        _isDisposing = false;
        _disposeCompleter?.complete(true);
        _disposeCompleter = null;
      }
    });
  }
  
  @override
  Future<void> seekTo(int position) async {
    if (!_isInitialized) return;
    
    await _resourceLock.synchronized(() async {
      try {
        // MediaKit使用Duration
        await _player.seek(Duration(milliseconds: position));
      } catch (e) {
        print('跳转失败: $e');
      }
    });
  }
  
  @override
  Future<void> setVolume(double volume) async {
    if (!_isInitialized) return;
    
    await _resourceLock.synchronized(() async {
      try {
        // MediaKit音量范围是0-100
        await _player.setVolume(volume * 100);
      } catch (e) {
        print('设置音量失败: $e');
      }
    });
  }
  
  @override
  Future<int> getCurrentPosition() async {
    if (!_isInitialized) return 0;
    
    try {
      final position = _player.state.position;
      return position.inMilliseconds;
    } catch (e) {
      print('获取当前播放位置失败: $e');
      return 0;
    }
  }
  
  @override
  Future<int> getDuration() async {
    if (!_isInitialized) return 0;
    
    try {
      final duration = _player.state.duration;
      return duration.inMilliseconds;
    } catch (e) {
      print('获取视频时长失败: $e');
      return 0;
    }
  }
  
  @override
  Widget getPlayerWidget() {
    // 使用ValueKey强制重建Widget树，确保SurfaceView释放
    return Stack(
      children: [
        // 视频播放器
        Video(
          controller: _controller,
          controls: NoVideoControls, // 不使用默认控制器，使用自定义控制器
          key: ValueKey('player_${_currentUrl}_${DateTime.now().millisecondsSinceEpoch}'),
        ),
      ],
    );
  }
  
  @override
  bool isPlaying() {
    return _isPlaying;
  }
  
  @override
  bool isInitialized() {
    return _isInitialized;
  }
  
  @override
  Future<void> enterFullScreen() async {
    // MediaKit没有直接的全屏API，需要通过外部实现
    _isFullScreen = true;
    _notifyListeners();
  }
  
  @override
  Future<void> exitFullScreen() async {
    // MediaKit没有直接的全屏API，需要通过外部实现
    _isFullScreen = false;
    _notifyListeners();
  }
  
  @override
  bool isFullScreen() {
    return _isFullScreen;
  }
  
  @override
  String getPlayerType() {
    return 'MediaKitPlayer';
  }
  
  @override
  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }
  
  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
  
  @override
  String? getErrorMessage() {
    return _errorMessage;
  }
  
  @override
  Future<void> setLooping(bool looping) async {
    if (!_isInitialized) return;
    
    await _resourceLock.synchronized(() async {
      try {
        await _player.setPlaylistMode(
          looping ? PlaylistMode.loop : PlaylistMode.single,
        );
      } catch (e) {
        print('设置循环播放失败: $e');
      }
    });
  }
  
  @override
  Future<void> setPlaybackSpeed(double speed) async {
    if (!_isInitialized) return;
    
    await _resourceLock.synchronized(() async {
      try {
        await _player.setRate(speed);
      } catch (e) {
        print('设置播放速度失败: $e');
      }
    });
  }
  
  /// 获取MediaKit播放器实例（用于高级功能）
  Player getMediaKitPlayerInstance() {
    return _player;
  }
  
  /// 获取MediaKit视频控制器（用于高级功能）
  VideoController getMediaKitVideoController() {
    return _controller;
  }
  
  /// 设置画面填充模式
  Future<void> setFit(BoxFit fit) async {
    // 需要通过Video widget的fit参数设置
    print('MediaKit播放器需要通过Video widget的fit参数设置画面填充模式');
  }
  
  /// 截图
  Future<String?> snapshot() async {
    // MediaKit没有直接的截图API
    print('MediaKit播放器不支持直接截图');
    return null;
  }
  
  /// 切换视频
  Future<void> switchVideo(String videoUrl, {Map<String, String>? headers}) async {
    // 生成新的切换令牌
    final token = ++_switchToken;
    
    // 设置超时定时器，防止切换过程卡死
    _switchTimeoutTimer?.cancel();
    _switchTimeoutTimer = Timer(const Duration(seconds: 10), () {
      print('切换超时，强制重置状态');
    });
    
    // 先释放旧资源
    await _releaseResources();
    
    // 检查令牌是否仍然有效
    if (token != _switchToken) {
      print('令牌已过期，取消切换');
      return;
    }
    
    // 初始化新视频
    await initialize(videoUrl, headers: headers);
  }
  
  /// 重新初始化播放器
  Future<void> reinitialize() async {
    await _resourceLock.synchronized(() async {
      try {
        // 释放旧播放器
        if (_isInitialized) {
          try {
            await _player.dispose();
          } catch (e) {
            print('释放旧播放器失败: $e');
          }
        }
        
        // 创建新播放器
        _player = Player();
        _controller = VideoController(_player);
        _setupEventListeners();
        
        // 如果有当前URL，重新加载
        if (_currentUrl.isNotEmpty) {
          await initialize(_currentUrl);
        }
      } catch (e) {
        print('重新初始化播放器失败: $e');
        _errorMessage = '重新初始化播放器失败: $e';
        _notifyListeners();
      }
    });
  }
}
