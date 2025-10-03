import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ovofun/services/api/ssl_Management.dart';
import 'package:ovofun/page/vedios.dart'; // 导入视频详情页面
//import 'package:ovofun/page/models/color_models.dart';
import 'package:ovofun/models/user_model.dart';
import 'package:ovofun/models/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:ovofun/widgets/back_to_top_button.dart';

// 支持扩展分1
class ClassifyModule extends StatefulWidget {
  final String title;
  final int typeId;
  final Function(int) onItemTap;
  final Function() onMoreTap;
  final bool showTitle;
  final bool showAllItems;

  const ClassifyModule({
    Key? key,
    required this.title,
    required this.typeId,
    required this.onItemTap,
    required this.onMoreTap,
    this.showTitle = true,
    this.showAllItems = false,
  }) : super(key: key);

  @override
  _ClassifyModuleState createState() => _ClassifyModuleState();
}

class _ClassifyModuleState extends State<ClassifyModule> {
  final OvoApiManager _apiManager = OvoApiManager();
  List<dynamic> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 🚀 新增：标记是否已经初始化过数据，避免频繁刷新
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // 🚀 延迟初始化，确保组件完全构建后再加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasInitialized && mounted) {
        _initializeData();
      }
    });
  }

  // 🚀 新增：初始化数据方法，只在首次加载时调用
  Future<void> _initializeData() async {
    if (_hasInitialized) return;

    print('🚀 ClassifyModule[${widget.typeId}] 首次初始化数据');
    _hasInitialized = true;
    await _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final result = await _apiManager.getVideosByType(
        typeId: widget.typeId,
        page: 1,
        limit: widget.showAllItems ? 30 : 6, // 如果显示所有项目，则获取更多数据
      );

      if (mounted) {
        setState(() {
          if (result.containsKey('list') && result['list'] is List) {
            _videos = result['list'];
          } else {
            _videos = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('获取分类视频失败: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '获取分类视频失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  // 🚀 修改：下拉刷新方法，强制重新获取数据
  Future<void> _refresh() async {
    print('🚀 ClassifyModule[${widget.typeId}] 用户主动下拉刷新');
    // 🚀 清空数据并重新获取
    _videos.clear();
    await _fetchVideos();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder:
          (context, themeNotifier, child) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏 - 如果不显示标题则跳过
              if (widget.showTitle)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Stack(
                        children: <Widget>[
                          Positioned(
                            left: 0.0,
                            top: 0.0,
                            bottom: 1.4,
                            width: 25.0, // 从35.7减少到18.0，只覆盖1个字
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    themeNotifier.primaryColor.withOpacity(
                                      0.58,
                                    ),
                                    themeNotifier.primaryColor.withOpacity(0.0),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              4.0,
                              0.6,
                              0.0,
                              0.0,
                            ),
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                fontFamily: 'FZLanTingHeiS-EB-GB',
                                fontSize: 13,
                                color: Color(0xff000000),
                              ),
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: widget.onMoreTap,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(1.0),
                              decoration: BoxDecoration(
                                color: themeNotifier.primaryColor, // 使用主题色
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // 内容区域
              _buildContent(),
            ],
          ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            color: Color(0xFF00B0F0), // 使用应用主色调
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B0F0), // 使用应用主色调
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return const SizedBox.shrink(); // 没有数据时不占用空间
    }

    // 计算要显示的行数
    final int itemsPerRow = 3;
    final int rowCount =
        widget.showAllItems
            ? (_videos.length / itemsPerRow).ceil()
            : (_videos.length / itemsPerRow).ceil() > 2
            ? 2
            : (_videos.length / itemsPerRow).ceil();
    final int itemsToShow =
        widget.showAllItems
            ? _videos.length
            : rowCount * itemsPerRow > _videos.length
            ? _videos.length
            : rowCount * itemsPerRow;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2 / 3, // Adjust aspect ratio for the new style
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 12.0,
      ),
      itemCount: itemsToShow,
      itemBuilder: (context, index) {
        final video = _videos[index];
        final String imageUrl = Uri.decodeFull(
          video['vod_pic'].toString().replaceAll(r'\/', '/'),
        );

        return GestureDetector(
          onTap: () {
            final int vodId =
                video['vod_id'] is int
                    ? video['vod_id']
                    : int.tryParse(video['vod_id'].toString()) ?? 0;
            widget.onItemTap(vodId);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 视频封面
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11.0),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) =>
                                Container(color: Colors.grey[200]),
                        errorWidget:
                            (context, url, error) =>
                                Container(color: Colors.grey[200]),
                      ),
                    ),
                    if (video['vod_remarks'] != null &&
                        video['vod_remarks'].toString().isNotEmpty)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(11.0),
                              bottomRight: Radius.circular(11.0),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.75),
                                Colors.black.withOpacity(0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Text(
                            '${video['vod_remarks']}',
                            style: const TextStyle(
                              fontFamily: 'FZHei-B01S',
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  blurRadius: 1.0,
                                  color: Colors.black45,
                                  offset: Offset(0.5, 0.5),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 视频标题 - 居中显示
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  video['vod_name'] ?? '未知标题',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'FZHei-B01S',
                    fontSize: 12,
                    color: Color(0xff000000),
                  ),
                ),
              ),

              // 视频副标题（演员或标签）- 居中显示
              if (video['vod_actor'] != null &&
                  video['vod_actor'].toString().isNotEmpty)
                Text(
                  video['vod_actor'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
                )
              else if (video['vod_tag'] != null &&
                  video['vod_tag'].toString().isNotEmpty)
                Text(
                  video['vod_tag'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
                ),
            ],
          ),
        );
      },
    );
  }
}

