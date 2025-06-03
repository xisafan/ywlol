import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:ovofun/page/base_player_interface.dart';

/// ExoPlayer模块实现（基于video_player和chewie）- 修改版，禁用内置控制器
class ExoPlayer implements BasePlayerInterface {
  /// 视频播放器控制器
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  /// 播放器状态
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isFullScreen = false;
  String? _errorMessage;

  /// 视频信息
  String _currentUrl = '';

  /// 监听器列表
  final List<VoidCallback> _listeners = [];

  /// 资源释放锁
  bool _isDisposing = false;

  /// 资源释放完成器
  Completer<bool>? _disposeCompleter;

  /// 构造函数
  ExoPlayer();

  /// 通知所有监听器
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// 视频播放器状态变化监听
  void _onVideoPlayerControllerUpdate() {
    if (_videoPlayerController == null) return;

    if (_videoPlayerController!.value.hasError) {
      _errorMessage = "播放错误: ${_videoPlayerController!.value.errorDescription}";
      _isPlaying = false;
    } else {
      _isPlaying = _videoPlayerController!.value.isPlaying;
    }

    _notifyListeners();
  }

  /// Chewie控制器状态变化监听
  void _onChewieControllerUpdate() {
    if (_chewieController == null) return;

    _isFullScreen = _chewieController!.isFullScreen;
    _notifyListeners();
  }

