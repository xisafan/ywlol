import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import '../services/api/ssl_Management.dart';
import '../models/user_model.dart';
import 'package:provider/provider.dart';

class DailyCheckinPage extends StatefulWidget {
  const DailyCheckinPage({Key? key}) : super(key: key);

  @override
  State<DailyCheckinPage> createState() => _DailyCheckinPageState();
}

class _DailyCheckinPageState extends State<DailyCheckinPage> {
  bool _isLoading = true;
  bool _isCheckedIn = false;
  bool _isProcessing = false; // 签到处理中
  
  // 签到统计数据
  Map<String, dynamic>? _checkinStats;
  List<CheckinRecord> _checkinHistory = [];
  List<CheckinRankItem> _rankingList = [];
  
  // 从stats中提取的便捷属性，确保类型转换
  int get _currentStreak {
    final value = _checkinStats?['stats']?['current_consecutive_days'];
    if (value == null) return 0;
    return value is int ? value : int.tryParse(value.toString()) ?? 0;
  }
  
  int get _totalDays {
    final value = _checkinStats?['stats']?['total_checkin_days'];
    if (value == null) return 0;
    return value is int ? value : int.tryParse(value.toString()) ?? 0;
  }
  
  int get _todayPoints {
    final value = _checkinStats?['next_reward']?['points_reward'];
    if (value == null) return 5;
    return value is int ? value : int.tryParse(value.toString()) ?? 5;
  }

  @override
  void initState() {
    super.initState();
    _loadCheckinData();
  }

  /// 加载签到数据
  Future<void> _loadCheckinData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 并行加载签到统计和排行榜数据
      final results = await Future.wait([
        OvoApiManager.getCheckinStats(),
        OvoApiManager.getCheckinRanking(limit: 10),
      ]);

      final statsResponse = results[0];
      final rankingResponse = results[1];

      if (statsResponse['code'] == 0) {
        _checkinStats = statsResponse['data'];
        _isCheckedIn = _checkinStats?['is_today_checked'] ?? false;
        
        // 处理签到历史数据
        final recentHistory = _checkinStats?['recent_history'] as List<dynamic>? ?? [];
        _checkinHistory = _generateCheckinHistory(recentHistory);
      } else {
        _showErrorSnackBar('获取签到数据失败: ${statsResponse['msg']}');
      }

