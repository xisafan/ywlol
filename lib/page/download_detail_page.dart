import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/download_manager.dart';
import 'download_page.dart';
import 'package:open_file/open_file.dart';

class DownloadDetailPage extends StatelessWidget {
  final String vodId;
  final String vodName;
  final String vodPic;
  const DownloadDetailPage({Key? key, required this.vodId, required this.vodName, required this.vodPic}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final allTasks = DownloadManager().tasks.where((t) => t.vodId == vodId).toList();
    final downloading = allTasks.where((t) => t.status == 'downloading' || t.status == 'paused' || t.status == 'waiting').toList();
    final completed = allTasks.where((t) => t.status == 'completed').toList();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('剧集管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: () {
              // 删除该vodId下所有任务
              for (var t in allTasks) {
                DownloadManager().removeTask(t);
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: vodPic,
                    width: 60,
                    height: 90,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => Icon(Icons.broken_image, size: 60),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    vodName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey[300]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text('下载中', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          downloading.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      '暂无下载中的内容',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ),
                )
              : Column(
                  children: downloading.map((task) => _buildDownloadingItem(context, task)).toList(),
                ),
          if (downloading.isNotEmpty) Divider(color: Colors.grey[300]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text('已完成', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          completed.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      '暂无已完成的内容',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ),
                )
              : Column(
                  children: completed.map((task) => _buildCompletedItem(context, task)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildDownloadingItem(BuildContext context, DownloadTask task) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
          child: Row(
            children: [
              Text('${task.episode}', style: TextStyle(fontSize: 15)),
              SizedBox(width: 10),
              Expanded(
                child: LinearProgressIndicator(
                  value: task.progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                ),
              ),
              SizedBox(width: 10),
              Text(
                task.status == 'waiting' ? '等待中' : '${(task.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 13),
              ),
              IconButton(
                icon: Icon(task.status == 'paused' ? Icons.play_arrow : Icons.pause),
                onPressed: () {
                  if (task.status == 'paused') {
                    DownloadManager().resumeTask(task);
                  } else {
                    DownloadManager().pauseTask(task);
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.cancel, color: Colors.red),
                onPressed: () {
                  DownloadManager().removeTask(task);
                },
              ),
            ],
          ),
        ),
        Divider(color: Colors.grey[200], height: 1),
      ],
    );
  }

  Widget _buildCompletedItem(BuildContext context, DownloadTask task) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
          child: Row(
            children: [
              Text('${task.episode}', style: TextStyle(fontSize: 15)),
              Spacer(),
              IconButton(
                icon: Icon(Icons.play_circle_fill, color: Colors.blue),
                onPressed: () {
                  if (task.savePath.isNotEmpty) {
                    OpenFile.open(task.savePath);
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  DownloadManager().removeTask(task);
                },
              ),
            ],
          ),
        ),
        Divider(color: Colors.grey[200], height: 1),
      ],
    );
  }
} 