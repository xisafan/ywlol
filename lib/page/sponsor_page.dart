import 'package:flutter/material.dart';
import 'package:ovofun/theme/app_theme.dart';
import 'package:ovofun/models/user_model.dart';
import 'package:ovofun/models/package_model.dart';
import 'package:ovofun/services/api/ssl_Management.dart';
import 'package:provider/provider.dart';

class SponsorPage extends StatefulWidget {
  const SponsorPage({Key? key}) : super(key: key);

  @override
  State<SponsorPage> createState() => _SponsorPageState();
}

class _SponsorPageState extends State<SponsorPage> {
  int selectedSponsorIndex = 0;
  List<Package> packages = [];
  bool isLoading = true;
  String? errorMessage;
  final TextEditingController _redeemCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  @override
  void dispose() {
    _redeemCodeController.dispose();
    super.dispose();
  }

  // 加载套餐列表
  Future<void> _loadPackages() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await OvoApiManager.getPackageList(
        status: 1, // 只获取启用的套餐
        limit: 20,
      );

      if (response['code'] == 0) {
        final packageResponse = PackageListResponse.fromJson(response['data']);
        setState(() {
          packages = packageResponse.packages;
          isLoading = false;
          // 默认选中第一个套餐
          if (packages.isNotEmpty) {
            selectedSponsorIndex = 0;
          }
        });
      } else {
        setState(() {
          errorMessage = response['msg'] ?? '加载套餐列表失败';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = '加载套餐列表异常: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadPackages,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('重试'),
                      ),
                    ],
                  ),
                )
              : packages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.card_giftcard,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            '暂无可用套餐',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildUserInfoSection(),
                          _buildSponsorSection(),
                          _buildBottomSection(),
                        ],
                      ),
                    ),
    );
  }

  // 构建顶部导航栏（参考我的收藏样式）
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
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
        '权益中心',
        style: TextStyle(
          fontSize: 15, 
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // 构建用户信息区域
  Widget _buildUserInfoSection() {
    return Consumer<UserStore>(
      builder: (context, userStore, child) {
        final user = userStore.user;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withOpacity(0.1),
                Colors.white,
              ],
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: 20),
              // 用户头像和信息
              Row(
                children: [
                  SizedBox(width: 16),
                  // 用户头像
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: _buildUserAvatar(user),
                    ),
                  ),
                  SizedBox(width: 12),
                  // 用户名和积分
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.nickname ?? '未登录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '积分: ${user?.xp ?? 0}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 获取积分按钮
                  Container(
                    margin: EdgeInsets.only(right: 16),
                    child: ElevatedButton(
                      onPressed: () {
                        _showRedeemCodeDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                        minimumSize: Size(0, 32),
                      ),
                      child: Text(
                        '获取积分',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // 构建用户头像
  Widget _buildUserAvatar(User? user) {
    if (user != null && user.avatar != null && user.avatar!.isNotEmpty) {
      // 显示用户头像
      String avatarUrl = user.avatar!;
      // 如果是相对路径，转换为完整URL
      if (avatarUrl.startsWith('/uploads/')) {
        // 这里可以根据需要添加baseUrl逻辑
        // avatarUrl = baseUrl + avatarUrl;
      }
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar();
        },
      );
    } else if (user != null && user.qq != null && user.qq!.isNotEmpty) {
      // 显示QQ头像
      return Image.network(
        'https://q1.qlogo.cn/g?b=qq&nk=${user.qq}&s=100',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar();
        },
      );
    } else {
      // 显示默认头像
      return _buildDefaultAvatar();
    }
  }

  // 构建默认头像
  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[300],
      child: Icon(
        Icons.person,
        size: 25,
        color: Colors.grey[600],
      ),
    );
  }

  // 构建赞助选项区域
  Widget _buildSponsorSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '使用积分进行赞助',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          // 横向滚动的赞助选项
          Container(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: packages.length,
              itemBuilder: (context, index) {
                Package package = packages[index];
                bool isSelected = selectedSponsorIndex == index;
                
                return Container(
                  width: 130,
                  margin: EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedSponsorIndex = index;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected 
                              ? AppTheme.primaryColor 
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected 
                            ? AppTheme.primaryColor.withOpacity(0.05)
                            : Colors.white,
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  package.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected 
                                        ? AppTheme.primaryColor 
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              if (package.isRecommended)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '推荐',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${package.credits}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected 
                                      ? AppTheme.primaryColor 
                                      : Colors.black87,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '积分',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              package.description.isNotEmpty 
                                  ? package.description 
                                  : '${package.validityDescription}权益',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 构建底部区域
  Widget _buildBottomSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          // 用户协议
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '兑换则代表接受',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: 显示用户协议
                  _showUserAgreement();
                },
                child: Text(
                  '《用户协议》',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.primaryColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // 立即赞助按钮
          Container(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                _handleSponsor();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: Text(
                '立即赞助',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  // 显示用户协议
  void _showUserAgreement() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          '用户协议',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. 赞助服务说明',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '• 赞助服务可为您提供免广告体验\n• 不同赞助类型对应不同的服务时长\n• 赞助期间可享受更流畅的观影体验',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              SizedBox(height: 16),
              Text(
                '2. 积分使用规则',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '• 积分仅可用于应用内服务兑换\n• 兑换后积分不可退还\n• 积分不可转让给其他用户',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              SizedBox(height: 16),
              Text(
                '3. 服务条款',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '• 服务激活后立即生效\n• 我们保留调整服务内容的权利\n• 如有问题请联系客服',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '我知道了',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // 处理赞助
  void _handleSponsor() {
    if (packages.isEmpty) return;
    
    final selectedPackage = packages[selectedSponsorIndex];
    final user = context.read<UserStore>().user;
    final userPoints = user?.xp ?? 0;
    
    // 检查积分是否足够
    if (userPoints < selectedPackage.credits) {
      _showInsufficientPointsDialog();
      return;
    }

    // 显示确认对话框
    _showConfirmSponsorDialog(selectedPackage);
  }

  // 显示积分不足对话框
  void _showInsufficientPointsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          '积分不足',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        content: Text(
          '您当前积分不足，无法完成此次赞助。\n请先获取更多积分。',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '确定',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // 显示确认赞助对话框
  void _showConfirmSponsorDialog(Package package) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          '确认赞助',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('您选择的赞助类型：', style: TextStyle(fontSize: 14)),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '需要积分: ${package.credits}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  Text(
                    package.description.isNotEmpty 
                        ? package.description 
                        : '享受${package.validityDescription}权益',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              '确认后将扣除您的积分并激活对应服务。',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processSponsor(package);
            },
            child: Text(
              '确认赞助',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // 处理赞助逻辑
  Future<void> _processSponsor(Package package) async {
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
              Text('处理中...'),
            ],
          ),
        ),
      );

      // 调用积分兑换API
      final response = await OvoApiManager.exchangePoints(package.id);
      
      // 关闭加载对话框
      Navigator.of(context).pop();

      if (response['code'] == 0) {
        // 兑换成功，刷新用户信息
        final userStore = Provider.of<UserStore>(context, listen: false);
        await userStore.refreshUserProfile();
        
        // 显示成功对话框
        _showSuccessDialog(response['data']);
      } else {
        // 显示错误信息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['msg'] ?? '赞助失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 关闭加载对话框
      Navigator.of(context).pop();
      
      // 显示错误信息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('赞助失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 构建信息行
  Widget _buildInfoRow(String title, String value, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        SizedBox(width: 8),
        Text(
          '$title: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // 显示兑换码输入对话框
  void _showRedeemCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          '兑换积分',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请输入兑换码(长按粘贴)',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _redeemCodeController,
              decoration: InputDecoration(
                hintText: '请输入兑换码',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryColor),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (value) {
                // 可以添加实时验证
              },
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processRedeemCode();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  '立即兑换',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _openGetCodeWebsite();
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '还没有兑换卡？点我立即获取',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 处理兑换码
  Future<void> _processRedeemCode() async {
    final code = _redeemCodeController.text.trim();
    
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请输入兑换码'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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

      // 调用兑换码API
      final response = await OvoApiManager.useRedeemCode(code);
      
      // 关闭加载对话框
      Navigator.of(context).pop();

      if (response['code'] == 0) {
        // 兑换成功，清空输入框
        _redeemCodeController.clear();
        
        // 刷新用户信息
        final userStore = Provider.of<UserStore>(context, listen: false);
        await userStore.refreshUserProfile();
        
        // 显示成功对话框
        _showRedeemSuccessDialog(response['data']);
      } else {
        // 显示错误信息
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
      
      // 显示错误信息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('兑换失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 打开获取兑换码网站
  void _openGetCodeWebsite() {
    // TODO: 使用url_launcher打开网站
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('即将跳转到 http://154.94.227.51:6548/'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
    // 这里可以添加 url_launcher 来打开网站
    // launch('http://154.94.227.51:6548/');
  }

  // 显示兑换成功对话框
  void _showRedeemSuccessDialog(Map<String, dynamic> data) {
    final redeemData = data['redeem_data'];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 60,
            ),
            SizedBox(height: 16),
            Text(
              '兑换成功！',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              data['message'] ?? '兑换成功',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '兑换详情：',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    redeemData['description'] ?? '兑换成功',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // 关闭对话框
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 显示成功对话框
  void _showSuccessDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 60,
            ),
            SizedBox(height: 16),
            Text(
              '赞助成功！',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '您的${data['package_name']}已激活',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('消耗积分', '${data['points_used']}', Icons.remove_circle, Colors.red),
                  SizedBox(height: 8),
                  _buildInfoRow('剩余积分', '${data['remaining_points']}', Icons.account_balance_wallet, Colors.blue),
                  SizedBox(height: 8),
                  _buildInfoRow('有效期', '${data['duration_days']}天', Icons.schedule, Colors.orange),
                  SizedBox(height: 8),
                  _buildInfoRow('到期时间', '${data['end_time_formatted']}', Icons.event, Colors.green),
                ],
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // 关闭对话框
                  Navigator.pop(context); // 返回上一页
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