      if (rankingResponse['code'] == 0) {
        final rankings = rankingResponse['data']?['rankings'] as List<dynamic>? ?? [];
        _rankingList = rankings.map((item) => CheckinRankItem.fromJson(item)).toList();
      } else {
        _showErrorSnackBar('获取排行榜失败: ${rankingResponse['msg']}');
      }

    } catch (e) {
      _showErrorSnackBar('加载数据异常: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 生成签到历史（最近7天）
  List<CheckinRecord> _generateCheckinHistory(List<dynamic> recentHistory) {
    final history = <CheckinRecord>[];
    final today = DateTime.now();
    
    // 创建最近7天的日期列表
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      // 查找该日期是否有签到记录
      final record = recentHistory.firstWhere(
        (item) => item['checkin_date'] == dateStr,
        orElse: () => null,
      );
      
      if (record != null) {
        // 确保类型转换
        final pointsEarned = record['points_earned'];
        final points = pointsEarned is int ? pointsEarned : int.tryParse(pointsEarned.toString()) ?? 0;
        
        final isMakeupValue = record['is_补签'];
        final isMakeup = isMakeupValue == 1 || isMakeupValue == '1';
        
        history.add(CheckinRecord(
          date: date,
          points: points,
          isChecked: true,
          isMakeup: isMakeup,
        ));
      } else {
        // 如果是今天且未签到，显示未签到状态
        history.add(CheckinRecord(
          date: date,
          points: i == 0 ? _todayPoints : 0, // 今天显示预期积分
          isChecked: false,
        ));
      }
    }
    
    return history;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 30,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.arrow_back, color: Colors.white, size: 12),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          '每日签到',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(height: 16),
                  Text(
                    '加载签到数据中...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  // 签到状态卡片
                  _buildCheckinStatusCard(),
                  SizedBox(height: 12),
                  // 签到统计
                  _buildCheckinStats(),
                  SizedBox(height: 12),
                  // 签到历史
                  _buildCheckinHistory(),
                  SizedBox(height: 12),
                  // 签到奖励说明
                  _buildRewardInfo(),
                  SizedBox(height: 12),
                  // 签到排行榜
                  _buildCheckinRanking(),
                ],
              ),
            ),
    );
  }

  Widget _buildCheckinStatusCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          children: [
            // 签到图标
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                _isCheckedIn ? Icons.check_circle : Icons.calendar_today,
                color: Colors.white,
                size: 30,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _isCheckedIn ? '今日已签到' : '点击签到',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              _isCheckedIn ? '已获得 $_todayPoints 积分' : '签到可获得 $_todayPoints 积分',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            // 签到按钮
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isCheckedIn || _isProcessing) ? null : _performCheckin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_isCheckedIn || _isProcessing) ? Colors.grey : Colors.white,
                  foregroundColor: (_isCheckedIn || _isProcessing) ? Colors.white : AppTheme.primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '签到中...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _isCheckedIn ? '已完成签到' : '立即签到',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckinStats() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                title: '连续签到',
                value: '$_currentStreak',
                unit: '天',
                icon: Icons.local_fire_department,
                color: Colors.orange,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey[200],
            ),
            Expanded(
              child: _buildStatItem(
                title: '累计签到',
                value: '$_totalDays',
                unit: '天',
                icon: Icons.calendar_month,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 8),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: unit,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckinHistory() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '签到记录',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            // 日历视图
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _checkinHistory.map((record) {
                return _buildCalendarDay(record);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarDay(CheckinRecord record) {
    bool isToday = _isSameDay(record.date, DateTime.now());
    bool isChecked = record.isChecked || (isToday && _isCheckedIn);
    
    return Column(
      children: [
        Text(
          _getWeekdayName(record.date.weekday),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 4),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isChecked 
                ? (isToday ? AppTheme.primaryColor : Colors.green)
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
            border: isToday && !isChecked 
                ? Border.all(color: AppTheme.primaryColor, width: 2)
                : null,
          ),
          child: Center(
            child: isChecked
                ? Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${record.date.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isToday ? AppTheme.primaryColor : Colors.grey[600],
                    ),
                  ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          isChecked ? '+${record.points}' : '',
          style: TextStyle(
            fontSize: 10,
            color: Colors.green,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRewardInfo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                SizedBox(width: 8),
                Text(
                  '签到奖励说明',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildRewardRule('每日签到', '获得5-30积分'),
            _buildRewardRule('连续3天', '额外奖励10积分'),
            _buildRewardRule('连续7天', '额外奖励30积分'),
            _buildRewardRule('连续30天', '额外奖励100积分'),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardRule(String condition, String reward) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '$condition：$reward',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 执行签到
  Future<void> _performCheckin() async {
    if (_isProcessing || _isCheckedIn) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final response = await OvoApiManager.checkin();
      
      if (response['code'] == 0) {
        final data = response['data'];
        
        // 显示签到成功对话框
        _showCheckinSuccessDialog(data);
        
        // 刷新用户数据和签到数据
        await Future.wait([
          _refreshUserProfile(),
          _loadCheckinData(),
        ]);
        
      } else {
        _showErrorSnackBar('签到失败: ${response['msg']}');
      }
      
    } catch (e) {
      _showErrorSnackBar('签到异常: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// 显示签到成功对话框
  void _showCheckinSuccessDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text('签到成功！'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSuccessInfoRow('获得积分', '${_safeParseInt(data['points_earned'])} 分'),
              _buildSuccessInfoRow('连续天数', '${_safeParseInt(data['consecutive_days'])} 天'),
              _buildSuccessInfoRow('奖励类型', data['reward_name']?.toString() ?? '每日签到'),
              _buildSuccessInfoRow('签到日期', data['checkin_date']?.toString() ?? '今天'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('确定', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        );
      },
    );
  }

  /// 构建成功信息行
  Widget _buildSuccessInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// 刷新用户资料
  Future<void> _refreshUserProfile() async {
    try {
      final userStore = Provider.of<UserStore>(context, listen: false);
      await userStore.refreshUserProfile();
    } catch (e) {
      print('刷新用户资料失败: $e');
    }
  }

  /// 显示错误提示
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// 安全的整数解析方法
  int _safeParseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return weekdays[weekday - 1];
  }

  // 构建签到排行榜
  Widget _buildCheckinRanking() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.leaderboard, color: AppTheme.primaryColor, size: 20),
                SizedBox(width: 8),
                Text(
                  '签到排行榜',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Spacer(),
                Text(
                  'TOP 10',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _rankingList.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey[100],
              indent: 56,
            ),
            itemBuilder: (context, index) {
              final item = _rankingList[index];
              return _buildRankingItem(item);
            },
          ),
        ],
      ),
    );
  }

  // 构建排行榜单项
  Widget _buildRankingItem(CheckinRankItem item) {
    Color rankColor = Colors.grey[600]!;
    Widget rankWidget;
    
    // 根据排名设置不同的样式
    if (item.rank == 1) {
      rankColor = Color(0xFFFFD700); // 金色
      rankWidget = Icon(Icons.looks_one, color: rankColor, size: 20);
    } else if (item.rank == 2) {
      rankColor = Color(0xFFC0C0C0); // 银色
      rankWidget = Icon(Icons.looks_two, color: rankColor, size: 20);
    } else if (item.rank == 3) {
      rankColor = Color(0xFFCD7F32); // 铜色
      rankWidget = Icon(Icons.looks_3, color: rankColor, size: 20);
    } else {
      rankWidget = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            '${item.rank}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    // 判断是否是当前用户
    final userStore = Provider.of<UserStore>(context, listen: false);
    bool isCurrentUser = userStore.user != null && 
                        (item.username == userStore.user!.username || 
                         item.username == userStore.user!.nickname);

    return Container(
      color: isCurrentUser ? AppTheme.primaryColor.withOpacity(0.05) : Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 排名
            SizedBox(
              width: 24,
              child: rankWidget,
            ),
            SizedBox(width: 12),
            // 头像
            ClipOval(
              child: item.avatar != null && item.avatar!.isNotEmpty
                  ? Image.network(
                      item.avatar!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person, color: Colors.grey[600], size: 18),
                        );
                      },
                    )
                  : Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: Colors.grey[600], size: 18),
                    ),
            ),
            SizedBox(width: 12),
            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrentUser ? FontWeight.w600 : FontWeight.w500,
                      color: isCurrentUser ? AppTheme.primaryColor : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    '最后签到: ${item.lastCheckinRelative}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            // 连续签到天数
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: rankColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: rankColor.withOpacity(0.3), width: 1),
              ),
              child: Text(
                '连续${item.consecutiveDays}天',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: rankColor == Colors.grey[600] ? AppTheme.primaryColor : rankColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckinRecord {
  final DateTime date;
  final int points;
  bool isChecked;
  final bool isMakeup; // 是否为补签

  CheckinRecord({
    required this.date,
    required this.points,
    required this.isChecked,
    this.isMakeup = false,
  });
}

class CheckinRankItem {
  final int rank;
  final String username;
  final String nickname;
  final String? avatar;
  final int consecutiveDays;
  final int totalDays;
  final String lastCheckinTime;
  final String lastCheckinRelative;

  CheckinRankItem({
    required this.rank,
    required this.username,
    required this.nickname,
    this.avatar,
    required this.consecutiveDays,
    required this.totalDays,
    required this.lastCheckinTime,
    required this.lastCheckinRelative,
  });

  factory CheckinRankItem.fromJson(Map<String, dynamic> json) {
    // 安全的整数类型转换函数
    int safeParseInt(dynamic value, [int defaultValue = 0]) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    return CheckinRankItem(
      rank: safeParseInt(json['ranking']),
      username: json['username']?.toString() ?? 'unknown',
      nickname: json['nickname']?.toString() ?? json['username']?.toString() ?? 'unknown',
      avatar: json['avatar']?.toString(),
      consecutiveDays: safeParseInt(json['current_consecutive_days']),
      totalDays: safeParseInt(json['total_checkin_days']),
      lastCheckinTime: json['last_checkin_formatted']?.toString() ?? '',
      lastCheckinRelative: json['last_checkin_relative']?.toString() ?? '',
    );
  }

  String get displayName => nickname.isNotEmpty ? nickname : username;
}
