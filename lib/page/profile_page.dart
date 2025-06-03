import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'login_page.dart';
import 'history_page.dart';
import 'package:ovofun/page/vedios.dart'; // 导入视频详情页
import 'package:ovofun/page/models/color_models.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
//111111
class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _user;
  List<WatchHistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await UserStore().loadUser();
      await UserStore().loadWatchHistory();
      setState(() {
        _user = UserStore().user;
        _history = UserStore().watchHistory;
        _isLoading = false;
      });
    } catch (e) {
      print('加载用户数据失败: $e');
      setState(() {
        _user = null;
        _history = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('退出登录'),
        content: Text('确定要退出登录吗？'),
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
        await UserStore().logout();
        setState(() {
          _user = null;
          _history = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已退出登录')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('退出登录失败: ${e.toString()}')),
        );
      }
    }
  }

  void _navigateToLogin() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LoginPage(
          onLoginSuccess: (user) {
            _loadUserData();
          },
        ),
      ),
    );
    if (result == true) {
      _loadUserData();
    }
  }

  void _navigateToHistory() {
    if (_user == null) {
      _showLoginRequiredDialog();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HistoryPage(user: _user!),
      ),
    );
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('需要登录'),
        content: Text('请先登录后再查看历史记录'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToLogin();
            },
            child: Text('去登录'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(child: SizedBox()),
            IconButton(
              icon: Icon(Icons.brightness_6_outlined, color: Colors.black87),
              onPressed: () {
                final isDark = AdaptiveTheme.of(context).mode.isDark;
                if (isDark) {
                  AdaptiveTheme.of(context).setLight();
                } else {
                  AdaptiveTheme.of(context).setDark();
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.settings_outlined, color: Colors.black87),
              onPressed: () {}, // 设置功能后续实现
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBlock() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Row(
            children: [
              // 头像
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
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
              const SizedBox(width: 16),
              // 用户名和状态
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user != null && _user!.nickname.isNotEmpty
                          ? _user!.nickname
                          : (_user != null && _user!.username.isNotEmpty ? _user!.username : '登录'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    if (_user != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '普通用户',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 右侧箭头
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.chevron_right, color: Colors.grey),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  // 赞助卡片
  Widget _buildSponsorCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              Color(0xFFFA8BFF),
              Color(0xFF2BD2FF),
              Color(0xFF2BFF88),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Text(
                  '支持我们，帮助平台持续运营',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: ElevatedButton(
                onPressed: () {
                  // 这里可以弹出赞助二维码或跳转赞助页
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  elevation: 0,
                ),
                child: Text(
                  '赞助',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final List<Map<String, String>> actions = [
      {
        'icon': 'assets/icon/yizhuifan.png',
        'label': '我的追番',
      },
      {
        'icon': 'assets/icon/work.png',
        'label': '任务中心',
      },
      {
        'icon': 'assets/icon/mydown.png',
        'label': '我的下载',
      },
      {
        'icon': 'assets/icon/mymessage.png',
        'label': '我的信息',
      },
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions.map((action) {
          return Expanded(
            child: GestureDetector(
              onTap: () {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    action['icon']!,
                    width: 32,
                    height: 32,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action['label']!,
                    style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHistoryBlock() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_user != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => HistoryPage(user: _user!),
            ),
          );
        }
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Row(
              children: [
                Text(
                  '观看历史',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: Colors.grey),
                  onPressed: () {
                    if (_user != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => HistoryPage(user: _user!),
                        ),
                      );
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),
          Container(
            height: 90,
            margin: const EdgeInsets.only(top: 0),
            child: _history.isEmpty
                ? Center(
              child: Text(
                '暂无历史记录',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
                : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _history.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                final item = _history[index];
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => VideoDetailPage(
                          vodId: int.tryParse(item.videoId) ?? 0,
                          initialEpisodeIndex: item.episodeIndex,
                        ),
                      ),
                    );
                  },
                  child: _buildHistoryItem(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(WatchHistoryItem item) {
    String formatDuration(int seconds) {
      final m = (seconds ~/ 60).toString().padLeft(2, '0');
      final s = (seconds % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    return Container(
      width: 105,
      height: 90,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      item.videoCover,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/image/touxiang.jpg',
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 3,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '已看到${formatDuration(item.positionSeconds)}',
                        style: TextStyle(fontSize: 9, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.videoTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color),
          ),
          Text(
            '第${item.episodeIndex + 1}集',
            style: TextStyle(fontSize: 9, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadUserData,
        child: ListView(
          physics: AlwaysScrollableScrollPhysics(),
          children: [
            _buildAppBar(),
            _buildUserBlock(),
            _buildSponsorCard(),
            _buildHistoryBlock(),
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }
}
