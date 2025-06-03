import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ovofun/services/api/ssl_Management.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ovofun/page/vedios.dart';
import 'package:ovofun/page/models/color_models.dart';
import 'dart:math' as math;

class RankingPage extends StatefulWidget {
  @override
  _RankingPageState createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  final OvoApiManager _api = OvoApiManager();
  List<dynamic> _types = [];
  int _selectedTypeIndex = 0; // 用index方便PageView联动1
  List<List<dynamic>> _rankingLists = [];
  bool _loading = true;
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    _fetchTypesAndRanking();
  }

  Future<void> _fetchTypesAndRanking() async {
    setState(() { _loading = true; });
    final types = await _api.getAllTypes();
    setState(() {
      _types = types;
      _selectedTypeIndex = 0;
      _rankingLists = List.generate(types.length + 1, (_) => []); // 包含"全部"1
      _pageController = PageController(initialPage: 0);
    });
    await _fetchRanking(0);
  }

  Future<void> _fetchRanking(int pageIndex) async {
    setState(() { _loading = true; });
    int typeId = pageIndex == 0 ? 0 : _types[pageIndex - 1]['type_id'];
    final res = await _api.get('/top', queryParameters: typeId == 0 ? null : {'type': typeId});
    List<dynamic> list = [];
    if (res is Map && res['list'] != null) {
      list = res['list'];
    } else if (res is List) {
      list = res;
    }
    setState(() {
      _rankingLists[pageIndex] = list;
      _loading = false;
    });
  }

  Widget _buildTypeTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        height: 46,
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(_types.length + 1, (i) {
            String name = i == 0 ? '全部' : _types[i - 1]['type_name'];
            final selected = _selectedTypeIndex == i;
            return GestureDetector(
              onTap: () {
                if (_selectedTypeIndex != i) {
                  setState(() { _selectedTypeIndex = i; });
                  _pageController?.jumpToPage(i); // 直接跳转到目标页面，不使用动画
                  if (_rankingLists[i].isEmpty) _fetchRanking(i);
                }
              },
              child: Container(
                width: 80,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      style: TextStyle(
                        fontSize: selected ? 20 : 16,
                        color: selected ? Colors.blue : Colors.black87,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      child: Text(name),
                    ),
                    SizedBox(height: 0),
                    Container(
                      width: 28,
                      height: 14,
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: 200),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: selected
                            ? CustomPaint(
                                key: ValueKey('arc_$i'),
                                size: Size(28, 14),
                                painter: ArcIndicatorPainter(color: Colors.blue),
                              )
                            : SizedBox.shrink(key: ValueKey('empty_$i')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildRankingList(int pageIndex) {
    if (_loading && _rankingLists.isEmpty) {
      return Center(child: CircularProgressIndicator(color: Colors.pink));
    }
    final list = _rankingLists.isNotEmpty ? _rankingLists[pageIndex] : [];
    if (list.isEmpty && !_loading) {
      return Center(child: Text('暂无数据'));
    }
    return ListView.builder(
      key: PageStorageKey(pageIndex),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _buildRankingItem(list[index], index);
      },
    );
  }

  Widget _buildRankingItem(Map item, int index) {
    final String pic = item['vod_pic'] ?? '';
    final String name = item['vod_name'] ?? '';
    final String remarks = item['vod_remarks'] ?? '';
    final String lang = item['vod_lang'] ?? '';
    final String year = item['vod_year']?.toString() ?? '';
    final String content = item['vod_content'] ?? '';
    final bool isTop3 = index < 3;
    final List<String> topAssets = [
      'assets/image/top1.png',
      'assets/image/top2.png',
      'assets/image/top3.png',
    ];
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      height: 150,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          final vodId = item['vod_id'] ?? item['id'] ?? item['video_id'];
          if (vodId != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => VideoDetailPage(vodId: int.tryParse(vodId.toString()) ?? 0),
              ),
            );
          }
        },
        child: Stack(
          children: [
            // 背景高斯模糊
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: pic.isNotEmpty
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: CachedNetworkImage(
                          imageUrl: pic,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey.shade200),
                          errorWidget: (context, url, error) => Container(color: Colors.grey.shade300),
                        ),
                      )
                    : Container(color: Colors.grey.shade200),
              ),
            ),
            // 半透明白色遮罩
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: Colors.white.withOpacity(0.50),
                ),
              ),
            ),
            // 内容
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 左侧竖图（3:4比例，底部角标在容器内叠加，底部圆角一致）
                Container(
                  width: 110,
                  margin: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: pic.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: pic,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: Colors.grey.shade300),
                                  errorWidget: (context, url, error) => Container(color: Colors.grey.shade300),
                                )
                              : Container(color: Colors.grey.shade300),
                        ),
                        if (isTop3)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              child: Image.asset(
                                topAssets[index],
                                fit: BoxFit.fitWidth,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // 右侧信息
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 18, horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        SizedBox(height: 0),
                        Text(
                          '$remarks | $lang | $year',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 5),
                        Text(
                          content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          // 顶部背景图+渐隐，直接顶到屏幕最上方
          SizedBox(
            width: double.infinity,
            height: 160,
            child: Stack(
              children: [
                Image.asset(
                  'assets/image/rankingtop.jpg',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
                // 顶部白色渐隐
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 48, // 可微调
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // 底部白色渐隐
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 120,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.white,
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 内容区用SafeArea包裹
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 16),
                Center(
                  child: Text(
                    '排行榜',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),
                _buildTypeTabs(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _types.length + 1,
                    onPageChanged: (i) {
                      setState(() { _selectedTypeIndex = i; });
                      if (_rankingLists[i].isEmpty) _fetchRanking(i);
                    },
                    itemBuilder: (context, i) => _buildRankingList(i),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ArcIndicatorPainter extends CustomPainter {
  final Color color;
  final double thickness;
  ArcIndicatorPainter({required this.color, this.thickness = 3.5});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final double width = size.width;
    final double height = size.height;
    
    final Rect rect = Rect.fromLTWH(
      0,
      -height * 0.6,  // 减小向上偏移量
      width,
      height * 1.6  // 减小高度倍数使弧度更小
    );

    // 画一个较小的弧（30°~150°）
    canvas.drawArc(
      rect,
      math.pi * 0.167,  // 30度
      math.pi * 0.666,  // 120度
      false,
      paint
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}