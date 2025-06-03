import 'package:flutter/material.dart';
import 'page/home_page.dart';      // 导入拆分后的页面
import 'page/ranking_page.dart';
import 'page/schedule_page.dart';
import 'page/profile_page.dart';
import 'page/vedios.dart';
import 'models/user_model.dart';
import 'dart:async';
// 定时器1
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  bool _showContinueWatch = true;
  Timer? _continueWatchTimer;
  bool _continueWatchSlideOut = false;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(onNavigateToProfile: _onItemTapped),
      RankingPage(),
      SchedulePage(),
      ProfilePage(),
    ];
    _startContinueWatchTimerIfNeeded();
  }

  void _startContinueWatchTimerIfNeeded() {
    if (_showContinueWatch && UserStore().watchHistory.isNotEmpty) {
      _continueWatchTimer?.cancel();
      setState(() { _continueWatchSlideOut = false; });
      _continueWatchTimer = Timer(Duration(seconds: 5), () {
        if (mounted) setState(() { _continueWatchSlideOut = true; });
        Future.delayed(Duration(milliseconds: 400), () {
          if (mounted) setState(() => _showContinueWatch = false);
        });
      });
    }
  }

  @override
  void dispose() {
    _continueWatchTimer?.cancel();
    super.dispose();
  }

  final List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Image.asset(
        'assets/icon/shouyeoff.png',
        width: 24,
        height: 24,
      ),
      activeIcon: Image.asset(
        'assets/icon/shouyeon.png',
        width: 24,
        height: 24,
      ),
      label: '首页'
    ),
    BottomNavigationBarItem(
      icon: Image.asset(
        'assets/icon/paihangoff.png',
        width: 24,
        height: 24,
      ),
      activeIcon: Image.asset(
        'assets/icon/paihangon.png',
        width: 24,
        height: 24,
      ),
      label: '排行榜'
    ),
    BottomNavigationBarItem(
      icon: Image.asset(
        'assets/icon/paiqioff.png',
        width: 24,
        height: 24,
      ),
      activeIcon: Image.asset(
        'assets/icon/paiqion.png',
        width: 24,
        height: 24,
      ),
      label: '排期表'
    ),
    BottomNavigationBarItem(
      icon: Image.asset(
        'assets/icon/wodeoff.png',
        width: 24,
        height: 24,
      ),
      activeIcon: Image.asset(
        'assets/icon/wodeon.png',
        width: 24,
        height: 24,
      ),
      label: '我的'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _pages[_selectedIndex],
          if (_selectedIndex == 0 && _showContinueWatch && UserStore().watchHistory.isNotEmpty)
            Positioned(
              left: 0,
              bottom: 72,
              child: AnimatedSlide(
                offset: _continueWatchSlideOut ? const Offset(-1.1, 0) : Offset.zero,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeIn,
                child: _buildContinueWatchBar(context),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: _navItems,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) _startContinueWatchTimerIfNeeded();
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0: return '首页';
      case 1: return '排行榜';
      case 2: return '排期表';
      case 3: return '我的';
      default: return 'OVOFUN';
    }
  }

  Widget _buildContinueWatchBar(BuildContext context) {
    final history = UserStore().watchHistory.first;
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.horizontal(left: Radius.circular(8), right: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                setState(() { _continueWatchSlideOut = true; });
                Future.delayed(Duration(milliseconds: 400), () {
                  if (mounted) setState(() => _showContinueWatch = false);
                });
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.black54, size: 18),
              ),
            ),
            SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VideoDetailPage(
                      vodId: int.tryParse(history.videoId) ?? 0,
                      initialEpisodeIndex: history.episodeIndex,
                      initialPlayFrom: history.playFrom,
                      initialPositionSeconds: history.positionSeconds,
                    ),
                  ),
                );
              },
              child: Text(
                '继续看《${history.videoTitle.isNotEmpty ? history.videoTitle : '未知'}》',
                style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}