import 'package:flutter/material.dart';
import 'package:ovofun/utils/steganography_decoder.dart';
import 'dart:convert';

/// 隐写术测试页面 - 用于测试从图片中解码配置
class TestSteganographyPage extends StatefulWidget {
  const TestSteganographyPage({Key? key}) : super(key: key);

  @override
  State<TestSteganographyPage> createState() => _TestSteganographyPageState();
}

class _TestSteganographyPageState extends State<TestSteganographyPage> {
  bool _isLoading = false;
  bool _hasData = false;
  String _statusMessage = '等待测试...';
  Map<String, dynamic>? _config;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 自动开始测试
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testDecode();
    });
  }

  /// 测试解码
  Future<void> _testDecode() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在从图片中提取配置...';
      _errorMessage = null;
      _hasData = false;
    });

    try {
      // 从图片加载配置
      final config = await StegConfigManager.loadConfig(
        imagePath: 'assets/image/config_hidden.png',
        useCache: false, // 不使用缓存，每次重新解码
      );

      if (config != null) {
        setState(() {
          _config = config;
          _hasData = true;
          _statusMessage = '✅ 解码成功！';
          _isLoading = false;
        });

        // 打印配置
        print('=' * 60);
        print('测试解码成功！配置内容：');
        print(JsonEncoder.withIndent('  ').convert(config));
        print('=' * 60);
      } else {
        setState(() {
          _statusMessage = '❌ 解码失败';
          _errorMessage = '无法从图片中提取配置信息';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ 发生错误';
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('隐写术解码测试'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _testDecode,
            tooltip: '重新测试',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态卡片
          _buildStatusCard(),
          const SizedBox(height: 20),

          // 配置详情
          if (_hasData && _config != null) ...[
            _buildConfigCard(),
            const SizedBox(height: 20),
            _buildDetailsCard(),
          ],

          // 错误信息
          if (_errorMessage != null) _buildErrorCard(),

          // 操作按钮
          const SizedBox(height: 20),
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// 状态卡片
  Widget _buildStatusCard() {
    Color statusColor = _hasData ? Colors.green : (_errorMessage != null ? Colors.red : Colors.blue);
    IconData statusIcon = _hasData ? Icons.check_circle : (_errorMessage != null ? Icons.error : Icons.info);

    return Card(
      elevation: 4,
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(statusIcon, size: 32, color: statusColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  if (_isLoading)
                    const Text(
                      '请稍候...',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 配置卡片
  Widget _buildConfigCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '基础配置',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildConfigItem('版本', _config!['version']),
            _buildConfigItem('域名配置URL', _config!['domain_config_url']),
            _buildConfigItem('默认API域名', _config!['default_api_domain']),
            _buildConfigItem('加密密钥', _config!['encrypt_key']),
          ],
        ),
      ),
    );
  }

  /// 详细配置卡片
  Widget _buildDetailsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  '详细配置',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),

            // 友盟配置
            if (_config!['umeng'] != null) ...[
              const Text(
                '友盟统计:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue),
              ),
              const SizedBox(height: 8),
              _buildConfigItem('Android Key', _config!['umeng']['android_key']),
              _buildConfigItem('iOS Key', _config!['umeng']['ios_key']),
              _buildConfigItem('应用名称', _config!['umeng']['app_name']),
              const SizedBox(height: 12),
            ],

            // 广告配置
            if (_config!['ad'] != null) ...[
              const Text(
                '广告配置:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.orange),
              ),
              const SizedBox(height: 8),
              _buildConfigItem('Android ID', _config!['ad']['android_id']),
              _buildConfigItem('iOS ID', _config!['ad']['ios_id']),
              _buildConfigItem('HarmonyOS ID', _config!['ad']['ohos_id']),
              _buildConfigItem('包名', _config!['ad']['package_name']),
              const SizedBox(height: 12),
            ],

            // 备用域名
            if (_config!['backup_domains'] != null) ...[
              const Text(
                '备用域名:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.purple),
              ),
              const SizedBox(height: 8),
              ...((_config!['backup_domains'] as List).map((domain) => Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            domain.toString(),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ))),
              const SizedBox(height: 12),
            ],

            // 功能开关
            if (_config!['features'] != null) ...[
              const Text(
                '功能开关:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.teal),
              ),
              const SizedBox(height: 8),
              _buildSwitchItem('启用广告', _config!['features']['enable_ads']),
              _buildSwitchItem('启用数据分析', _config!['features']['enable_analytics']),
              _buildSwitchItem('调试模式', _config!['features']['debug_mode']),
            ],
          ],
        ),
      ),
    );
  }

  /// 错误卡片
  Widget _buildErrorCard() {
    return Card(
      elevation: 4,
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  '错误信息',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 14, color: Colors.red),
            ),
            const SizedBox(height: 12),
            const Text(
              '可能的原因：',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text('• 图片不存在或路径错误', style: TextStyle(fontSize: 12)),
            const Text('• 图片未包含隐写数据', style: TextStyle(fontSize: 12)),
            const Text('• 图片格式不正确（需要PNG）', style: TextStyle(fontSize: 12)),
            const Text('• 图片已被压缩或修改', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _testDecode,
          icon: const Icon(Icons.refresh),
          label: const Text('重新测试'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        if (_hasData)
          ElevatedButton.icon(
            onPressed: () {
              StegConfigManager.printConfig();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('配置已打印到控制台')),
              );
            },
            icon: const Icon(Icons.print),
            label: const Text('打印配置到控制台'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            _showJsonDialog();
          },
          icon: const Icon(Icons.code),
          label: const Text('查看原始JSON'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  /// 配置项
  Widget _buildConfigItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value?.toString() ?? 'null',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// 开关项
  Widget _buildSwitchItem(String label, dynamic value) {
    final isEnabled = value == true;
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        children: [
          Icon(
            isEnabled ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isEnabled ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 8),
          Text(
            isEnabled ? '(开启)' : '(关闭)',
            style: TextStyle(
              fontSize: 12,
              color: isEnabled ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示JSON对话框
  void _showJsonDialog() {
    if (_config == null) return;

    final jsonString = JsonEncoder.withIndent('  ').convert(_config);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('原始JSON数据'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonString,
              style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

