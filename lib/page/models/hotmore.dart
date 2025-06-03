import 'package:flutter/material.dart';
import 'package:ovofun/models/hotvedio_model.dart';
import 'package:ovofun/services/api/ssl_Management.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HotMorePage extends StatefulWidget {
  const HotMorePage({Key? key}) : super(key: key);

  @override
  _HotMorePageState createState() => _HotMorePageState();
}

class _HotMorePageState extends State<HotMorePage> {
  final OvoApiManager _apiManager = OvoApiManager();
  List<HotVedioModel> _hotVedios = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHotVedios();
  }

  /// 获取热播视频数据
  Future<void> _fetchHotVedios() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 使用OvoApiManager获取热播视频数据 - 无参数调用
      final dynamic hotVediosData = await _apiManager.getHotVedios();
      print('获取到的热播视频数据: $hotVediosData');
      
      // 将API返回的数据转换为HotVedioModel列表
      final List<HotVedioModel> hotVedios = [];
      
      if (hotVediosData is List) {
        for (var item in hotVediosData) {
          if (item is Map<String, dynamic>) {
            hotVedios.add(HotVedioModel.fromJson(item));
          }
        }
      } else if (hotVediosData is Map<String, dynamic>) {
        // 如果返回的是单个对象，也尝试解析
        if (hotVediosData.containsKey('list') && hotVediosData['list'] is List) {
          for (var item in hotVediosData['list']) {
            if (item is Map<String, dynamic>) {
              hotVedios.add(HotVedioModel.fromJson(item));
            }
          }
        } else {
          // 尝试直接解析单个对象
          hotVedios.add(HotVedioModel.fromJson(hotVediosData));
        }
      }
      
      print('解析后的热播视频数量: ${hotVedios.length}');
      
      setState(() {
        _hotVedios = hotVedios;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('获取热播视频数据失败: $e');
      print('堆栈跟踪: $stackTrace');
      setState(() {
        _errorMessage = '获取热播视频数据失败: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('热播推荐'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHotVedios,
        child: _buildBody(),
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
              onPressed: _fetchHotVedios,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_hotVedios.isEmpty) {
      return const Center(
        child: Text('暂无热播视频数据'),
      );
    }

    // 使用GridView以一行三个的方式显示热播视频
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 一行三个
        childAspectRatio: 0.7, // 宽高比
        crossAxisSpacing: 10, // 水平间距
        mainAxisSpacing: 10, // 垂直间距
      ),
      itemCount: _hotVedios.length,
      itemBuilder: (context, index) {
        final hotVedio = _hotVedios[index];
        
        // 确保URL已正确解码
        final String imageUrl = Uri.decodeFull(hotVedio.vodPic.replaceAll(r'\/', '/'));
        
        return GestureDetector(
          onTap: () {
            // 处理视频点击事件，可以跳转到视频详情页
            print('点击了视频ID: ${hotVedio.vodId}');
            // Navigator.push(context, MaterialPageRoute(builder: (context) => VideoDetailPage(vodId: hotVedio.vodId)));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 视频封面
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 视频图片
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.black12,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          print('图片加载错误: $error');
                          return Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.error, color: Colors.red),
                            ),
                          );
                        },
                      ),
                      
                      // 备注信息（右上角）
                      if (hotVedio.vodRemarks.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            padding: EdgeInsets.only(left: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.grey.withOpacity(0.6),
                                ],
                              ),
                            ),
                            child: Text(
                              hotVedio.vodRemarks,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // 视频标题
              const SizedBox(height: 5),
              Text(
                hotVedio.vodName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
