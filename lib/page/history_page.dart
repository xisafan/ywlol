import 'package:flutter/material.dart';
import 'package:flutter/src/material/material_state.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ovofun/page/vedios.dart';
import 'package:ovofun/page/models/color_models.dart';
import 'package:ovofun/services/api/ssl_Management.dart';
// 历史记录页面
class HistoryPage extends StatefulWidget {
  final User user;

  const HistoryPage({Key? key, required this.user}) : super(key: key);

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _isLoading = false;
  String? _errorMessage;
  List<WatchHistoryItem> _historyList = [];
  final ScrollController _scrollController = ScrollController();

  // 多选相关
  bool _isSelecting = false;
  Set<String> _selectedSet = {};

  String _itemKey(WatchHistoryItem item) => '${item.videoId}_${item.episodeIndex}';

  @override
  void initState() {
    super.initState();
    print('当前token: [32m${UserStore().user?.token}[0m');
    if (UserStore().user?.token != null) {
      OvoApiManager().setToken(UserStore().user!.token!);
    }
    _loadHistoryList();
    _fetchCloudHistory();
  }

  Future<void> _loadHistoryList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await UserStore().loadWatchHistory();
      setState(() {
        _historyList = UserStore().watchHistory;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载历史记录失败: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCloudHistory() async {
    try {
      final cloudList = await UserStore().fetchCloudHistory(page: 1, limit: 100);
      setState(() {
        final historyList = cloudList.map((e) => WatchHistoryItem(
          videoId: e['vod_id'].toString(),
          episodeIndex: e['episode_index'] is int
              ? e['episode_index']
              : int.tryParse(e['episode_index']?.toString() ?? '') ?? 0,
          positionSeconds: int.tryParse(e['play_progress']?.toString() ?? '') ?? 0,
          playFrom: e['play_source']?.toString() ?? '',
          timestamp: DateTime.tryParse(e['update_time'] ?? e['create_time'] ?? '') ?? DateTime.now(),
          videoTitle: e['vod_name']?.toString() ?? '',
          videoCover: e['vod_pic']?.toString() ?? '',
        )).toList();
        _historyList = historyList;
        // 同步到本地
        UserStore().saveWatchHistoryList(historyList);
      });
    } catch (e) {
      print('云端历史获取失败: $e');
    }
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清空历史记录'),
        content: Text('确定要清空所有历史记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await UserStore().clearWatchHistory();
        setState(() {
          _historyList.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已清空所有历史记录')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清空失败: ${e.toString()}')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inDays == 0) {
        return '今天 ${DateFormat('HH:mm').format(dateTime)}';
      } else if (difference.inDays == 1) {
        return '昨天 ${DateFormat('HH:mm').format(dateTime)}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}天前';
      } else {
        return DateFormat('yyyy-MM-dd').format(dateTime);
      }
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // appbar 已实现
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: kPrimaryColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
            ),
          ),
        ),
        title: Text('观看历史'),
        actions: [
          if (!_isSelecting && _historyList.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _isSelecting = true;
                  _selectedSet.clear();
                });
              },
              style: TextButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
                overlayColor: Colors.transparent,
              ),
              child: Text('选择', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
            ),
          if (_isSelecting)
            TextButton(
              onPressed: () {
                setState(() {
                  _isSelecting = false;
                  _selectedSet.clear();
                });
              },
              style: TextButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
                overlayColor: Colors.transparent,
              ),
              child: Text('取消', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadHistoryList,
                        child: Text('重试'),
                      ),
                    ],
                  ),
                )
              : _historyList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            '暂无观看历史',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '您观看过的视频将会显示在这里',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistoryList,
                      child: ListView.builder(
                        controller: _scrollController,
                            itemCount: _historyList.length,
                        itemBuilder: (context, index) {
                              final history = _historyList[index];
                              final key = _itemKey(history);
                              final selected = _selectedSet.contains(key);
                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _isSelecting
                                    ? () {
                                        setState(() {
                                          if (selected) {
                                            _selectedSet.remove(key);
                                          } else {
                                            _selectedSet.add(key);
                                          }
                                        });
                          }
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => VideoDetailPage(
                                              vodId: int.tryParse(history.videoId) ?? 0,
                                              initialEpisodeIndex: history.episodeIndex,
                                              initialPlayFrom: history.playFrom,
                                              initialPositionSeconds: history.positionSeconds,
                              ),
                            ),
                                        ).then((_) => _loadHistoryList());
                            },
                                child: Container(
                              margin: EdgeInsets.symmetric(
                                horizontal: 12.0,
                                    vertical: 8.0,
                              ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      if (_isSelecting)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 12.0, right: 4.0),
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                if (selected) {
                                                  _selectedSet.remove(key);
                                                } else {
                                                  _selectedSet.add(key);
                                                }
                                              });
                                            },
                                            child: Container(
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: selected ? kPrimaryColor : Colors.grey[400]!,
                                                  width: 2,
                                                ),
                                                color: selected ? kPrimaryColor : Colors.transparent,
                                              ),
                                              child: selected
                                                  ? Icon(Icons.check, size: 16, color: Colors.white)
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                                        child: SizedBox(
                                          width: 90,
                                          height: 120,
                                          child: Stack(
                                            children: [
                                      ClipRRect(
                                                borderRadius: BorderRadius.circular(10.0),
                                                child: history.videoCover.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: history.videoCover,
                                                        width: 90,
                                                        height: 120,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey[300],
                                                          child: Icon(Icons.image, color: Colors.grey[400]),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: Colors.grey[300],
                                                          child: Icon(Icons.broken_image, color: Colors.grey[400]),
                                                        ),
                                                      )
                                                    : Container(
                                                        color: Colors.grey[300],
                                                        child: Icon(Icons.ondemand_video, color: Colors.grey[500], size: 40),
                                            ),
                                              ),
                                              // 右下角已播放时间，底部渐隐阴影
                                              Positioned(
                                                left: 0,
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.bottomCenter,
                                                      end: Alignment.topCenter,
                                                      colors: [
                                                        Colors.black.withOpacity(0.32),
                                                        Colors.transparent,
                                                      ],
                                                    ),
                                                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                                                  ),
                                                  alignment: Alignment.bottomRight,
                                                  padding: EdgeInsets.only(right: 8, bottom: 4),
                                                  child: Text(
                                                    '已播放${_formatDuration(history.positionSeconds)}',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                                history.videoTitle.isNotEmpty ? history.videoTitle : '视频ID: ${history.videoId}',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                              SizedBox(height: 1),
                                            Text(
                                                '已看到第${history.episodeIndex + 1}集',
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.grey[500],
                                                  fontWeight: FontWeight.w400,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                            ),
                                              SizedBox(height: 35),
                                            Text(
                                                '${_formatDateTime(history.timestamp)}',
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.grey[400],
                                                  fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ),
                                      SizedBox(width: 12),
                                    ],
                                  ),
                                ),
                              );
                            },
                            ),
                        ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              offset: _isSelecting && _historyList.isNotEmpty ? Offset(0, 0) : Offset(0, 1),
              duration: Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: _isSelecting && _historyList.isNotEmpty ? 1.0 : 0.0,
                duration: Duration(milliseconds: 150),
                child: (_isSelecting && _historyList.isNotEmpty)
                    ? Container(
                        margin: EdgeInsets.all(12),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // 全选/取消全选
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                foregroundColor: Colors.white,
                                shape: StadiumBorder(),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: Icon(_selectedSet.length == _historyList.length ? Icons.check_box : Icons.check_box_outline_blank),
                              label: Text(_selectedSet.length == _historyList.length ? '取消全选' : '全选'),
                              onPressed: () {
                                setState(() {
                                  if (_selectedSet.length == _historyList.length) {
                                    _selectedSet.clear();
                                  } else {
                                    _selectedSet = _historyList.map(_itemKey).toSet();
                                  }
                                });
                        },
                      ),
                            // 删除选中
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: StadiumBorder(),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: Icon(Icons.delete),
                              label: Text('删除选中'),
                              onPressed: _selectedSet.isEmpty
                                  ? null
                                  : () async {
                                      final isAll = _selectedSet.length == _historyList.length;
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('删除历史记录'),
                                          content: Text(isAll ? '确定要删除全部历史记录吗？' : '确定要删除选中的历史记录吗？'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: Text('取消'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: Text('确定'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        if (isAll) {
                                          await UserStore().deleteAllCloudHistory();
                                          setState(() {
                                            _historyList.clear();
                                            _selectedSet.clear();
                                            _isSelecting = false;
                                          });
                                        } else {
                                          for (final key in _selectedSet) {
                                            final parts = key.split('_');
                                            final videoId = parts[0];
                                            await UserStore().deleteCloudHistoryItem(videoId);
                                          }
                                          await _loadHistoryList();
                                          setState(() {
                                            _selectedSet.clear();
                                            _isSelecting = false;
                                          });
                                        }
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('删除成功')),
                                        );
                                      }
                                    },
                            ),
                            // 删除全部
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                shape: StadiumBorder(),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: Icon(Icons.delete_sweep),
                              label: Text('删除全部'),
                              onPressed: _historyList.isEmpty
                                  ? null
                                  : () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('删除全部历史记录'),
                                          content: Text('确定要删除全部历史记录吗？'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: Text('取消'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: Text('确定'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await UserStore().deleteAllCloudHistory();
                                        setState(() {
                                          _historyList.clear();
                                          _selectedSet.clear();
                                          _isSelecting = false;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('已删除全部历史记录')),
                                        );
                                      }
                                    },
                            ),
                          ],
                        ),
                      )
                    : SizedBox.shrink(),
              ),
            ),
          ),
        ],
                    ),
    );
  }
}