  @override
  Future<void> initialize(String videoUrl, {Map<String, String>? headers}) async {
    // 如果正在释放资源，等待释放完成
    if (_isDisposing && _disposeCompleter != null) {
      await _disposeCompleter!.future;
    }

    _currentUrl = videoUrl;
    _isInitialized = false;
    _isPlaying = false;
    _errorMessage = null;

    try {
      // 释放旧的控制器
      await dispose();

      // 创建新的视频播放器控制器 - 使用新版本的API
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: headers ?? {},
      );

      // 添加状态监听
      _videoPlayerController!.addListener(_onVideoPlayerControllerUpdate);

      // 初始化视频播放器
      await _videoPlayerController!.initialize();

      // 创建Chewie控制器 - 修改：禁用所有内置控制器
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowFullScreen: false, // 禁用全屏按钮
        allowMuting: false, // 禁用静音按钮
        showControlsOnInitialize: false, // 初始化时不显示控制器
        showControls: false, // 完全禁用内置控制器
        // 使用新版本的进度条颜色设置
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blue,
          backgroundColor: Colors.grey.shade800,
          bufferedColor: Colors.grey.shade600,
        ),
        placeholder: const Center(
          child: CircularProgressIndicator(),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 42),
                const SizedBox(height: 8),
                Text(
                  '播放错误: $errorMessage',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    initialize(videoUrl, headers: headers);
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        },
      );

      // 添加Chewie控制器状态监听
      _chewieController!.addListener(_onChewieControllerUpdate);

      // 标记为已初始化
      _isInitialized = true;
      _notifyListeners();
    } catch (e) {
      _errorMessage = '初始化播放器失败: $e';
      print(_errorMessage);
      _notifyListeners();
    }
  }

  @override
  Future<void> play() async {
    if (!_isInitialized || _videoPlayerController == null) {
      _errorMessage = '播放器未初始化';
      return;
    }

    try {
      await _videoPlayerController!.play();
      _isPlaying = true;
      _notifyListeners();
    } catch (e) {
      _errorMessage = '播放失败: $e';
      print(_errorMessage);
      _notifyListeners();
    }
  }

  @override
  Future<void> pause() async {
    if (!_isInitialized || _videoPlayerController == null) return;

    try {
      await _videoPlayerController!.pause();
      _isPlaying = false;
      _notifyListeners();
    } catch (e) {
      print('暂停失败: $e');
    }
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

    try {
      _listeners.clear();

      // 先暂停播放
      if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        try {
          await _videoPlayerController!.pause();
        } catch (e) {
          print('暂停播放失败: $e');
        }
      }

      // 移除监听器 - 必须在dispose之前
      if (_videoPlayerController != null) {
        _videoPlayerController!.removeListener(_onVideoPlayerControllerUpdate);
      }

      if (_chewieController != null) {
        _chewieController!.removeListener(_onChewieControllerUpdate);
      }

      // 释放Chewie控制器
      if (_chewieController != null) {
        try {
          _chewieController!.dispose();
        } catch (e) {
          print('释放ChewieController失败: $e');
        } finally {
          _chewieController = null;
        }
      }

      // 释放VideoPlayer控制器
      if (_videoPlayerController != null) {
        try {
          await _videoPlayerController!.dispose();
        } catch (e) {
          print('释放VideoPlayerController失败: $e');
        } finally {
          _videoPlayerController = null;
        }
      }

      _isInitialized = false;
      _isPlaying = false;

      // 增加延迟，确保资源完全释放
      await Future.delayed(Duration(milliseconds: 500));
    } catch (e) {
      print('释放播放器资源失败: $e');
    } finally {
      _isDisposing = false;
      _disposeCompleter?.complete(true);
      _disposeCompleter = null;
    }
  }

  @override
  Future<void> seekTo(int position) async {
    if (!_isInitialized || _videoPlayerController == null) return;

    try {
      await _videoPlayerController!.seekTo(Duration(milliseconds: position));
    } catch (e) {
      print('跳转失败: $e');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    if (!_isInitialized || _videoPlayerController == null) return;

    try {
      await _videoPlayerController!.setVolume(volume);
    } catch (e) {
      print('设置音量失败: $e');
    }
  }

  @override
  Future<int> getCurrentPosition() async {
    if (!_isInitialized || _videoPlayerController == null) return 0;

    try {
      final position = _videoPlayerController!.value.position;
      return position.inMilliseconds;
    } catch (e) {
      print('获取当前播放位置失败: $e');
      return 0;
    }
  }

  @override
  Future<int> getDuration() async {
    if (!_isInitialized || _videoPlayerController == null) return 0;

    try {
      final duration = _videoPlayerController!.value.duration;
      return duration.inMilliseconds;
    } catch (e) {
      print('获取视频时长失败: $e');
      return 0;
    }
  }

  @override
  Widget getPlayerWidget() {
    if (!_isInitialized || _chewieController == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 修改：使用唯一Key重建Widget树，强制释放SurfaceView
    return AspectRatio(
      key: ValueKey('player_${_currentUrl}_${DateTime.now().millisecondsSinceEpoch}'),
      aspectRatio: _videoPlayerController!.value.aspectRatio,
      child: VideoPlayer(_videoPlayerController!),
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
    // 不使用内置全屏，由vedios.dart控制
    _isFullScreen = true;
    _notifyListeners();
  }

  @override
  Future<void> exitFullScreen() async {
    // 不使用内置全屏，由vedios.dart控制
    _isFullScreen = false;
    _notifyListeners();
  }

  @override
  bool isFullScreen() {
    return _isFullScreen;
  }

  @override
  String getPlayerType() {
    return 'ExoPlayer';
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
    if (!_isInitialized || _videoPlayerController == null) return;

    try {
      await _videoPlayerController!.setLooping(looping);
    } catch (e) {
      print('设置循环播放失败: $e');
    }
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    if (!_isInitialized || _videoPlayerController == null) return;

    try {
      await _videoPlayerController!.setPlaybackSpeed(speed);
    } catch (e) {
      print('设置播放速度失败: $e');
    }
  }

  /// 获取VideoPlayerController实例（用于高级功能）
  VideoPlayerController? getVideoPlayerController() {
    return _videoPlayerController;
  }

  /// 获取ChewieController实例（用于高级功能）
  ChewieController? getChewieController() {
    return _chewieController;
  }

  /// 自定义Chewie控制器 - 不再使用，避免控制器冲突
  void setCustomChewieController(ChewieController controller) {
    // 不再支持自定义Chewie控制器，避免与vedios.dart冲突
    print('警告：setCustomChewieController方法已禁用，请使用vedios.dart中的控制器');
  }
}
