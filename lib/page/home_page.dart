import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ovofun/page/models/banner.dart';
import 'package:ovofun/models/banner_model.dart';
import 'package:ovofun/page/models/hotvedio.dart';
import 'package:ovofun/models/hotvedio_model.dart';
import 'package:ovofun/page/models/classify.dart'; // 导入分类模块
import 'package:ovofun/page/search_page.dart'; // 导入搜索页面
import 'package:ovofun/page/vedios.dart'; // 导入视频详情页面
import 'package:ovofun/services/api/ssl_Management.dart'; // 引入OvoApiManager
import 'package:ovofun/page/history_page.dart'; // 导入历史记录页面
import 'package:ovofun/page/login_page.dart'; // 导入登录页面
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:ovofun/models/user_model.dart';
import 'package:ovofun/page/models/color_models.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';

// 自定义 TabBar 指示器，实现圆角效果
class RoundedRectIndicator extends Decoration {
  final BoxPainter _painter;

  RoundedRectIndicator({
    required Color color,
    required double radius,
    double thickness = 3.0, // 指示器厚度默认
  }) : _painter = _RoundedRectPainter(color, radius, thickness);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _painter;
}

class _RoundedRectPainter extends BoxPainter {
  final Paint _paint;
  final double radius;
  final double thickness;

  _RoundedRectPainter(Color color, this.radius, this.thickness) 
    : _paint = Paint()
      ..color = color
      ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect = offset & configuration.size!;
    final RRect rrect = RRect.fromRectAndCorners(
      Rect.fromLTWH(rect.left, rect.bottom - thickness, rect.width, thickness),
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
      bottomLeft: Radius.circular(radius), // 如果也想要底部圆角，可以设置这里
      bottomRight: Radius.circular(radius), // 如果也想要底部圆角，可以设置这里1
    );
    canvas.drawRRect(rrect, _paint);
  }
}

class HomePage extends StatefulWidget {
  final Function(int)? onNavigateToProfile;  // 添加回调函数
  const HomePage({super.key, this.onNavigateToProfile});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {  // 修改为TickerProviderStateMixin
  final OvoApiManager _apiManager = OvoApiManager();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  
  // 用户信息
  User? _user;
  
  // Banner数据
  List<BannerModel> _banners = [];
  bool _loadingBanners = true;
  
  // 热门视频数据
  List<HotVedioModel> _hotVedios = [];
  bool _loadingHotVedios = true;
  
  // 分类数据
  List<dynamic> _categories = [];
  bool _loadingCategories = true;
  
  // 当前选中的分类索引
  int _selectedCategoryIndex = 0;
  
  // Tab控制器
  TabController? _tabController;  // 修改为可空类型
  
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchData();
  }
  
  @override
  void dispose() {
    _disposeTabController();  // 添加释放TabController的方法
    super.dispose();
  }
  
  // 释放TabController的方法
  void _disposeTabController() {
    _tabController?.removeListener(_handleTabSelection);  // 移除监听器
    _tabController?.dispose();
    _tabController = null;
  }
  
  // Tab选择监听器
  void _handleTabSelection() {
    if (_tabController != null && !_tabController!.indexIsChanging) {
      setState(() {
        _selectedCategoryIndex = _tabController!.index;
      });
    }
  }
  
  // 加载用户信息（从UserStore）
  Future<void> _loadUserInfo() async {
    await UserStore().loadUser();
    print('刷新后页面拿到的qq: [32m[1m[4m[7m${UserStore().user?.qq}[0m');
    setState(() {
      _user = UserStore().user;
      print('setState后 _user.qq: [31m[1m[4m[7m${_user?.qq}[0m');
    });
    // 如果有token，设置到API管理器
    if (_user != null && _user!.token != null && _user!.token!.isNotEmpty) {
      _apiManager.setToken(_user!.token ?? '');
    }
  }
  
  // 获取所有数据
  Future<void> _fetchData() async {
    await Future.wait([
      _fetchCategories(),
      _fetchBanners(),
      _fetchHotVedios(),
    ]);
  }
  
