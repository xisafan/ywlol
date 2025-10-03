import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api/ssl_Management.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
// 移除组件导入，使用自包含实现

// 波纹加载动画组件
class WaveLoadingSpinner extends StatefulWidget {
  final double size;
  final Color color;

  const WaveLoadingSpinner({
    Key? key,
    this.size = 28.0, // 从40改为28，更小更圆滑
    this.color = const Color(0xFFBDBDBD),
  }) : super(key: key);

  @override
  _WaveLoadingSpinnerState createState() => _WaveLoadingSpinnerState();
}

class _WaveLoadingSpinnerState extends State<WaveLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _WaveLoadingPainter(
            animation: _controller,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _WaveLoadingPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _WaveLoadingPainter({required this.animation, required this.color})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final double animationValue = animation.value;
    final double radius1 = (size.width / 2) * animationValue;
    final double radius2 = (size.width / 2) * ((animationValue + 0.5) % 1.0);

    if (radius1 <= size.width / 2) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        radius1,
        paint,
      );
    }

    if (radius2 <= size.width / 2) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        radius2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveLoadingPainter oldDelegate) => true;
}

/// 重构后的主视频详情页面
class VideoDetailPage extends StatefulWidget {
  final int vodId;
  final int? initialEpisodeIndex;
  final String? initialPlayFrom;
  final int? initialPositionSeconds;

  const VideoDetailPage({
    Key? key,
    required this.vodId,
    this.initialEpisodeIndex,
    this.initialPlayFrom,
    this.initialPositionSeconds,
  }) : super(key: key);

  @override
  _VideoDetailPageState createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  final OvoApiManager _apiManager = OvoApiManager();
  final ScrollController _mainScrollController = ScrollController();
  
  // 全局状态
  Map<String, dynamic>? _videoDetail;
  bool _isLoading = true;
  String? _errorMessage;
  bool _contentLoaded = false;
  
  // 播放器相关状态
  bool _isFullScreen = false;
  int _currentEpisodeIndex = 0;
  List<List<Map<String, String>>> _playUrlsList = [];
  List<String> _playFromList = [];
  bool _isReverseSort = false;
  bool _showEpisodePopup = false;
  
  // 标签页相关
  String _currentTab = '简介';
  
  // 浮动操作栏
  bool _showFloatingActionBar = true;
  bool _isLiked = false;
  bool _isFavorited = false;
  
  // Tab栏相关
  double _tabIndicatorPosition = 0.0;
  bool _danmakuEnabled = true;
  
  // 固定的切换栏高度常量
  static const double kTabBarFixedHeight = 42.0;
  
  // 颜色常量
  Color get _secondaryTextColor => Colors.grey[600]!;
  
  // 评论相关
  final TextEditingController _commentInputController = TextEditingController();
  final FocusNode _commentInputFocusNode = FocusNode();
  bool _isReplying = false;
  String _replyToUserName = '';
  int? _replyToCommentId;
  
  // 组件引用（自包含版本）
  // GlobalKey<VideoPlayerComponentState> _playerKey = GlobalKey();
  // GlobalKey<VideoInfoComponentState> _infoKey = GlobalKey();
  // GlobalKey<VideoCommentComponentState> _commentKey = GlobalKey();
  
  // 主题色
  Color get _primaryColor => AppTheme.primaryColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // 初始化集数索引
    if (widget.initialEpisodeIndex != null) {
      _currentEpisodeIndex = widget.initialEpisodeIndex!;
    }
    
