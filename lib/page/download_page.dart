import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/download_manager.dart';
import 'download_detail_page.dart';
import 'models/color_models.dart'; // 用于kPrimaryColor等
import 'dart:io';

class DownloadTask {
  final String vodId;
  final String vodName;
  final String vodPic;
  final String url;
  final String referer;
  final String episode;
  final String forceFormat;
  double progress; // 0~1
  String status; // downloading, paused, completed, failed
  String savePath;
  final bool isM3U8;
  int totalSegments;
  int completedSegments;
  double speed; // 下载速度，单位B/s
  int fileSize; // 已下载文件大小，单位B/s
  List<double> speedSamples; // 速度采样
  int totalFileSize; // 总文件大小，单位B/s

  DownloadTask({
    required this.vodId,
    required this.vodName,
    required this.vodPic,
    required this.url,
    required this.referer,
    required this.episode,
    required this.forceFormat,
    this.progress = 0,
    this.status = 'downloading',
    this.savePath = '',
    this.isM3U8 = false,
    this.totalSegments = 0,
    this.completedSegments = 0,
    this.speed = 0,
    this.fileSize = 0,
    this.totalFileSize = 0,
    List<double>? speedSamples,
  }) : speedSamples = speedSamples ?? [];

  // 获取平滑速度（滑动平均，取最近10次）
  double getSmoothSpeed() {
    if (speedSamples.isEmpty) return speed;
    int n = speedSamples.length > 10 ? 10 : speedSamples.length;
    return speedSamples.sublist(speedSamples.length - n).reduce((a, b) => a + b) / n;
  }
}

