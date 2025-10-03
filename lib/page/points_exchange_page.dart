import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api/ssl_Management.dart';
import '../models/user_model.dart';

/// 积分兑换页面
class PointsExchangePage extends StatefulWidget {
  const PointsExchangePage({super.key});

  @override
  PointsExchangePageState createState() => PointsExchangePageState();
}

class PointsExchangePageState extends State<PointsExchangePage> {
  List<MemberPackage> _packages = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  /// 加载会员套餐列表
  Future<void> _loadPackages() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final response = await OvoApiManager.getPackageList();
      
      if (response['code'] == 0) {
        final packagesData = response['data']['packages'] as List;
        _packages = packagesData.map((pkg) => MemberPackage.fromJson(pkg)).toList();
      } else {
        _errorMessage = response['msg'] ?? '获取套餐列表失败';
      }
    } catch (e) {
      _errorMessage = '网络错误: ${e.toString()}';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 兑换积分
  Future<void> _exchangePoints(MemberPackage package) async {
    final userStore = Provider.of<UserStore>(context, listen: false);
    final user = userStore.user;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请先登录')),
      );
      return;
    }

    // 检查积分是否足够
    if (user.xp < package.pointsPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('积分不足！需要 ${package.pointsPrice} 积分，当前只有 ${user.xp} 积分'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 显示确认对话框
    final confirmed = await _showConfirmDialog(package, user);
    if (!confirmed) return;

    try {
      // 显示加载对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('兑换中...'),
            ],
          ),
        ),
      );

      final response = await OvoApiManager.exchangePoints(package.id);
      
      // 关闭加载对话框
      Navigator.of(context).pop();

      if (response['code'] == 0) {
        // 兑换成功，刷新用户信息
        await userStore.refreshUserProfile();
        
        // 显示成功对话框
        _showSuccessDialog(response['data']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['msg'] ?? '兑换失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 关闭加载对话框
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('兑换失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 显示确认对话框
  Future<bool> _showConfirmDialog(MemberPackage package, User user) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认兑换'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('套餐：${package.name}'),
            Text('时长：${package.durationDays}天'),
            Text('消耗积分：${package.pointsPrice}'),
            Text('当前积分：${user.xp}'),
            Text('兑换后积分：${user.xp - package.pointsPrice}'),
            SizedBox(height: 16),
            Text('确定要兑换此套餐吗？', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('确认兑换'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// 显示成功对话框
  void _showSuccessDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('兑换成功'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('套餐：${data['package_name']}'),
            Text('时长：${data['duration_days']}天'),
            Text('消耗积分：${data['points_used']}'),
            Text('剩余积分：${data['remaining_points']}'),
            Text('到期时间：${data['end_time_formatted']}'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // 返回上一页
            },
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('积分兑换'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(_errorMessage, style: TextStyle(color: Colors.grey)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPackages,
              child: Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无可兑换的套餐', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildUserPointsHeader(),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _packages.length,
            itemBuilder: (context, index) => _buildPackageCard(_packages[index]),
          ),
        ),
      ],
    );
  }

  /// 构建用户积分头部
  Widget _buildUserPointsHeader() {
    return Consumer<UserStore>(
      builder: (context, userStore, child) {
        final user = userStore.user;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Text(
                '当前积分',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '${user?.xp ?? 0}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                user?.groupName ?? '游客',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建套餐卡片
  Widget _buildPackageCard(MemberPackage package) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 推荐标签
          if (package.isRecommend)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Text(
                  '推荐',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            package.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            package.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${package.pointsPrice}积分',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          '${package.durationDays}天',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // 特性列表
                if (package.features.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: package.features.take(3).map((feature) => Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        feature,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    )).toList(),
                  ),
                  SizedBox(height: 12),
                ],
                // 兑换按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _exchangePoints(package),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('立即兑换'),
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

/// 会员套餐数据模型
class MemberPackage {
  final int id;
  final String name;
  final String code;
  final String type;
  final int durationDays;
  final int pointsPrice;
  final double originalPrice;
  final double discountPrice;
  final String description;
  final List<String> features;
  final bool isRecommend;

  MemberPackage({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.durationDays,
    required this.pointsPrice,
    required this.originalPrice,
    required this.discountPrice,
    required this.description,
    required this.features,
    required this.isRecommend,
  });

  factory MemberPackage.fromJson(Map<String, dynamic> json) {
    // 适配原来的套餐API数据结构 (qwq_group表)
    return MemberPackage(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['group_name'] ?? '', // 使用group_name作为code
      type: 'custom', // 默认类型
      durationDays: json['validity_days'] ?? 0, // 使用validity_days
      pointsPrice: json['credits'] ?? 0, // 使用credits作为积分价格
      originalPrice: 0.0, // 原价格，原API没有此字段
      discountPrice: 0.0, // 折扣价格，原API没有此字段
      description: json['description'] ?? '',
      features: [], // 特性列表，原API没有此字段
      isRecommend: (json['sort_order'] ?? 0) == 3, // 年度会员设为推荐
    );
  }
}
