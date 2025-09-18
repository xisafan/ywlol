import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../home.dart';
import '../services/api/ssl_Management.dart';

/// 启动页 - 动态域名选择
class StartupPage extends StatefulWidget {
  @override
  _StartupPageState createState() => _StartupPageState();

  /// 静态方法：显示线路选择页面（用于在设置中调用）
  static void showLineSelection(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => StartupPage()));
  }
}

class _StartupPageState extends State<StartupPage>
    with SingleTickerProviderStateMixin {
  List<String> _domains = [];
  Map<String, int> _pingResults = {};
  bool _isLoading = true;
  bool _isTestingPing = false;
  String? _selectedDomain;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _initStartup();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 初始化启动流程
  Future<void> _initStartup() async {
    // 检查是否已有保存的域名
    final prefs = await SharedPreferences.getInstance();
    final savedDomain = prefs.getString('selected_domain');

    if (savedDomain != null && savedDomain.isNotEmpty) {
      // 直接使用保存的域名进入主页
      _setApiBaseUrl(savedDomain);
      _navigateToHome();
      return;
    }

    // 获取域名列表
    await _fetchDomains();
  }

  /// 获取动态域名列表
  Future<void> _fetchDomains() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await http
          .get(
            Uri.parse('http://dmw.0606666.xyz/dmw.json'),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final domains = List<String>.from(jsonData['domains'] ?? []);

        setState(() {
          _domains = domains.where((domain) => domain.isNotEmpty).toList();
          _isLoading = false;
        });

        // 自动开始ping测试
        if (_domains.isNotEmpty) {
          _startPingTest();
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '获取域名列表失败: ${e.toString()}';
      });
    }
  }

  /// 开始ping测试
  Future<void> _startPingTest() async {
    setState(() {
      _isTestingPing = true;
      _pingResults.clear();
    });

    final List<Future<void>> pingTasks =
        _domains.map((domain) => _pingDomain(domain)).toList();
    await Future.wait(pingTasks);

    setState(() {
      _isTestingPing = false;
    });
  }

  /// ping单个域名
  Future<void> _pingDomain(String domain) async {
    try {
      final cleanDomain =
          domain.replaceAll('https://', '').replaceAll('http://', '').trim();
      if (cleanDomain.isEmpty) return;

      final stopwatch = Stopwatch()..start();

      // 尝试TCP连接测试
      final socket = await Socket.connect(
        cleanDomain,
        80,
        timeout: Duration(seconds: 5),
      );
      await socket.close();

      stopwatch.stop();
      final pingTime = stopwatch.elapsedMilliseconds;

      setState(() {
        _pingResults[domain] = pingTime;
      });
    } catch (e) {
      setState(() {
        _pingResults[domain] = 9999; // 表示连接失败
      });
    }
  }

  /// 选择域名
  void _selectDomain(String domain) {
    setState(() {
      _selectedDomain = domain;
    });
    _setApiBaseUrl(domain);
    _saveSelectedDomain(domain);
    _navigateToHome();
  }

  /// 自动选择延时最低的域名
  void _autoSelectBestDomain() {
    if (_pingResults.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('请等待网络测试完成')));
      return;
    }

    String? bestDomain;
    int bestPing = 9999;

    _pingResults.forEach((domain, ping) {
      if (ping < bestPing && ping < 9999) {
        bestPing = ping;
        bestDomain = domain;
      }
    });

    if (bestDomain != null) {
      _selectDomain(bestDomain!);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('所有线路都无法连接，请检查网络')));
    }
  }

  /// 设置API基础URL
  void _setApiBaseUrl(String domain) {
    final apiUrl =
        domain.endsWith('/') ? '${domain}api.php' : '$domain/api.php';

    // 这里需要设置到API管理器中
    OvoApiManager.setBaseUrl(apiUrl);
  }

  /// 保存选择的域名
  Future<void> _saveSelectedDomain(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_domain', domain);
  }

  /// 跳转到主页
  void _navigateToHome() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => HomeScreen()));
  }

  /// 重新测试
  void _retryTest() {
    _fetchDomains();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/image/screen.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          // 添加半透明遮罩以便文字更清晰
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.4)),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // 顶部空白区域（让开屏图logo自然显示）
                  SizedBox(height: 120),
                  // 线路选择标题
                  _buildTitle(),
                  // 线路选择区域
                  Expanded(child: _buildContent()),
                  // 底部操作区域
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建标题区域
  Widget _buildTitle() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Text(
            '线路选择',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.8),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          Text(
            '请选择最佳线路以获得更好的使用体验',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 3,
                  color: Colors.black.withOpacity(0.8),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 构建主要内容
  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingView();
    }

    if (_error != null) {
      return _buildErrorView();
    }

    return _buildDomainList();
  }

  /// 构建加载视图
  Widget _buildLoadingView() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                SizedBox(height: 24),
                Text(
                  '正在获取线路信息...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.8),
                      ),
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

  /// 构建错误视图
  Widget _buildErrorView() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.8),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  '线路获取失败',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.8),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.8),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _retryTest,
                    icon: Icon(Icons.refresh),
                    label: Text('重新尝试'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Color(0xFF1E3A8A),
                      backgroundColor: Colors.white.withOpacity(0.95),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建域名列表
  Widget _buildDomainList() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // 测试状态提示
          if (_isTestingPing)
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    '正在测试网络延时...',
                    style: TextStyle(
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // 域名列表
          Expanded(
            child: ListView.builder(
              itemCount: _domains.length,
              itemBuilder: (context, index) {
                final domain = _domains[index];
                return _buildDomainItem(domain, index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建单个域名项
  Widget _buildDomainItem(String domain, int lineNumber) {
    final ping = _pingResults[domain];
    final isSelected = _selectedDomain == domain;

    String displayDomain = domain
        .replaceAll('https://', '')
        .replaceAll('http://', '');
    if (displayDomain.endsWith('/')) {
      displayDomain = displayDomain.substring(0, displayDomain.length - 1);
    }

    String statusText = '';
    Color statusColor = Colors.white.withOpacity(0.6);
    IconData statusIcon = Icons.pending;

    if (ping != null) {
      if (ping < 9999) {
        statusText = '${ping}ms';
        if (ping < 100) {
          statusColor = Colors.green;
          statusIcon = Icons.wifi;
        } else if (ping < 300) {
          statusColor = Colors.orange;
          statusIcon = Icons.wifi;
        } else {
          statusColor = Colors.red;
          statusIcon = Icons.wifi_off;
        }
      } else {
        statusText = '连接失败';
        statusColor = Colors.red;
        statusIcon = Icons.wifi_off;
      }
    } else if (_isTestingPing) {
      statusText = '测试中...';
      statusIcon = Icons.hourglass_empty;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectDomain(domain),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(isSelected ? 0.7 : 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 线路编号
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$lineNumber',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black.withOpacity(0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                // 域名信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '线路 $lineNumber',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black.withOpacity(0.8),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        displayDomain,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black.withOpacity(0.8),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 状态指示
                Column(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建底部操作区域
  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          // 自动选择按钮
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _pingResults.isEmpty ? null : _autoSelectBestDomain,
              icon: Icon(Icons.auto_mode),
              label: Text(
                '自动选择最佳线路',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Color(0xFF1E3A8A),
                backgroundColor: Colors.white.withOpacity(0.95),
                disabledBackgroundColor: Colors.white.withOpacity(0.4),
                disabledForegroundColor: Colors.grey,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          SizedBox(height: 16),
          // 重新测试按钮
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black.withOpacity(0.3),
            ),
            child: TextButton.icon(
              onPressed: _isLoading ? null : _retryTest,
              icon: Icon(
                Icons.refresh,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: Colors.black.withOpacity(0.8),
                  ),
                ],
              ),
              label: Text(
                '重新测试',
                style: TextStyle(
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black.withOpacity(0.8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
