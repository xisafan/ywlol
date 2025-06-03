import 'package:flutter/material.dart';
import 'package:ovofun/services/api/ssl_Management.dart';
import 'package:ovofun/page/models/color_models.dart';

class SchedulePage extends StatefulWidget {
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}
// mapapp
class _SchedulePageState extends State<SchedulePage> {
  final OvoApiManager _apiManager = OvoApiManager();
  int _selectedDay = DateTime.now().weekday; // 1-7
  Map<String, List<dynamic>> _scheduleData = {};
  bool _loading = true;
  String? _error;

  final List<String> _weekDays = ['一', '二', '三', '四', '五', '六', '日'];
  final List<String> _dateLabels = [];

  late final PageController _pageController = PageController(initialPage: _selectedDay - 1);

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _apiManager.getSchedule();
      setState(() {
        _scheduleData = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: ${e.toString()}';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 顶部背景图+渐隐
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
          // 标题，和ranking_page一致
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 16),
                Center(
                  child: Text(
                    '排期表',
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
              ],
            ),
          ),
          // 内容区
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 56), // 顶部留出标题空间，和ranking_page一致
                _loading
                    ? Expanded(child: Center(child: CircularProgressIndicator(color: Colors.pink)))
                    : _error != null
                        ? Expanded(child: Center(child: Text(_error!, style: TextStyle(color: Colors.red))))
                        : Expanded(
                            child: Column(
                              children: [
                                _buildWeekBar(),
                                Expanded(child: _buildScheduleList()),
                              ],
                            ),
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekBar() {
    final today = DateTime.now();
    // 计算本周的日期
    List<DateTime> weekDates = List.generate(7, (i) {
      return today.subtract(Duration(days: today.weekday - 1 - i));
    });
    // 让周选择栏高度固定，防止动画时跳动
    return SizedBox(
      height: 54, // 可根据实际视觉微调
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final date = weekDates[i];
          final isSelected = (_selectedDay == i + 1);
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDay = i + 1;
                _pageController.jumpToPage(i);
              });
            },
            child: Column(
              children: [
                AnimatedDefaultTextStyle(
                  duration: Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? kPrimaryColor : kTextColor,
                    fontSize: isSelected ? 14 : 12,
                    height: 1.3,
                  ),
                  child: Text('周${_weekDays[i]}'),
                ),
                SizedBox(height: 1),
                AnimatedDefaultTextStyle(
                  duration: Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  style: TextStyle(
                    color: isSelected ? kPrimaryColor : kSecondaryTextColor,
                    fontSize: isSelected ? 11 : 9,
                    height: 1.3,
                  ),
                  child: Text('${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
                ),
                SizedBox(height: 1),
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)),
                  child: isSelected
                      ? Container(
                          key: ValueKey('dot_$i'),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: kPrimaryColor,
                            shape: BoxShape.circle,
                          ),
                        )
                      : SizedBox.shrink(key: ValueKey('empty_$i')),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildScheduleList() {
    final dayKey = _selectedDay.toString();
    final list = _scheduleData[dayKey] ?? [];
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: Colors.pink));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: Colors.red)));
    }
    return PageView.builder(
      controller: _pageController,
      itemCount: 7,
      onPageChanged: (i) {
        setState(() {
          _selectedDay = i + 1;
        });
      },
      itemBuilder: (context, i) {
        final key = (i + 1).toString();
        final dayList = _scheduleData[key] ?? [];
        if (dayList.isEmpty) {
          return Center(child: Text('今日暂无番剧', style: TextStyle(color: Colors.grey)));
        }
        return GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 12,
            childAspectRatio: 0.65,
          ),
          itemCount: dayList.length,
          itemBuilder: (context, idx) {
            final item = dayList[idx];
            return _buildAnimeCard(item);
          },
        );
      },
    );
  }

  Widget _buildAnimeCard(dynamic item) {
    final String pic = item['vod_pic'] ?? '';
    final String name = item['vod_name'] ?? '';
    final String remarks = item['vod_remarks'] ?? '';
    return GestureDetector(
      onTap: () {
        // TODO: 跳转到详情页
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 图片独立块
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: pic.isNotEmpty
                    ? Image.network(
                        pic,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          height: 150,
                          color: Colors.grey.shade200,
                          child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
                        ),
                      )
                    : Container(
                        height: 150,
                        color: Colors.grey.shade200,
                        child: Icon(Icons.image, color: Colors.grey, size: 32),
                      ),
              ),
              if (remarks.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.65),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      alignment: Alignment.bottomLeft,
                      padding: EdgeInsets.only(left: 6, bottom: 4, right: 8),
                      child: Text(
                        remarks,
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 0),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}