    // 获取视频详情
    _fetchVideoDetail().then((_) {
      // 视频详情加载完成后获取点赞和收藏状态
      _fetchLikeStatus();
      _fetchFavoriteStatus();
    });
  }
  
  // 获取点赞状态
  Future<void> _fetchLikeStatus() async {
    final vodId = int.tryParse(_videoDetail?['vod_id']?.toString() ?? '') ?? 0;
    if (vodId > 0) {
      final liked = await _apiManager.isVideoLiked(vodId);
      setState(() {
        _isLiked = liked;
      });
    }
  }

  // 获取收藏状态
  Future<void> _fetchFavoriteStatus() async {
    final vodId = int.tryParse(_videoDetail?['vod_id']?.toString() ?? '') ?? 0;
    if (vodId > 0) {
      final favorited = await _apiManager.isVideoFavorited(vodId);
      setState(() {
        _isFavorited = favorited;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mainScrollController.dispose();
    _commentInputController.dispose();
    _commentInputFocusNode.dispose();
    super.dispose();
  }

  /// 获取视频详情
  Future<void> _fetchVideoDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vodDetail = await _apiManager.getVideoDetail(widget.vodId);

      if (vodDetail.isNotEmpty) {
        setState(() {
          _videoDetail = vodDetail;
          _isLoading = false;
          _contentLoaded = true;
        });
        
        // 解析播放源数据
        _parsePlayerData(vodDetail);
        
      } else {
        setState(() {
          _errorMessage = '获取视频详情失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('获取视频详情失败: $e');
      setState(() {
        _errorMessage = '网络错误，请稍后重试';
        _isLoading = false;
      });
    }
  }

  /// 解析播放器数据
  void _parsePlayerData(Map<String, dynamic> videoDetail) {
    final vodPlayFrom = videoDetail['vod_play_from'] ?? '';
    final vodPlayUrl = videoDetail['vod_play_url'] ?? '';
    
    if (vodPlayFrom.isNotEmpty && vodPlayUrl.isNotEmpty) {
      _playFromList = vodPlayFrom.split('\$\$\$');
      final playUrlsList = vodPlayUrl.split('\$\$\$');
      
      if (_playFromList.length == playUrlsList.length) {
        _playUrlsList.clear();
        for (String playUrls in playUrlsList) {
          final episodeList = <Map<String, String>>[];
          final episodes = playUrls.split('#');
          
          for (String episode in episodes) {
            if (episode.trim().isNotEmpty) {
              final parts = episode.split('\$');
              if (parts.length >= 2) {
                episodeList.add({
                  'name': parts[0],
                  'url': parts[1],
                });
              }
            }
          }
          _playUrlsList.add(episodeList);
        }
        
        // 确保当前集数索引在有效范围内
        if (_playUrlsList.isNotEmpty && 
            _currentEpisodeIndex >= _playUrlsList[0].length) {
          _currentEpisodeIndex = 0;
        }
      }
    }
  }

  /// 处理全屏状态变化
  void _onFullScreenChanged(bool isFullScreen) {
    setState(() {
      _isFullScreen = isFullScreen;
    });
  }

  /// 显示选集弹窗
  void _showEpisodeSelection() {
    setState(() {
      _showEpisodePopup = true;
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEpisodeSheet(),
    ).then((_) {
      setState(() {
        _showEpisodePopup = false;
      });
    });
  }

  /// 构建选集弹窗
  Widget _buildEpisodeSheet() {
    if (_playUrlsList.isEmpty) return SizedBox.shrink();
    
    final episodes = _playUrlsList[0];
    final displayEpisodes = _isReverseSort ? episodes.reversed.toList() : episodes;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Text(
                  '选择集数',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isReverseSort = !_isReverseSort;
                    });
                    Navigator.pop(context);
                    _showEpisodeSelection(); // 重新打开
                  },
                  child: Row(
                    children: [
                      Icon(
                        _isReverseSort ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                        color: _primaryColor,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _isReverseSort ? '升序' : '降序',
                        style: TextStyle(color: _primaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 选集网格
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              itemCount: displayEpisodes.length,
              itemBuilder: (context, index) {
                final actualIndex = _isReverseSort ? episodes.length - 1 - index : index;
                final episode = displayEpisodes[index];
                final isSelected = actualIndex == _currentEpisodeIndex;
                
                return EpisodeCard(
                  name: episode['name'] ?? '第${actualIndex + 1}集',
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      _currentEpisodeIndex = actualIndex;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 浮动操作栏 - 椭圆形黑色背景，支持智能显示/隐藏
  Widget _buildFloatingActionBar() {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: 0,
      right: 0,
      bottom: _showFloatingActionBar
          ? MediaQuery.of(context).padding.bottom + 20
          : -(MediaQuery.of(context).padding.bottom + 70),
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 250),
        opacity: _showFloatingActionBar ? 1.0 : 0.0,
        child: Center(
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 点赞
                _buildFloatingActionButton(
                  icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  label: '${_videoDetail?['vod_up'] ?? '0'}',
                  isActive: _isLiked,
                  onTap: () {
                    if (UserStore().user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('请先登录后再操作')),
                      );
                      return;
                    }
                    _toggleLike();
                  },
                ),
                SizedBox(width: 14),
                // 下载
                _buildFloatingActionButton(
                  icon: Icons.file_download_outlined,
                  label: '下载',
                  onTap: () {
                    if (UserStore().user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('请先登录后再操作')),
                      );
                      return;
                    }
                    _showDownloadSheet();
                  },
                ),
                SizedBox(width: 14),
                // 催更
                _buildFloatingActionButton(
                  icon: Icons.notification_add_outlined,
                  label: '催更',
                  onTap: () {
                    if (UserStore().user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('请先登录后再操作')),
                      );
                      return;
                    }
                    // 催更功能后续补充
                  },
                ),
                SizedBox(width: 14),
                // 反馈
                _buildFloatingActionButton(
                  icon: Icons.feedback_outlined,
                  label: '反馈',
                  onTap: () {
                    if (UserStore().user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('请先登录后再操作')),
                      );
                      return;
                    }
                    // 反馈功能后续补充
                  },
                ),
                SizedBox(width: 14),
                // 收藏
                _buildFloatingActionButton(
                  icon: _isFavorited ? Icons.bookmark : Icons.bookmark_border,
                  label: '收藏',
                  isActive: _isFavorited,
                  onTap: () {
                    if (UserStore().user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('请先登录后再操作')),
                      );
                      return;
                    }
                    _toggleFavorite();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 浮动操作按钮构建器 - 适配黑色背景
  Widget _buildFloatingActionButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isActive
                  ? _primaryColor.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 19,
              color: isActive ? _primaryColor : Colors.white.withOpacity(0.9),
            ),
          ),
          SizedBox(height: 2),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? _primaryColor : Colors.white.withOpacity(0.9),
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 点赞切换方法
  Future<void> _toggleLike() async {
    final vodId = int.tryParse(_videoDetail?['vod_id']?.toString() ?? '') ?? 0;
    if (vodId == 0) return;
    final newLike = !_isLiked;
    print('准备${newLike ? "点赞" : "取消点赞"}视频 $vodId');
    print('当前状态 - 点赞状态: $_isLiked, 点赞数: ${_videoDetail?['vod_up']}');

    final result = await _apiManager.likeVideo(vodId, newLike);
    print('服务器返回点赞结果: $result');

    if (result['zan'] == newLike) {
      // 操作成功
      setState(() {
        _isLiked = newLike;
        if (result['vod_up'] != null) {
          final oldUp = _videoDetail?['vod_up'];
          _videoDetail?.update(
            'vod_up',
            (value) => result['vod_up'].toString(),
          );
          print('更新点赞数: $oldUp -> ${result['vod_up']}');
        }
      });
      print('点赞操作成功: ${newLike ? "已点赞" : "已取消点赞"}');
    } else {
      // 操作失败
      print('点赞操作失败: 期望状态=$newLike, 服务器返回状态=${result['zan']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newLike ? "点赞" : "取消点赞"}失败，请稍后重试')),
      );
    }
  }

  // 收藏切换方法
  Future<void> _toggleFavorite() async {
    final vodId = int.tryParse(_videoDetail?['vod_id']?.toString() ?? '') ?? 0;
    if (vodId == 0) return;
    bool success = false;
    if (_isFavorited) {
      success = await _apiManager.removeVideoFavorite(vodId);
    } else {
      success = await _apiManager.addVideoFavorite(vodId);
    }
    if (success) {
      setState(() {
        _isFavorited = !_isFavorited;
      });
    }
  }

  // 显示下载弹窗
  void _showDownloadSheet() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('下载功能待实现')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 设置状态栏样式
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _isFullScreen ? Colors.black : Colors.white,
        systemNavigationBarIconBrightness: _isFullScreen ? Brightness.light : Brightness.dark,
      ),
    );

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: WaveLoadingSpinner(
            size: 48,
            color: _primaryColor,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('加载失败'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchVideoDetail,
                child: Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_isFullScreen) {
          _onFullScreenChanged(false);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _isFullScreen ? Colors.black : Colors.white,
        resizeToAvoidBottomInset: true,
        body: _isFullScreen
            ? SafeArea(
                top: false,
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Text(
                      '全屏播放器',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),
              )
            : Stack(
                children: [
                  _buildPortraitLayout(),
                  // 浮动操作栏只在简介页面且非全屏时显示
                  if (!_isFullScreen && _currentTab == '简介')
                    _buildFloatingActionBar(),
                  // 评论输入框固定在底部
                  if (!_isFullScreen && _currentTab == '评论')
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildCommentInputBar(),
                    ),
                ],
              ),
      ),
    );
  }

  /// 构建竖屏布局
  Widget _buildPortraitLayout() {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          // 状态栏高度的黑色区域
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).padding.top,
            color: Colors.black,
          ),
          
          // 视频播放器区域
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.width * 9 / 16,
            color: Colors.black,
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 60,
                      ),
                      SizedBox(height: 12),
                      Text(
                        '视频播放器',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      if (_videoDetail != null) ..[
                        SizedBox(height: 8),
                        Text(
                          _videoDetail!['vod_name'] ?? '',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                // 全屏按钮
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => _onFullScreenChanged(true),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 下方内容区域
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // 弹幕输入框和Tab栏
                  _buildDanmakuTabBar(),
                  
                  // 内容区域
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建标签栏
  Widget _buildTabBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          _buildTabButton('简介', 0),
          _buildTabButton('评论', 1),
        ],
      ),
    );
  }


  // 弹幕输入框开关tab一行
  Widget _buildDanmakuTabBar() {
    return Container(
      height: kTabBarFixedHeight, // 设置固定高度
      child: Column(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              margin: EdgeInsets.only(top: 0), // 进一步减少顶部间距为0
              child: Row(
                children: [
                  _buildTabButton('简介', 0),
                  SizedBox(width: 12), // 减少按钮间距
                  _buildTabButton('评论', 1),
                  Spacer(),
                  // 右侧弹幕输入框开关始终显示
                  Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      height: 26, // 进一步缩小弹幕输入框高度至26px
                      width: _danmakuEnabled
                          ? MediaQuery.of(context).size.width * 0.45 // 从0.5缩小到0.45
                          : 38, // 进一步缩小弹幕开关按钮宽度
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(13), // 调整圆角以配合高度
                      ),
                      child: Row(
                        mainAxisAlignment: _danmakuEnabled
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.end,
                        children: [
                          if (_danmakuEnabled) ...[
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _showDanmakuSendSheet();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                  ),
                                  child: Text(
                                    '发送弹幕',
                                    style: TextStyle(
                                      fontSize: 12, // 从14缩小到12
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 16, // 从20缩小到16
                              color: Colors.grey[300],
                              margin: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 7,
                              ), // 调整vertical从8到7
                            ),
                          ],
                          // 弹幕开关按钮始终显示
                          Padding(
                            padding: const EdgeInsets.only(
                              right: 6.0,
                              left: 3.0,
                            ), // 缩小padding
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _danmakuEnabled = !_danmakuEnabled;
                                });
                              },
                              child: Icon(
                                _danmakuEnabled
                                    ? Icons.subtitles
                                    : Icons.subtitles_off,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建标签按钮S
  Widget _buildTabButton(String label, int tabIndex) {
    bool isSelected = (_tabIndicatorPosition.round() == tabIndex);
    double baseFontSize = 12; // 修正基础字体大小
    double selectedFontSize = baseFontSize + 3; // 从+4改为+3

    return GestureDetector(
      onTap: () => _onTabTap(label),
      child: Container(
        height: 28, // 进一步减少至28px
        padding: EdgeInsets.symmetric(horizontal: 6), // 保持水平填充
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: baseFontSize,
                  end: isSelected ? selectedFontSize : baseFontSize,
                ),
                duration: Duration(milliseconds: 180),
                curve: Curves.ease,
                builder: (context, value, child) {
                  return Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? _primaryColor
                          : _secondaryTextColor,
                      fontSize: value,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                },
              ),
            ),
            // 指示器
            AnimatedContainer(
              duration: Duration(milliseconds: 100),
              curve: Curves.ease,
              margin: EdgeInsets.only(bottom: 0),
              height: 3,
              width: _tabIndicatorPosition == tabIndex
                  ? 32
                  : (_tabIndicatorPosition - tabIndex).abs() < 1
                  ? 32 * (1 - (_tabIndicatorPosition - tabIndex).abs())
                  : 0,
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tab切换方法
  void _onTabTap(String tab) {
    setState(() {
      _currentTab = tab;
      _tabIndicatorPosition = tab == '简介' ? 0.0 : 1.0;
      
      // 根据当前页面设置浮动操作栏状态
      if (tab == '评论') {
        _showFloatingActionBar = false;
      } else {
        _showFloatingActionBar = true;
      }
    });
  }

  // 显示弹幕发送弹窗
  void _showDanmakuSendSheet() {
    // TODO: 实现弹幕发送功能
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('弹幕功能待实现')),
    );
  }

  // 评论输入框
  Widget _buildCommentInputBar() {
    final bool isLoggedIn = UserStore().user != null;

    return SafeArea(
      child: Container(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 回复状态提示条
            if (_isReplying && _replyToUserName.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: _primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.reply, color: _primaryColor, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '正在回复 @$_replyToUserName 的评论',
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, color: _primaryColor, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            // 输入栏
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 32,
                      child: TextField(
                        controller: _commentInputController,
                        focusNode: _commentInputFocusNode,
                        enabled: isLoggedIn,
                        decoration: InputDecoration(
                          hintText: !isLoggedIn
                              ? '请先登录后评论'
                              : (_isReplying && _replyToUserName.isNotEmpty
                              ? '回复@$_replyToUserName的评论：'
                              : '快来发点什么吧！'),
                          filled: true,
                          fillColor: isLoggedIn
                              ? Color(0xFFF2F2F2)
                              : Color(0xFFE8E8E8),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: !isLoggedIn
                              ? Icon(
                            Icons.login,
                            color: Colors.grey[400],
                            size: 18,
                          )
                              : null,
                          isDense: true,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: isLoggedIn ? Colors.black87 : Colors.grey[400],
                        ),
                        onTap: () async {
                          if (!isLoggedIn) {
                            // TODO: 跳转到登录页面
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('请先登录后再评论')),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // 发送按钮
                  GestureDetector(
                    onTap: isLoggedIn ? _onSendComment : null,
                    child: Container(
                      height: 32,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isLoggedIn && _commentInputController.text.trim().isNotEmpty
                            ? _primaryColor
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '发送',
                          style: TextStyle(
                            color: isLoggedIn && _commentInputController.text.trim().isNotEmpty
                                ? Colors.white
                                : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 发送评论
  void _onSendComment() async {
    final content = _commentInputController.text.trim();
    if (content.isEmpty) return;

    // TODO: 实现评论发送功能
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('评论发送功能待实现')),
    );
    
    // 清空输入框
    _commentInputController.clear();
    // 取消输入框焦点
    _commentInputFocusNode.unfocus();
  }

  // 取消回复
  void _cancelReply() {
    setState(() {
      _isReplying = false;
      _replyToUserName = '';
      _replyToCommentId = null;
    });
  }

  /// 构建内容区域
  Widget _buildContent() {
    return IndexedStack(
      index: _currentTab == '简介' ? 0 : 1,
      children: [
        // 简介页
        VideoInfoComponent(
          key: _infoKey,
          videoDetail: _videoDetail,
          mainScrollController: _mainScrollController,
          currentEpisodeIndex: _currentEpisodeIndex,
          playUrlsList: _playUrlsList,
          isReverseSort: _isReverseSort,
          isLiked: _isLiked,
          isFavorited: _isFavorited,
          onEpisodeSelected: (index) {
            setState(() {
              _currentEpisodeIndex = index;
            });
          },
          onShowEpisodePopup: _showEpisodeSelection,
          onLikePressed: _toggleLike,
          onFavoritePressed: _toggleFavorite,
          onDownloadPressed: _showDownloadSheet,
        ),
        
        // 评论页
        VideoCommentComponent(
          key: _commentKey,
          vodId: widget.vodId,
        ),
      ],
    );
  }
}

// 选集卡片组件
class EpisodeCard extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const EpisodeCard({
    Key? key,
    required this.name,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? primaryColor : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            name,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// 视频流组件（简化版，用于相关推荐）
class VideoStreaming extends StatelessWidget {
  final int? currentVideoId;
  final int? typeId;

  const VideoStreaming({
    Key? key,
    this.currentVideoId,
    this.typeId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      child: Center(
        child: Text(
          '相关推荐',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

// 其他必要的枚举和类
enum AspectRatioMode { auto, stretch, cover, ratio16_9, ratio4_3 }

// 视频详情页模糊背景页面
class VideoBlurbDetailPage extends StatelessWidget {
  final String title;
  final String blurb;

  const VideoBlurbDetailPage({
    Key? key,
    required this.title,
    required this.blurb,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                blurb,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