// 分类更多页面
class ClassifyMorePage extends StatefulWidget {
  final int typeId;
  final String title;

  const ClassifyMorePage({Key? key, required this.typeId, required this.title})
    : super(key: key);

  @override
  _ClassifyMorePageState createState() => _ClassifyMorePageState();
}

class _ClassifyMorePageState extends State<ClassifyMorePage> {
  final OvoApiManager _apiManager = OvoApiManager();
  List<dynamic> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  // 扩展分类相关
  Map<String, List<String>> _extendOptions = {};
  String _selectedArea = '全部';
  String _selectedLang = '全部';
  String _selectedYear = '全部';

  @override
  void initState() {
    super.initState();
    _fetchExtends();
    _fetchVideos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchExtends() async {
    try {
      Map<String, dynamic>? res = await UserStore.getExtends(widget.typeId);
      if (res == null) {
        final apiRes = await _apiManager.get(
          '/v1/vod_extends',
          queryParameters: {'type_id': widget.typeId},
        );
        if (apiRes is Map) {
          res = Map<String, dynamic>.from(apiRes);
          await UserStore.saveExtends(widget.typeId, res);
        }
      }
      if (res != null) {
        res = Map<String, dynamic>.from(res);
        // 处理area排序：中国优先，其次其他，全部始终第一
        List<String> areaList =
            (res['area'] as List?)?.map((e) => e.toString()).toList() ?? [];
        areaList.removeWhere((e) => e == '全部');
        if (areaList.contains('中国')) {
          areaList.remove('中国');
          areaList = ['全部', '中国', ...areaList];
        } else {
          areaList = ['全部', ...areaList];
        }
        // 年份从大到小排序
        List<String> yearList =
            (res['year'] as List?)?.map((e) => e.toString()).toList() ?? [];
        yearList.sort((a, b) {
          int? ay = int.tryParse(a);
          int? by = int.tryParse(b);
          if (ay != null && by != null) return by.compareTo(ay);
          return b.compareTo(a);
        });
        // 语言原样
        List<String> langList =
            (res['lang'] as List?)?.map((e) => e.toString()).toList() ?? [];
        _extendOptions = {'area': areaList, 'lang': langList, 'year': yearList};
      }
    } catch (e) {
      print('获取扩展分类失败: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreVideos();
    }
  }

  Future<void> _fetchVideos() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      Map<String, String> params = {
        'type_id': widget.typeId.toString(),
        'page': '1',
        'limit': _pageSize.toString(),
      };
      if (_selectedArea != '全部') params['area'] = _selectedArea;
      if (_selectedLang != '全部') params['lang'] = _selectedLang;
      if (_selectedYear != '全部') params['year'] = _selectedYear;

      final bool useExtendApi =
          (_selectedArea != '全部' ||
              _selectedLang != '全部' ||
              _selectedYear != '全部');
      final result =
          useExtendApi
              ? await _apiManager.get(
                '/v1/vod_extend_list',
                queryParameters: params,
              )
              : await _apiManager.getVideosByType(
                typeId: widget.typeId,
                page: 1,
                limit: _pageSize,
              );

      if (mounted) {
        setState(() {
          if (result is Map &&
              result.containsKey('list') &&
              result['list'] is List) {
            _videos = result['list'];
          } else {
            _videos = [];
          }
          _currentPage = 1;
          _hasMore =
              (result is Map && result['total'] != null)
                  ? result['total'] > _videos.length
                  : false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('获取分类视频失败: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '获取分类视频失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMore) return;

    if (mounted) {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      Map<String, String> params = {
        'type_id': widget.typeId.toString(),
        'page': (_currentPage + 1).toString(),
        'limit': _pageSize.toString(),
      };
      if (_selectedArea != '全部') params['area'] = _selectedArea;
      if (_selectedLang != '全部') params['lang'] = _selectedLang;
      if (_selectedYear != '全部') params['year'] = _selectedYear;
      final bool useExtendApi =
          (_selectedArea != '全部' ||
              _selectedLang != '全部' ||
              _selectedYear != '全部');
      final result =
          useExtendApi
              ? await _apiManager.get(
                '/v1/vod_extend_list',
                queryParameters: params,
              )
              : await _apiManager.getVideosByType(
                typeId: widget.typeId,
                page: _currentPage + 1,
                limit: _pageSize,
              );

      if (mounted) {
        setState(() {
          if (result is Map &&
              result.containsKey('list') &&
              result['list'] is List) {
            _videos.addAll(result['list']);
          }
          _currentPage++;
          _hasMore =
              (result is Map && result['total'] != null)
                  ? result['total'] > _videos.length
                  : false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('加载更多分类视频失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _fetchExtends();
    await _fetchVideos();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithBackToTop(
      scrollController: _scrollController,
      bottomOffset: 70, // 适配自定义导航栏高度
      body: SafeArea(
        child: Column(
          children: [
            // 扩展分类选择器
            if (_extendOptions.isNotEmpty) _buildExtendSelector(),
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
                  // 标题
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 内容区域
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildExtendSelector() {
    Widget buildSingleSelector(
      String key,
      String selected,
      List<String> options,
      void Function(String) onChanged,
    ) {
      final List<String> allOptions = [
        '全部',
        ...options.where((e) => e != '全部'),
      ];
      return Container(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children:
                allOptions.map((opt) {
                  final bool isSelected = selected == opt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: GestureDetector(
                      onTap: () {
                        if (!isSelected) onChanged(opt);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 10 : 8,
                          vertical: 4,
                        ),
                        decoration:
                            isSelected
                                ? BoxDecoration(
                                  color:
                                      Provider.of<ThemeNotifier>(
                                        context,
                                        listen: false,
                                      ).primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                )
                                : null,
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_extendOptions['area'] != null &&
              _extendOptions['area']!.isNotEmpty)
            buildSingleSelector(
              'area',
              _selectedArea,
              _extendOptions['area']!,
              (v) {
                setState(() {
                  _selectedArea = v;
                });
                _fetchVideos();
              },
            ),
          if (_extendOptions['lang'] != null &&
              _extendOptions['lang']!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: buildSingleSelector(
                'lang',
                _selectedLang,
                _extendOptions['lang']!,
                (v) {
                  setState(() {
                    _selectedLang = v;
                  });
                  _fetchVideos();
                },
              ),
            ),
          if (_extendOptions['year'] != null &&
              _extendOptions['year']!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: buildSingleSelector(
                'year',
                _selectedYear,
                _extendOptions['year']!,
                (v) {
                  setState(() {
                    _selectedYear = v;
                  });
                  _fetchVideos();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _videos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          color: Color(0xFF00B0F0), // 使用应用主色调
        ),
      );
    }

    if (_errorMessage != null && _videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B0F0), // 使用应用主色调
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_videos.isEmpty) {
      return const SizedBox.shrink(); // 没有数据时不占用空间
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF00B0F0), // 使用应用主色调
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 12.0,
        ),
        itemCount: _videos.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _videos.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: Color(0xFF00B0F0), // 使用应用主色调
                ),
              ),
            );
          }

          final video = _videos[index];
          final String imageUrl = Uri.decodeFull(
            video['vod_pic'].toString().replaceAll(r'\/', '/'),
          );

          return GestureDetector(
            onTap: () {
              // 处理视频点击事件，跳转到视频详情页
              final int vodId =
                  video['vod_id'] is int
                      ? video['vod_id']
                      : int.tryParse(video['vod_id'].toString()) ?? 0;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoDetailPage(vodId: vodId),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 视频封面
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Stack(
                      children: [
                        // 使用CachedNetworkImage提升性能
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder:
                              (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    color: Color(0xFF00B0F0), // 使用应用主色调
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: Icon(
                                    Icons.error,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ),
                        ),

                        // 底部整体渐变
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 32, // 渐变高度可调
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.55), // 底部深色
                                  Colors.transparent, // 向上渐隐
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 备注文字
                        if (video['vod_remarks'] != null &&
                            video['vod_remarks'].toString().isNotEmpty)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 4), // 距离底部微调
                              child: Text(
                                '${video['vod_remarks']}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
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

                // 视频标题 - 居中显示
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    video['vod_name'] ?? '未知标题',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // 视频副标题（演员或标签）- 居中显示
                if (video['vod_actor'] != null &&
                    video['vod_actor'].toString().isNotEmpty)
                  Text(
                    video['vod_actor'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
                  )
                else if (video['vod_tag'] != null &&
                    video['vod_tag'].toString().isNotEmpty)
                  Text(
                    video['vod_tag'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 可复用的扩展筛选+视频列表组件
class ClassifyWithFilterModule extends StatefulWidget {
  final int typeId;
  final String title;
  const ClassifyWithFilterModule({
    Key? key,
    required this.typeId,
    required this.title,
  }) : super(key: key);

  @override
  State<ClassifyWithFilterModule> createState() =>
      _ClassifyWithFilterModuleState();
}

class _ClassifyWithFilterModuleState extends State<ClassifyWithFilterModule> {
  final OvoApiManager _apiManager = OvoApiManager();
  List<dynamic> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  Map<String, List<String>> _extendOptions = {};
  String _selectedArea = '全部';
  String _selectedLang = '全部';
  String _selectedYear = '全部';

  // 🚀 新增：标记是否已经初始化过数据，避免频繁刷新
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // 🚀 只添加滚动监听器，不自动加载数据
    _scrollController.addListener(_onScroll);
    // 🚀 延迟初始化，确保组件完全构建后再加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasInitialized && mounted) {
        _initializeData();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // 🚀 新增：初始化数据方法，只在首次加载时调用
  Future<void> _initializeData() async {
    if (_hasInitialized) return;

    print('🚀 ClassifyWithFilterModule[${widget.typeId}] 首次初始化数据');
    _hasInitialized = true;
    await _fetchExtends();
    await _fetchVideos();
  }

  Future<void> _fetchExtends() async {
    try {
      Map<String, dynamic>? res = await UserStore.getExtends(widget.typeId);
      if (res == null) {
        final apiRes = await _apiManager.get(
          '/v1/vod_extends',
          queryParameters: {'type_id': widget.typeId},
        );
        if (apiRes is Map) {
          res = Map<String, dynamic>.from(apiRes);
          await UserStore.saveExtends(widget.typeId, res);
        }
      }
      if (res != null) {
        res = Map<String, dynamic>.from(res);
        // 处理area排序：中国优先，其次其他，全部始终第一
        List<String> areaList =
            (res['area'] as List?)?.map((e) => e.toString()).toList() ?? [];
        areaList.removeWhere((e) => e == '全部');
        if (areaList.contains('中国')) {
          areaList.remove('中国');
          areaList = ['全部', '中国', ...areaList];
        } else {
          areaList = ['全部', ...areaList];
        }
        // 年份从大到小排序
        List<String> yearList =
            (res['year'] as List?)?.map((e) => e.toString()).toList() ?? [];
        yearList.sort((a, b) {
          int? ay = int.tryParse(a);
          int? by = int.tryParse(b);
          if (ay != null && by != null) return by.compareTo(ay);
          return b.compareTo(a);
        });
        // 语言原样
        List<String> langList =
            (res['lang'] as List?)?.map((e) => e.toString()).toList() ?? [];
        _extendOptions = {'area': areaList, 'lang': langList, 'year': yearList};
      }
    } catch (e) {
      print('获取扩展分类失败: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreVideos();
    }
  }

  Future<void> _fetchVideos() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      Map<String, String> params = {
        'type_id': widget.typeId.toString(),
        'page': '1',
        'limit': _pageSize.toString(),
      };
      if (_selectedArea != '全部') params['area'] = _selectedArea;
      if (_selectedLang != '全部') params['lang'] = _selectedLang;
      if (_selectedYear != '全部') params['year'] = _selectedYear;

      final bool useExtendApi =
          (_selectedArea != '全部' ||
              _selectedLang != '全部' ||
              _selectedYear != '全部');
      final result =
          useExtendApi
              ? await _apiManager.get(
                '/v1/vod_extend_list',
                queryParameters: params,
              )
              : await _apiManager.getVideosByType(
                typeId: widget.typeId,
                page: 1,
                limit: _pageSize,
              );

      if (mounted) {
        setState(() {
          if (result is Map &&
              result.containsKey('list') &&
              result['list'] is List) {
            _videos = result['list'];
          } else {
            _videos = [];
          }
          _currentPage = 1;
          _hasMore =
              (result is Map && result['total'] != null)
                  ? result['total'] > _videos.length
                  : false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('获取分类视频失败: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '获取分类视频失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMore) return;

    if (mounted) {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      Map<String, String> params = {
        'type_id': widget.typeId.toString(),
        'page': (_currentPage + 1).toString(),
        'limit': _pageSize.toString(),
      };
      if (_selectedArea != '全部') params['area'] = _selectedArea;
      if (_selectedLang != '全部') params['lang'] = _selectedLang;
      if (_selectedYear != '全部') params['year'] = _selectedYear;
      final bool useExtendApi =
          (_selectedArea != '全部' ||
              _selectedLang != '全部' ||
              _selectedYear != '全部');
      final result =
          useExtendApi
              ? await _apiManager.get(
                '/v1/vod_extend_list',
                queryParameters: params,
              )
              : await _apiManager.getVideosByType(
                typeId: widget.typeId,
                page: _currentPage + 1,
                limit: _pageSize,
              );

      if (mounted) {
        setState(() {
          if (result is Map &&
              result.containsKey('list') &&
              result['list'] is List) {
            _videos.addAll(result['list']);
          }
          _currentPage++;
          _hasMore =
              (result is Map && result['total'] != null)
                  ? result['total'] > _videos.length
                  : false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('加载更多分类视频失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // 🚀 修改：下拉刷新方法，强制重新获取数据
  Future<void> _refresh() async {
    print('🚀 ClassifyWithFilterModule[${widget.typeId}] 用户主动下拉刷新');
    // 🚀 重置当前页和数据状态
    _currentPage = 1;
    _hasMore = true;
    _videos.clear();

    await _fetchExtends();
    await _fetchVideos();
  }

  Widget _buildExtendSelector() {
    Widget buildSingleSelector(
      String key,
      String selected,
      List<String> options,
      void Function(String) onChanged,
    ) {
      final List<String> allOptions = [
        '全部',
        ...options.where((e) => e != '全部'),
      ];
      return Container(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children:
                allOptions.map((opt) {
                  final bool isSelected = selected == opt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: GestureDetector(
                      onTap: () {
                        if (!isSelected) onChanged(opt);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 10 : 8,
                          vertical: 4,
                        ),
                        decoration:
                            isSelected
                                ? BoxDecoration(
                                  color:
                                      Provider.of<ThemeNotifier>(
                                        context,
                                        listen: false,
                                      ).primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                )
                                : null,
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_extendOptions['area'] != null &&
              _extendOptions['area']!.isNotEmpty)
            buildSingleSelector(
              'area',
              _selectedArea,
              _extendOptions['area']!,
              (v) {
                setState(() {
                  _selectedArea = v;
                });
                _fetchVideos();
              },
            ),
          if (_extendOptions['lang'] != null &&
              _extendOptions['lang']!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: buildSingleSelector(
                'lang',
                _selectedLang,
                _extendOptions['lang']!,
                (v) {
                  setState(() {
                    _selectedLang = v;
                  });
                  _fetchVideos();
                },
              ),
            ),
          if (_extendOptions['year'] != null &&
              _extendOptions['year']!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: buildSingleSelector(
                'year',
                _selectedYear,
                _extendOptions['year']!,
                (v) {
                  setState(() {
                    _selectedYear = v;
                  });
                  _fetchVideos();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _videos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          color: Color(0xFF00B0F0),
        ),
      );
    }

    if (_errorMessage != null && _videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B0F0),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_videos.isEmpty) {
      return const SizedBox.shrink(); // 没有数据时不占用空间
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF00B0F0),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 12.0,
        ),
        itemCount: _videos.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _videos.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: Color(0xFF00B0F0),
                ),
              ),
            );
          }

          final video = _videos[index];
          final String imageUrl = Uri.decodeFull(
            video['vod_pic'].toString().replaceAll(r'\/', '/'),
          );

          return GestureDetector(
            onTap: () {
              final int vodId =
                  video['vod_id'] is int
                      ? video['vod_id']
                      : int.tryParse(video['vod_id'].toString()) ?? 0;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoDetailPage(vodId: vodId),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder:
                              (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    color: Color(0xFF00B0F0),
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: Icon(
                                    Icons.error,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ),
                        ),

                        // 底部整体渐变
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 32, // 渐变高度可调
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.55), // 底部深色
                                  Colors.transparent, // 向上渐隐
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 备注文字
                        if (video['vod_remarks'] != null &&
                            video['vod_remarks'].toString().isNotEmpty)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 4), // 距离底部微调
                              child: Text(
                                '${video['vod_remarks']}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
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
                    video['vod_name'] ?? '未知标题',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (video['vod_actor'] != null &&
                    video['vod_actor'].toString().isNotEmpty)
                  Text(
                    video['vod_actor'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
                  )
                else if (video['vod_tag'] != null &&
                    video['vod_tag'].toString().isNotEmpty)
                  Text(
                    video['vod_tag'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            if (_extendOptions.isNotEmpty) _buildExtendSelector(),
            Expanded(child: _buildContent()),
          ],
        ),
        BackToTopButton(
          scrollController: _scrollController,
          bottomOffset: 70, // 适配自定义导航栏高度
        ),
      ],
    );
  }
}
