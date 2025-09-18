import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 我的消息页面
class MessagesPage extends StatefulWidget {
  const MessagesPage({Key? key}) : super(key: key);

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 16,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '我的消息',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            onPressed: () => _showMoreOptions(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey[600],
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: '系统通知'),
            Tab(text: '互动消息'),
            Tab(text: '活动公告'),
            Tab(text: '更新提醒'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSystemNotifications(),
          _buildInteractionMessages(),
          _buildActivityAnnouncements(),
          _buildUpdateReminders(),
        ],
      ),
    );
  }

  Widget _buildSystemNotifications() {
    return _buildEmptyState(
      icon: Icons.notifications_outlined,
      title: '暂无系统通知',
      subtitle: '系统消息将在这里显示',
      actionText: '刷新',
      onActionTap: () => _showComingSoon('刷新功能'),
    );
  }

  Widget _buildInteractionMessages() {
    return _buildEmptyState(
      icon: Icons.chat_bubble_outline,
      title: '暂无互动消息',
      subtitle: '点赞、评论、回复等消息将在这里显示',
      actionText: '查看设置',
      onActionTap: () => _showComingSoon('消息设置'),
    );
  }

  Widget _buildActivityAnnouncements() {
    return _buildEmptyState(
      icon: Icons.campaign_outlined,
      title: '暂无活动公告',
      subtitle: '最新活动和公告将在这里显示',
      actionText: '查看往期',
      onActionTap: () => _showComingSoon('历史公告'),
    );
  }

  Widget _buildUpdateReminders() {
    return _buildEmptyState(
      icon: Icons.system_update_outlined,
      title: '暂无更新提醒',
      subtitle: '版本更新和功能升级消息将在这里显示',
      actionText: '检查更新',
      onActionTap: () => _checkForUpdates(),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onActionTap,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(icon, size: 50, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: onActionTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryColor),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  actionText,
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            _buildFeaturePreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePreview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.upcoming_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '即将上线',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• 实时消息推送\n• 个性化通知设置\n• 消息分类管理\n• 已读/未读状态\n• 消息搜索功能',
            style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.6),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.mark_email_read_outlined,
                    color: Colors.grey[600],
                  ),
                  title: const Text('全部标为已读'),
                  onTap: () {
                    Navigator.pop(context);
                    _showComingSoon('标记已读');
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.notifications_outlined,
                    color: Colors.grey[600],
                  ),
                  title: const Text('通知设置'),
                  onTap: () {
                    Navigator.pop(context);
                    _showComingSoon('通知设置');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.grey[600]),
                  title: const Text('清空消息'),
                  onTap: () {
                    Navigator.pop(context);
                    _showClearConfirmDialog();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('清空消息'),
            content: const Text('确定要清空所有消息吗？此操作不可撤销。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('取消', style: TextStyle(color: Colors.grey[600])),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showComingSoon('清空消息');
                },
                child: Text(
                  '确定',
                  style: TextStyle(color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
    );
  }

  void _checkForUpdates() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                const Text('正在检查更新...'),
              ],
            ),
          ),
    );

    // 模拟检查更新
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已是最新版本'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    });
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature功能即将上线，敬请期待！'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}