  // 获取分类数据
  Future<void> _fetchCategories() async {
    try {
      setState(() {
        _loadingCategories = true;
      });
      
      // 添加"精选"作为第一个分类
      final List<dynamic> categories = [
        {'type_id': 0, 'type_name': '精选', 'type_en': 'featured'}
      ];
      
      // 获取API分类数据
      final apiCategories = await _apiManager.getAllTypes();
      categories.addAll(apiCategories);
      
      setState(() {
        _categories = categories;
        _loadingCategories = false;
        
        // 先释放旧的TabController
        _disposeTabController();
        
        // 初始化新的Tab控制器
        _tabController = TabController(
          length: _categories.length,
          vsync: this,
          initialIndex: _selectedCategoryIndex < _categories.length ? _selectedCategoryIndex : 0,
        );
        
        // 监听Tab切换
        _tabController!.addListener(_handleTabSelection);
      });
    } catch (e) {
      print('获取分类数据失败: $e');
      setState(() {
        _loadingCategories = false;
        _categories = [
          {'type_id': 0, 'type_name': '精选', 'type_en': 'featured'},
        ];
        
        // 先释放旧的TabController
        _disposeTabController();
        
        // 初始化新的Tab控制器
        _tabController = TabController(
          length: _categories.length,
          vsync: this,
          initialIndex: _selectedCategoryIndex < _categories.length ? _selectedCategoryIndex : 0,
        );
        
        // 监听Tab切换
        _tabController!.addListener(_handleTabSelection);
      });
    }
  }
  
  // 获取Banner数据
  Future<void> _fetchBanners() async {
    try {
      setState(() {
        _loadingBanners = true;
      });
      
      final bannerData = await _apiManager.getBanners();
      final List<BannerModel> banners = [];
      
      for (var item in bannerData) {
        try {
          banners.add(BannerModel.fromJson(item));
        } catch (e) {
          print('解析Banner数据失败: $e');
        }
      }
      
      setState(() {
        _banners = banners;
        _loadingBanners = false;
      });
    } catch (e) {
      print('获取Banner数据失败: $e');
      setState(() {
        _loadingBanners = false;
      });
    }
  }
  
  // 获取热门视频数据
  Future<void> _fetchHotVedios() async {
    try {
      setState(() {
        _loadingHotVedios = true;
      });
      
      final hotVedioData = await _apiManager.getHotVedios();
      final List<HotVedioModel> hotVedios = [];
      
      for (var item in hotVedioData) {
        try {
          hotVedios.add(HotVedioModel.fromJson(item));
        } catch (e) {
          print('解析热门视频数据失败: $e');
        }
      }
      
      setState(() {
        _hotVedios = hotVedios;
        _loadingHotVedios = false;
      });
    } catch (e) {
      print('获取热门视频数据失败: $e');
      setState(() {
        _loadingHotVedios = false;
      });
    }
  }
  
  // 刷新数据
  Future<void> _refreshData() async {
    await _loadUserInfo();
    await _fetchData();
    setState(() {}); // 强制刷新，确保TabBarView和分类内容区域重建
  }
  
