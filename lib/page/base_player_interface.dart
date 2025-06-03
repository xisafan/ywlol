import 'package:flutter/material.dart';

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
