import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../page/download_page.dart';

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final List<DownloadTask> _tasks = [];
  final Map<String, CancelToken> _cancelTokens = {};

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  String _taskKey(DownloadTask t) => '${t.vodId}_${t.episode}';

  void addTask(DownloadTask task) {
    // 避免重复添加
    if (_tasks.any((t) => t.vodId == task.vodId && t.episode == task.episode)) return;
    task.status = 'downloading';
    _tasks.add(task);
    notifyListeners();
    try {
      _startDownload(task);
    } catch (e) {
      task.status = 'failed';
      notifyListeners();
    }
  }

  void addAndStartTask({
    required String vodId,
    required String vodName,
    required String vodPic,
    required String url,
    required String referer,
    required String episode,
    required String forceFormat,
    bool? isM3U8,
  }) {
    final bool autoM3U8 = isM3U8 ?? url.trim().toLowerCase().endsWith('.m3u8');
    final task = DownloadTask(
      vodId: vodId,
      vodName: vodName,
      vodPic: vodPic,
      url: url,
      referer: referer,
      episode: episode,
      forceFormat: forceFormat,
      progress: 0,
      status: 'downloading',
      savePath: '',
      isM3U8: autoM3U8,
      totalFileSize: 0,
    );
    addTask(task);
  }

  void updateTask(DownloadTask task) {
    final idx = _tasks.indexWhere((t) => t.vodId == task.vodId && t.episode == task.episode);
    if (idx != -1) {
      _tasks[idx] = task;
      notifyListeners();
    }
  }

  void removeTask(DownloadTask task) {
    final key = _taskKey(task);
    _cancelTokens[key]?.cancel();
    _cancelTokens.remove(key);
    // 删除本地文件或目录
    if (task.savePath.isNotEmpty) {
      final fileOrDir = File(task.savePath);
      final dir = Directory(task.savePath);
      try {
        if (task.isM3U8) {
          if (dir.existsSync()) {
            dir.deleteSync(recursive: true);
          }
        } else {
          if (fileOrDir.existsSync()) {
            fileOrDir.deleteSync();
          }
        }
      } catch (e) {
        print('删除本地文件/目录失败: $e');
      }
    }
    _tasks.removeWhere((t) => t.vodId == task.vodId && t.episode == task.episode);
    notifyListeners();
  }

  void clear() {
    for (var t in _tasks) {
      final key = _taskKey(t);
      _cancelTokens[key]?.cancel();
    }
    _cancelTokens.clear();
    _tasks.clear();
    notifyListeners();
  }

  void pauseTask(DownloadTask task) {
    final key = _taskKey(task);
    _cancelTokens[key]?.cancel();
    _cancelTokens.remove(key);
    task.status = 'paused';
    notifyListeners();
  }

  void resumeTask(DownloadTask task) {
    if (task.status == 'paused') {
      task.status = 'downloading';
      notifyListeners();
      _startDownload(task, resume: true);
    }
  }

  Future<String> _getSaveDir() async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
      String publicDirPath = '${dir?.parent.parent.parent.parent.path}/Download/ovofun';
      Directory targetDir = Directory(publicDirPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      return targetDir.path;
    } else {
      final d = await getApplicationDocumentsDirectory();
      final path = '${d.path}/ovofun_downloads';
      await Directory(path).create(recursive: true);
      return path;
    }
  }

  void _startDownload(DownloadTask task, {bool resume = false}) async {
    final key = _taskKey(task);
    final cancelToken = CancelToken();
    _cancelTokens[key] = cancelToken;
    final dio = Dio();
    try {
      final saveDir = await _getSaveDir();
      final vodDir = Directory('$saveDir/${task.vodId}');
      if (!await vodDir.exists()) {
        await vodDir.create(recursive: true);
      }
      // m3u8分片下载
      if (task.isM3U8) {
        final episodeDir = Directory('${vodDir.path}/${task.episode}');
        if (!await episodeDir.exists()) {
          await episodeDir.create(recursive: true);
        }
        print('[M3U8] 下载m3u8内容: ' + task.url);
        // 递归解析ts分片和最终m3u8内容
        final result = await _resolveTsUrlsWithContent(task.url, referer: task.referer);
        final tsUrls = result['tsUrls'] as List<String>;
        String finalM3u8Content = result['m3u8Content'] as String;
        print('[M3U8] 解析到分片数: ' + tsUrls.length.toString());
        task.totalSegments = tsUrls.length;
        task.completedSegments = 0;
        task.fileSize = 0;
        task.speed = 0;
        task.totalFileSize = 0;
        notifyListeners();
        final int maxConcurrent = 8;
        int nextIndex = 0;
        int completed = 0;
        int failed = 0;
        bool hasError = false;
        List<Future> futures = [];
        int lastFileSize = 0;
        DateTime lastTime = DateTime.now();
        void updateSpeed() {
          final now = DateTime.now();
          final diff = now.difference(lastTime).inMilliseconds;
          if (diff > 0) {
            task.speed = ((task.fileSize - lastFileSize) * 1000 / diff).clamp(0, double.infinity);
            lastFileSize = task.fileSize;
            lastTime = now;
            notifyListeners();
          }
        }
        Future<void> startNext() async {
          if (hasError) return;
          if (nextIndex >= tsUrls.length) return;
          final i = nextIndex++;
          final url = tsUrls[i];
          final tsName = url.split('/').last;
          final savePath = '${episodeDir.path}/$tsName';
          print('[M3U8] 下载分片: $url -> $savePath');
          int retry = 0;
          while (retry < 3) {
            try {
              final before = File(savePath).existsSync() ? File(savePath).lengthSync() : 0;
              await dio.download(url, savePath, options: Options(headers: task.referer.isNotEmpty ? {'Referer': task.referer} : null), cancelToken: cancelToken, onReceiveProgress: (received, total) {
                final current = File(savePath).existsSync() ? File(savePath).lengthSync() : 0;
                task.fileSize += (current - before);
                updateSpeed();
                // 平滑速度采样（m3u8分片下载时也采样）
                task.speedSamples.add(task.speed);
                if (task.speedSamples.length > 10) task.speedSamples.removeAt(0);
              });
              break;
            } catch (e) {
              retry++;
              print('[M3U8] 分片下载失败: $url, 第${retry}次, $e');
              if (retry >= 3) {
                failed++;
                hasError = true;
                task.status = 'failed';
                notifyListeners();
                return;
              }
              await Future.delayed(Duration(seconds: 1));
            }
          }
          completed++;
          task.completedSegments = completed;
          task.progress = completed / tsUrls.length;
          notifyListeners();
          await startNext();
        }
        for (int i = 0; i < maxConcurrent && i < tsUrls.length; i++) {
          futures.add(startNext());
        }
        await Future.wait(futures);
        if (!hasError && completed == tsUrls.length) {
          // 处理m3u8内容，替换ts分片行为本地文件名
          final lines = finalM3u8Content.split('\n');
          final newLines = lines.map((line) {
            line = line.trim();
            if (line.isNotEmpty && line.endsWith('.ts')) {
              return line.split('/').last;
            }
            return line;
          }).toList();
          final m3u8Path = '${episodeDir.path}/index.m3u8';
          print('[M3U8] 保存m3u8为: $m3u8Path');
          await File(m3u8Path).writeAsString(newLines.join('\n'));
          task.status = 'completed';
          task.progress = 1.0;
          task.savePath = episodeDir.path;
          notifyListeners();
        } else if (hasError) {
          task.status = 'failed';
          notifyListeners();
        }
        _cancelTokens.remove(key);
        return;
      }
      // 普通视频下载
      final ext = task.forceFormat.isNotEmpty ? '.${task.forceFormat}' : '';
      final fileName = '${task.episode}$ext'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savePath = '${vodDir.path}/$fileName';
      task.savePath = savePath;
      File file = File(savePath);
      int downloaded = 0;
      if (resume && await file.exists()) {
        downloaded = await file.length();
      }
      // 新增：获取总文件大小
      if (task.totalFileSize == 0) {
        try {
          final headResp = await dio.head(task.url, options: Options(headers: task.referer.isNotEmpty ? {'Referer': task.referer} : null));
          final contentLength = headResp.headers['content-length']?.first;
          if (contentLength != null) {
            task.totalFileSize = int.tryParse(contentLength) ?? 0;
          }
        } catch (e) {
          task.totalFileSize = 0;
        }
        notifyListeners();
      }
      int lastReceived = 0;
      DateTime lastTime = DateTime.now();
      final response = await dio.download(
        task.url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            task.progress = (received + downloaded) / (total + downloaded);
            task.fileSize = received + downloaded;
            final now = DateTime.now();
            final diff = now.difference(lastTime).inMilliseconds;
            if (diff > 0) {
              task.speed = ((received - lastReceived) * 1000 / diff).clamp(0, double.infinity);
              lastReceived = received;
              lastTime = now;
              // 平滑速度采样
              task.speedSamples.add(task.speed);
              if (task.speedSamples.length > 10) task.speedSamples.removeAt(0);
            }
            notifyListeners();
          }
        },
        options: Options(
          headers: task.referer.isNotEmpty ? {'Referer': task.referer} : null,
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 10),
        ),
        cancelToken: cancelToken,
        deleteOnError: false,
      );
      if (response.statusCode == 200 || response.statusCode == 206) {
        task.progress = 1.0;
        task.status = 'completed';
        notifyListeners();
      } else {
        task.status = 'failed';
        notifyListeners();
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        task.status = 'paused';
      } else {
        task.status = 'failed';
      }
      notifyListeners();
    } catch (e) {
      task.status = 'failed';
      notifyListeners();
    } finally {
      _cancelTokens.remove(key);
    }
  }

  Future<List<String>> _parseM3U8(String url, {String? referer}) async {
    final dio = Dio();
    final response = await dio.get(url, options: Options(headers: referer != null && referer.isNotEmpty ? {'Referer': referer} : null));
    final lines = response.data.toString().split('\n');
    return lines.where((line) => line.trim().isNotEmpty && line.trim().endsWith('.ts')).map((ts) {
      ts = ts.trim();
      if (ts.startsWith('http')) return ts;
      final baseUrl = url.substring(0, url.lastIndexOf('/') + 1);
      return '$baseUrl$ts';
    }).toList();
  }

  // 递归解析m3u8，返回最终ts分片和原始内容
  Future<Map<String, dynamic>> _resolveTsUrlsWithContent(String m3u8Url, {String? referer}) async {
    final dio = Dio();
    final response = await dio.get(m3u8Url, options: Options(headers: referer != null && referer.isNotEmpty ? {'Referer': referer} : null));
    final content = response.data.toString();
    final lines = content.split('\n').map((l) => l.trim()).toList();
    final tsList = lines.where((l) => l.isNotEmpty && l.endsWith('.ts') && !l.contains('/adjump/')).toList();
    if (tsList.isNotEmpty) {
      // 已经是ts分片
      final tsUrls = tsList.map((ts) {
        if (ts.startsWith('http')) return ts;
        final baseUrl = m3u8Url.substring(0, m3u8Url.lastIndexOf('/') + 1);
        return '$baseUrl$ts';
      }).toList();
      return {'tsUrls': tsUrls, 'm3u8Content': content};
    }
    // 没有ts，查找下一级m3u8
    final subM3u8List = lines.where((l) => l.isNotEmpty && l.endsWith('.m3u8')).toList();
    if (subM3u8List.isNotEmpty) {
      String subUrl = subM3u8List.first;
      if (!subUrl.startsWith('http')) {
        final baseUrl = m3u8Url.substring(0, m3u8Url.lastIndexOf('/') + 1);
        subUrl = '$baseUrl$subUrl';
      }
      return await _resolveTsUrlsWithContent(subUrl, referer: referer);
    }
    return {'tsUrls': <String>[], 'm3u8Content': ''};
  }

  /// 批量删除某个vodId下的所有任务及本地文件
  void removeTasksByVodId(String vodId) {
    final toRemove = _tasks.where((t) => t.vodId == vodId).toList();
    for (var t in toRemove) {
      removeTask(t);
    }
    notifyListeners();
  }
} 