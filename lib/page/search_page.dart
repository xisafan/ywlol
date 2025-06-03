import 'package:flutter/material.dart';
import 'package:ovofun/models/hotvedio_model.dart';
import 'package:ovofun/services/api/ssl_Management.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ovofun/page/vedios.dart'; // 导入视频详情页
import 'package:ovofun/page/models/color_models.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final OvoApiManager _apiManager = OvoApiManager();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 搜索视频
  Future<void> _searchVideos(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _errorMessage = '请输入搜索关键词';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _hasSearched = true;
      });

      // 使用OvoApiManager搜索视频
      final dynamic searchResult = await _apiManager.searchVideos(keyword);
      print('搜索结果: $searchResult');

      // 直接使用原始数据，不进行模型转换
      List<dynamic> videos = [];

      if (searchResult is Map<String, dynamic>) {
        if (searchResult.containsKey('list') && searchResult['list'] is List) {
          videos = searchResult['list'] as List<dynamic>;
        }
      } else if (searchResult is List) {
        videos = searchResult;
      }

      print('搜索结果数量: ${videos.length}');

      setState(() {
        _searchResults = videos;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('搜索视频失败: $e');
      print('堆栈跟踪: $stackTrace');
      setState(() {
        _errorMessage = '搜索视频失败: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 移除AppBar，仅首页显示导航栏
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            // 自定义顶部导航区域
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // 返回按钮
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  // 搜索框
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '搜索视频',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            _searchVideos(_searchController.text);
                          },
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        _searchVideos(value);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 内容区域
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _searchVideos(_searchController.text),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Text('请输入关键词搜索视频'),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('未找到相关视频'),
      );
    }

    // 使用ListView以一行一条的方式显示搜索结果
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final video = _searchResults[index];

        // 直接从原始数据中获取字段
        final String vodName = video['vod_name'] ?? '未知标题';
        final String vodRemarks = video['vod_remarks'] ?? '';

        // 确保URL已正确解码
        String imageUrl = '';
        if (video['vod_pic'] != null) {
          imageUrl = Uri.decodeFull(video['vod_pic'].toString().replaceAll(r'\/', '/'));
        }

        return GestureDetector(
          onTap: () {
            // 处理视频点击事件，跳转到视频详情页
            print('点击了视频ID: ${video['vod_id']}');

            // 修复：将vod_id从String转换为int
            int vodId;
            try {
              // 尝试将vod_id转换为整数
              vodId = int.parse(video['vod_id'].toString());

              // 跳转到视频详情页
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoDetailPage(vodId: vodId),
                ),
              );
            } catch (e) {
              // 转换失败时显示错误提示
              print('视频ID转换失败: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('无法打开视频: ID格式错误'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 视频封面
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: 120,
                      height: 80,
                      placeholder: (context, url) => Container(
                        color: Colors.black12,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        print('图片加载错误: $error, URL: $url');
                        return Container(
                          color: Colors.grey[300],
                          width: 120,
                          height: 80,
                          child: const Center(
                            child: Icon(Icons.error, color: Colors.red),
                          ),
                        );
                      },
                    )
                        : Container(
                      color: Colors.grey[300],
                      width: 120,
                      height: 80,
                      child: const Center(
                        child: Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    ),
                  ),

                  // 视频信息
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 视频标题
                        Text(
                          vodName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 视频备注
                        if (vodRemarks.isNotEmpty)
                          Text(
                            vodRemarks,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
