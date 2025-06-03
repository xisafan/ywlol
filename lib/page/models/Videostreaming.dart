import 'package:flutter/material.dart';
import 'package:ovofun/page/vedios.dart';
import 'package:ovofun/services/api/ssl_Management.dart';
import 'dart:math';

class VideoStreaming extends StatefulWidget {
  final int? currentVideoId; // 当前视频ID，可选
  final int? typeId; // 视频类型ID，可选1

  const VideoStreaming({
    Key? key,
    this.currentVideoId,
    this.typeId,
  }) : super(key: key);

  @override
  _VideoStreamingState createState() => _VideoStreamingState();
}

class _VideoStreamingState extends State<VideoStreaming> {
  final OvoApiManager _apiManager = OvoApiManager();

  List<dynamic> _videoList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRelatedVideos();
  }

  /// 获取相关视频列表
  Future<void> _fetchRelatedVideos() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 如果已提供typeId，直接使用
      int? typeId = widget.typeId;

      // 如果未提供typeId但提供了currentVideoId，先获取当前视频详情以获取typeId
      if (typeId == null && widget.currentVideoId != null) {
        final videoDetail = await _apiManager.getVideoDetail(widget.currentVideoId!);
        if (videoDetail is Map<String, dynamic> && videoDetail.containsKey('type_id')) {
          typeId = int.tryParse(videoDetail['type_id'].toString());
        }
      }

      // 使用typeId获取同类型视频
      dynamic result;
      typeId ??= 20; // 如果typeId仍然为null，设置为0
      result = await _apiManager.getVideosByType(typeId: typeId);

      if (result is Map<String, dynamic> && result.containsKey('list') && result['list'] is List) {
        List<dynamic> allVideos = result['list'] as List<dynamic>;

        // 如果当前视频ID存在，从列表中排除
        if (widget.currentVideoId != null) {
          allVideos = allVideos.where((video) {
            final videoId = int.tryParse(video['vod_id'].toString());
            return videoId != widget.currentVideoId;
          }).toList();
        }

        // 如果视频总数超过9个，随机选择9个
        if (allVideos.length > 9) {
          // 创建一个随机数生成器
          final random = Random();

          // 随机选择9个不重复的视频
          final List<dynamic> randomVideos = [];
          final Set<int> selectedIndices = {};

          while (randomVideos.length < 9 && selectedIndices.length < allVideos.length) {
            int randomIndex = random.nextInt(allVideos.length);
            if (!selectedIndices.contains(randomIndex)) {
              selectedIndices.add(randomIndex);
              randomVideos.add(allVideos[randomIndex]);
            }
          }

          setState(() {
            _videoList = randomVideos;
            _isLoading = false;
          });
        } else {
          // 如果视频总数不足9个，全部显示
          setState(() {
            _videoList = allVideos;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = '获取视频列表失败: 数据格式错误';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('获取视频列表失败: $e');
      setState(() {
        _errorMessage = '获取视频列表失败: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.pink),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchRelatedVideos,
              child: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
              ),
            ),
          ],
        ),
      );
    }

    if (_videoList.isEmpty) {
      return const Center(
        child: Text('暂无相关视频', style: TextStyle(color: Colors.black87)),
      );
    }

    // 计算每个视频卡片的宽度（屏幕宽度减去边距和间距，然后除以3）
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 32 - 16) / 3; // 32是左右边距，16是两个间距的总和

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        // 禁用滚动，因为这个GridView会嵌入到另一个可滚动的视图中
        physics: NeverScrollableScrollPhysics(),
        // 设置为固定高度，只显示9个视频
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.7,
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
        ),
        itemCount: _videoList.length > 6 ? 6 : _videoList.length, // 最多显示9个
        itemBuilder: (context, index) {
          final video = _videoList[index];
          final String vodName = video['vod_name'] ?? '未知标题';
          final String vodRemarks = video['vod_remarks'] ?? '';
          String imageUrl = '';
          if (video['vod_pic'] != null) {
            imageUrl = Uri.decodeFull(video['vod_pic'].toString().replaceAll(r'\/', '/'));
          }
          return GestureDetector(
            onTap: () {
              if (video['vod_id'] != null) {
                try {
                  final int videoId = int.parse(video['vod_id'].toString());
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoDetailPage(vodId: videoId),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('无法打开视频: ID格式错误'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Stack(
                      children: [
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
                            ),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.black12,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                        ),
                        if (vodRemarks.isNotEmpty)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.5),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Text(
                                vodRemarks,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    vodName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (video['vod_actor'] != null && video['vod_actor'].toString().isNotEmpty)
                  Text(
                    video['vod_actor'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: Colors.grey[600],
                    ),
                  )
                else if (video['vod_tag'] != null && video['vod_tag'].toString().isNotEmpty)
                  Text(
                    video['vod_tag'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