  // 导航到视频详情页
  void _navigateToVideoDetail(int vodId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoDetailPage(vodId: vodId),
      ),
    );
  }
  
  // 导航到搜索页面
  void _navigateToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SearchPage(),
      ),
    );
  }
  
  // 导航到历史记录页面
  void _navigateToHistory() {
    if (_user == null) {
      // 未登录，先导航到登录页面
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      ).then((value) {
        // 登录页返回后刷新用户信息
        _loadUserInfo();
      });
    } else {
      // 已登录，导航到历史记录页面
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryPage(user: _user!),
        ),
      );
    }
  }
  
  // 导航到登录页面
  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
    ).then((value) {
      // 登录页返回后刷新用户信息
      _loadUserInfo();
    });
  }
  
  // 导航到分类更多页面
  void _navigateToClassifyMore(int typeId, String typeName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClassifyMorePage(
          typeId: typeId,
          title: typeName,
        ),
      ),
    );
  }
  
  // 修改头像点击事件处理
  void _handleAvatarTap() {
    if (_user == null) {
      _navigateToLogin();
    } else {
      // 切换到"我的"页面
      widget.onNavigateToProfile?.call(3);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: _refreshData,
          child: Column(
            children: [
              // 顶部导航栏 - 减小高度
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildTopBar(),
              ),
              
              // 分类Tab栏
              if (_loadingCategories)
                const SizedBox(
                  height: 40,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: Colors.blue,
                    ),
                  ),
                )
              else
                _buildCategoryTabs(),
              
              // 内容区域
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 构建顶部导航栏
  Widget _buildTopBar() {
    return Row(
      children: [
        // 用户头像 - 点击进入登录页或个人页面1
        GestureDetector(
          onTap: _handleAvatarTap,
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFEEEEEE),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: (_user != null && _user!.avatar != null && _user!.avatar!.isNotEmpty)
                  ? Image.network(
                      _user!.avatar!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/image/touxiang.jpg',
                          fit: BoxFit.cover,
                        );
                      },
                    )
                  : (_user != null && (_user!.avatar == null || _user!.avatar!.isEmpty) && _user!.qq != null && _user!.qq!.isNotEmpty)
                      ? Image.network(
                          'https://q1.qlogo.cn/g?b=qq&nk=${_user!.qq}&s=100',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/image/touxiang.jpg',
                              fit: BoxFit.cover,
                            );
                          },
                        )
                      : Image.asset(
                          'assets/image/touxiang.jpg',
                          fit: BoxFit.cover,
                        ),
            ),
          ),
        ),
          
        // 搜索框
        Expanded(
          child: GestureDetector(
            onTap: _navigateToSearch,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: Colors.grey[400],
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '今天你想看些什么？',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
          
        const SizedBox(width: 12),
          
        // 历史记录按钮
        GestureDetector(
          onTap: _navigateToHistory,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Image.asset(
              'assets/icon/lishijilu.png',
              width: 28,
              height: 28,
            ),
          ),
        ),
      ],
    );
  }
  
  // 构建分类Tab栏 - 靠左对齐，无底部灰线，减小高度
  Widget _buildCategoryTabs() {
    if (_tabController == null) {
      return const SizedBox(height: 40); // 减小高度
    }
    
    // 直接返回TabBar，不使用任何包装容器
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      labelColor: const Color(0xFF00B0F0), // 蓝色
      unselectedLabelColor: Colors.black87,
      labelStyle: const TextStyle(
        fontSize: 15, // 减小字体大小
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 15, // 减小字体大小
        fontWeight: FontWeight.normal,
      ),
      indicatorColor: const Color(0xFF00B0F0), // 蓝色指示器
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      indicatorPadding: const EdgeInsets.only(bottom: 0), // 调整指示器位置
      padding: const EdgeInsets.only(left: 16.0), // 修改：为TabBar整体添加左边距，您可以调整这个值
      labelPadding: const EdgeInsets.only(right: 24.0), // 修改：调整标签内边距，确保第一个标签与其他标签间隔一致
      tabAlignment: TabAlignment.start, // 确保Tab从左边开始排列
      // 移除点击时的灰色高亮效果
      overlayColor: MaterialStateProperty.all(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      tabs: _categories.map((category) {
        return Tab(
          height: 32, // 减小Tab高度
          text: category['type_name'],
        );
      }).toList(),
      // 移除底部分割线
      dividerColor: Colors.transparent, // 设置线为透明
      // 使用自定义的圆角指示器
      indicator: RoundedRectIndicator(
        color: const Color(0xFF00B0F0),
        radius: 8.0, // 圆角半径可以根据需要调整
        thickness: 3.0, // 指示器厚度
      ),
    );
  }
  
  // 构建内容区域
  Widget _buildContent() {
    if (_tabController == null) {
      return const SizedBox(); // 减小高度
    }
    return TabBarView(
      controller: _tabController,
      children: List.generate(_categories.length, (index) {
        if (index == 0) {
          // 精选Tab内容
          return RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner区域
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: _loadingBanners
                        ? const SizedBox(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                color: Colors.blue,
                              ),
                            ),
                          )
                        : _banners.isEmpty
                            ? const SizedBox(
                                height: 200,
                                child: Center(
                                  child: Text('暂无Banner数据'),
                                ),
                              )
                            : BannerWidget(
                                banners: _banners,
                                height: 200,
                                onBannerTap: _navigateToVideoDetail,
                              ),
                  ),
                  // 热门新番区域
                  _loadingHotVedios
                      ? const SizedBox(
                          height: 200,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: Colors.blue,
                            ),
                          ),
                        )
                      : _hotVedios.isEmpty
                          ? const SizedBox(
                              height: 200,
                              child: Center(
                                child: Text('暂无热门视频数据'),
                              ),
                            )
                          : HotVedioModule(
                              hotVedios: _hotVedios,
                              onTapItem: _navigateToVideoDetail,
                            ),
                  const SizedBox(height: 1),
                  // 分类内容区域
                  for (int i = 1; i < _categories.length; i++)
                    ClassifyModule(
                      title: _categories[i]['type_name'],
                      typeId: _categories[i]['type_id'],
                      onItemTap: _navigateToVideoDetail,
                      onMoreTap: () {
                        // 切换到对应TabBar分类
                        _tabController?.animateTo(i);
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        } else {
          // 其它分类内容区：顶部扩展筛选+视频列表
          final category = _categories[index];
          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ClassifyWithFilterModule(
                    typeId: category['type_id'],
              title: category['type_name'],
            ),
          );
        }
      }),
    );
  }
}