class DownloadPage extends StatefulWidget {
  const DownloadPage({Key? key}) : super(key: key);

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  bool _editMode = false; // 新增：编辑模式
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DownloadManager(),
      builder: (context, _) {
        final allTasks = DownloadManager().tasks;
        // 正在下载的任务（只取第一个vod_id）
        final downloadingTasks = allTasks.where((t) => t.status == 'downloading' || t.status == 'paused' || t.status == 'waiting').toList();
        DownloadTask? downloadingTask;
        if (downloadingTasks.isNotEmpty) {
          downloadingTask = downloadingTasks.first;
        }
        // 已缓存番剧（每个vod_id只保留已完成的第一个任务）
        final completedTasks = allTasks.where((t) => t.status == 'completed').toList();
        final Map<String, List<DownloadTask>> completedByVod = {};
        for (var t in completedTasks) {
          completedByVod.putIfAbsent(t.vodId, () => []).add(t);
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text('下载管理'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(_editMode ? Icons.check : Icons.edit),
                onPressed: () {
                  setState(() {
                    _editMode = !_editMode;
                  });
                },
              ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              // 第一行：正在缓存
              if (downloadingTask != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Row(
                    children: [
                      Text('正在缓存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Spacer(),
                      Icon(Icons.chevron_right, color: Colors.grey[500]),
                    ],
                  ),
                ),
              // 正在下载块
              if (downloadingTask != null)
                _buildDownloadingBlock(context, downloadingTask, edit: _editMode),
              if (downloadingTask != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Divider(color: Colors.grey[300], height: 1),
                ),
              // 已缓存番剧标题
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Text('已缓存番剧', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              // 已缓存番剧块
              ...completedByVod.entries.map((entry) {
                final vodId = entry.key;
                final tasks = entry.value;
                final firstTask = tasks.first;
                return _buildCompletedBlock(context, firstTask, tasks.length, edit: _editMode);
              }).toList(),
              if (downloadingTask == null && completedByVod.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(child: Text('暂无下载任务', style: TextStyle(color: Colors.grey))),
                ),
            ],
          ),
        );
      },
    );
  }

  // 正在下载的块
  Widget _buildDownloadingBlock(BuildContext context, DownloadTask task, {bool edit = false}) {
    // 速度、文件大小用真实数据
    String speed = task.getSmoothSpeed() > 0 ? _formatSpeed(task.getSmoothSpeed()) : '--';
    String fileSize;
    if (task.isM3U8 || task.totalFileSize == 0) {
      fileSize = _formatFileSize(task.fileSize);
    } else {
      fileSize = '${_formatFileSize(task.fileSize)}/${_formatFileSize(task.totalFileSize)}';
    }
    int downloadingCount = DownloadManager().tasks.where((t) => t.status == 'downloading' || t.status == 'paused' || t.status == 'waiting').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 70,
            height: 110,
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 图片
                    CachedNetworkImage(
                      imageUrl: task.vodPic,
                      fit: BoxFit.cover,
                    ),
                    // 高斯模糊
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(color: Colors.transparent),
                    ),
                    // 居中白字
                    Center(
                      child: Text(
                        '$downloadingCount个内容',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          // 右侧信息和操作按钮
          Expanded(
            child: Row(
              children: [
                // 信息区始终不动
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // vod_name
                        Text(
                          task.vodName,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        // 剧集
                        Text(
                          task.episode,
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        // 速度+文件大小
                        Row(
                          children: [
                            Text(speed, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                            Spacer(),
                            Text(fileSize, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                          ],
                        ),
                        SizedBox(height: 8),
                        // 进度条
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: task.progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 编辑模式下右侧操作，动画滑入
                AnimatedSlide(
                  offset: edit ? Offset(0, 0) : Offset(1.2, 0),
                  duration: Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 1,
                        height: 48,
                        color: Colors.grey[300],
                        margin: EdgeInsets.symmetric(horizontal: 4),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(task.status == 'paused' ? Icons.play_arrow : Icons.pause),
                            tooltip: task.status == 'paused' ? '继续' : '暂停',
                            onPressed: () {
                              if (task.status == 'paused') {
                                DownloadManager().resumeTask(task);
                              } else {
                                DownloadManager().pauseTask(task);
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.cancel),
                            tooltip: '取消任务',
                            onPressed: () {
                              DownloadManager().removeTask(task);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 灰色叠加块
  Widget _buildGrayBox(double scale) {
    return Container(
      width: 70 * scale,
      height: 110 * scale,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(18 * scale),
      ),
    );
  }

  // 已缓存番剧块
  Widget _buildCompletedBlock(BuildContext context, DownloadTask task, int count, {bool edit = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Stack(
            children: [
              // 图片
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 70,
                  height: 110,
                  child: CachedNetworkImage(
                    imageUrl: task.vodPic,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // 点击区域
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      if (!edit) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DownloadDetailPage(
                              vodId: task.vodId,
                              vodName: task.vodName,
                              vodPic: task.vodPic,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12),
          // 右侧信息和操作按钮
          Expanded(
            child: Row(
              children: [
                // 标题和副标题信息，始终左对齐且不溢出
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        task.vodName,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        _getVodTotalSizeText(task.vodId),
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 24),
                      Text(
                        '共$count集',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 编辑模式下右侧操作，动画滑入
                AnimatedSlide(
                  offset: edit ? Offset(0, 0) : Offset(1.2, 0),
                  duration: Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.grey[300],
                        margin: EdgeInsets.symmetric(horizontal: 4),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        tooltip: '删除该番剧所有视频',
                        onPressed: () {
                          DownloadManager().removeTasksByVodId(task.vodId);
                        },
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 格式化速度
  String _formatSpeed(double speed) {
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / 1024 / 1024).toStringAsFixed(2)} MB/s';
  }

  // 格式化文件大小
  String _formatFileSize(int size) {
    if (size < 1024) return '${size} B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / 1024 / 1024).toStringAsFixed(2)} MB';
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  // 新增：统计某vod_id下所有下载任务的本地文件总大小
  String _getVodTotalSizeText(String vodId) {
    final tasks = DownloadManager().tasks.where((t) => t.vodId == vodId && t.status == 'completed').toList();
    int total = 0;
    for (var t in tasks) {
      if (t.savePath.isNotEmpty) {
        final file = File(t.savePath);
        final dir = Directory(t.savePath);
        try {
          if (t.isM3U8) {
            if (dir.existsSync()) {
              total += dir.listSync(recursive: true).whereType<File>().fold(0, (sum, f) => sum + f.lengthSync());
            }
          } else {
            if (file.existsSync()) {
              total += file.lengthSync();
            }
          }
        } catch (e) {}
      }
    }
    return '总计: ' + _formatFileSize(total);
  }
}

// 静态方法：通过vod_id获取所有已下载集数和本地路径
class DownloadHelper {
  static List<Map<String, String>> getDownloadedEpisodesByVodId(String vodId) {
    final tasks = DownloadManager().tasks
        .where((t) => t.vodId == vodId && t.status == 'completed')
        .toList();
    return tasks.map((t) => {
      'episode': t.episode,
      'localPath': t.savePath,
    }).toList();
  }
}
