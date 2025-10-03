import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api/ssl_Management.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../vedios.dart' show WaveLoadingSpinner;

/// 视频评论页组件
/// 负责评论显示、评论输入、回复等功能
class VideoCommentComponent extends StatefulWidget {
  final int vodId;
  final ValueChanged<bool>? onCommentFocusChanged;

  const VideoCommentComponent({
    Key? key,
    required this.vodId,
    this.onCommentFocusChanged,
  }) : super(key: key);

  @override
  VideoCommentComponentState createState() => VideoCommentComponentState();
}

class VideoCommentComponentState extends State<VideoCommentComponent> {
  final OvoApiManager _apiManager = OvoApiManager();
  
  // 评论相关状态
  final TextEditingController _commentInputController = TextEditingController();
  final FocusNode _commentInputFocusNode = FocusNode();
  bool _isReplying = false;
  int _replyToCommentId = 0;
  String _replyToUserName = '';
  bool _isSendingComment = false;
  
  // 评论数据
  bool _isLoadingComments = false;
  List<dynamic> _commentList = [];
  String? _commentErrorMessage;
  Map<int, bool> _replyExpanded = {};
  
  // 主题色
  Color get _primaryColor => AppTheme.primaryColor;

  @override
  void initState() {
    super.initState();
    _fetchComments();
    
    // 监听输入框焦点变化
    _commentInputFocusNode.addListener(() {
      widget.onCommentFocusChanged?.call(_commentInputFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _commentInputController.dispose();
    _commentInputFocusNode.dispose();
    super.dispose();
  }

  /// 获取评论列表
  Future<void> _fetchComments() async {
    setState(() {
      _isLoadingComments = true;
      _commentErrorMessage = null;
    });

    try {
      final response = await _apiManager.get('/comment/getComments', queryParameters: {
        'vod_id': widget.vodId,
      });

      if (response['code'] == 1) {
        final comments = response['data'] as List;
        setState(() {
          _commentList = comments;
          _isLoadingComments = false;
        });
      } else {
        setState(() {
          _commentErrorMessage = response['msg'] ?? '获取评论失败';
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      print('获取评论失败: $e');
      setState(() {
        _commentErrorMessage = '网络错误，请稍后重试';
        _isLoadingComments = false;
      });
    }
  }

  /// 发送评论
  Future<void> _onSendComment() async {
    // 检查登录状态
    final user = UserStore().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请先登录后再评论')),
      );
      return;
    }

    final content = _commentInputController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('评论内容不能为空')),
      );
      return;
    }

    if (content.length > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('评论内容不能超过200字')),
      );
      return;
    }

    setState(() {
      _isSendingComment = true;
    });

    try {
      final response = await _apiManager.post('/comment/addComment', data: {
        'vod_id': widget.vodId,
        'content': content,
        'pid': _isReplying ? _replyToCommentId : 0,
        'user_name': user.username,
      });

      if (response['code'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isReplying ? '回复成功' : '评论成功'),
            backgroundColor: Colors.green,
          ),
        );

        // 清空输入框
        _commentInputController.clear();
        
        // 取消回复状态
        if (_isReplying) {
          _cancelReply();
        }

        // 刷新评论列表
        _fetchComments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['msg'] ?? '发送失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('发送评论失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('网络错误，请稍后重试'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSendingComment = false;
      });
    }

    // 隐藏键盘
    _commentInputFocusNode.unfocus();
  }

  /// 开始回复
  void _startReply(int commentId, String userName) {
    setState(() {
      _isReplying = true;
      _replyToCommentId = commentId;
      _replyToUserName = userName;
    });
    
    // 聚焦到输入框
    _commentInputFocusNode.requestFocus();
  }

  /// 取消回复
  void _cancelReply() {
    setState(() {
      _isReplying = false;
      _replyToCommentId = 0;
      _replyToUserName = '';
    });
  }

  /// 构建头像URL
  String _buildAvatarUrl(String? avatar) {
    if (avatar == null || avatar.isEmpty) {
      return '';
    }

    // 如果已经是完整的URL，直接返回
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return avatar;
    }

    // 如果是相对路径，拼接基础URL
    if (avatar.startsWith('/')) {
      String baseUrl = OvoApiManager().baseUrl;
      if (baseUrl.endsWith('/api.php')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - '/api.php'.length);
      }
      return baseUrl + avatar;
    }

    // 其他情况，直接使用基础URL拼接
    String baseUrl = OvoApiManager().baseUrl;
    if (baseUrl.endsWith('/api.php')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - '/api.php'.length);
    }
    return '$baseUrl/uploads/$avatar';
  }

  /// 格式化评论时间 - 支持多种时间格式
  String _formatCommentTime(dynamic timeInput) {
    try {
      int timestamp;

      if (timeInput is int) {
        timestamp = timeInput;
      } else if (timeInput is String) {
        // 尝试解析字符串
        final parsed = int.tryParse(timeInput);
        if (parsed != null) {
          timestamp = parsed;
        } else {
          // 尝试解析为DateTime字符串
          final dateTime = DateTime.tryParse(timeInput);
          if (dateTime != null) {
            timestamp = dateTime.millisecondsSinceEpoch ~/ 1000;
          } else {
            return '未知时间';
          }
        }
      } else {
        return '未知时间';
      }

      // 确保时间戳为秒级（10位数字）
      if (timestamp.toString().length > 10) {
        timestamp = timestamp ~/ 1000;
      }

      final now = DateTime.now();
      final commentTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      final diff = now.difference(commentTime);

      if (diff.inMinutes < 1) {
        return '刚刚';
      } else if (diff.inHours < 1) {
        return '${diff.inMinutes}分钟前';
      } else if (diff.inDays < 1) {
        return '${diff.inHours}小时前';
      } else if (diff.inDays < 30) {
        return '${diff.inDays}天前';
      } else {
        // 超过30天显示具体日期
        return '${commentTime.year}-${commentTime.month.toString().padLeft(2, '0')}-${commentTime.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      print('时间格式化错误: $e, 输入: $timeInput');
      return '未知时间';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 评论列表
        Expanded(child: _buildComments()),
        // 评论输入框
        _buildCommentInputBar(),
      ],
    );
  }

  /// 构建评论列表主体
  Widget _buildComments() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoadingComments) _buildLoadingIndicator(),

            if (_commentErrorMessage != null) _buildErrorDisplay(),

            if (!_isLoadingComments &&
                _commentErrorMessage == null &&
                _commentList.isEmpty)
              _buildEmptyComments(),

            if (!_isLoadingComments &&
                _commentErrorMessage == null &&
                _commentList.isNotEmpty)
              _buildCommentList(),
            
            // 添加底部间距，避免被输入框遮挡
            SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  /// 构建评论输入栏
  Widget _buildCommentInputBar() {
    final bool isLoggedIn = UserStore().user != null;

    return SafeArea(
      child: Container(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 回复状态提示条
            if (_isReplying && _replyToUserName.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: _primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.reply, color: _primaryColor, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '正在回复 @$_replyToUserName 的评论',
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, color: Colors.blue, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            
            // 输入栏
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 32,
                      child: TextField(
                        controller: _commentInputController,
                        focusNode: _commentInputFocusNode,
                        enabled: isLoggedIn,
                        decoration: InputDecoration(
                          hintText:
                              !isLoggedIn
                                  ? '请先登录后评论'
                                  : (_isReplying && _replyToUserName.isNotEmpty
                                      ? '回复@$_replyToUserName的评论：'
                                      : '快来发点什么吧！'),
                          filled: true,
                          fillColor:
                              isLoggedIn
                                  ? Color(0xFFF2F2F2)
                                  : Color(0xFFE8E8E8),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: isLoggedIn
                              ? null
                              : Container(
                                  margin: EdgeInsets.only(left: 8, right: 4),
                                  child: Icon(
                                    Icons.lock_outline,
                                    color: Colors.grey[500],
                                    size: 16,
                                  ),
                                ),
                          prefixIconConstraints: BoxConstraints(
                            minWidth: 0,
                            minHeight: 0,
                          ),
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isLoggedIn ? Colors.grey[600] : Colors.grey[500],
                          ),
                        ),
                        style: TextStyle(fontSize: 13),
                        maxLength: 200,
                        buildCounter: (context,
                                {required currentLength,
                                required isFocused,
                                maxLength}) =>
                            null, // 隐藏字数统计
                        onSubmitted: isLoggedIn ? (_) => _onSendComment() : null,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // 发送按钮
                  Container(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: (isLoggedIn && !_isSendingComment)
                          ? _onSendComment
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: _isSendingComment
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isReplying ? '回复' : '发送',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 加载指示器
  Widget _buildLoadingIndicator() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24.0),
    child: Center(child: WaveLoadingSpinner(size: 40, color: _primaryColor)),
  );

  /// 错误显示
  Widget _buildErrorDisplay() => Container(
    margin: const EdgeInsets.symmetric(vertical: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.red.withOpacity(0.3)),
    ),
    child: Column(
      children: [
        Icon(Icons.error_outline, color: Colors.red, size: 24),
        SizedBox(height: 8),
        Text(
          _commentErrorMessage!,
          style: TextStyle(color: Colors.red, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        TextButton(
          onPressed: _fetchComments,
          child: Text('重试'),
        ),
      ],
    ),
  );

  /// 空状态 - 居中显示
  Widget _buildEmptyComments() {
    final bool isLoggedIn = UserStore().user != null;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.grey[400],
          ),
          SizedBox(height: 12),
          Text(
            '暂无评论',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            isLoggedIn ? '快来发表第一条评论吧！' : '登录后可以参与评论',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// 评论列表
  Widget _buildCommentList() => ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _commentList.length,
    itemBuilder: (context, index) {
      try {
        return Container(
          margin: EdgeInsets.only(
            bottom: 16,
            top: index == 0 ? 8 : 0, // 进一步减少第一个评论的上边距，让它更靠近上方
          ),
          child: _buildCommentItem(_commentList[index]),
        );
      } catch (e) {
        print('构建评论项异常 (index: $index): $e');
        print('异常数据: ${_commentList[index]}');
        return Container(
          margin: EdgeInsets.only(
            bottom: 16,
            top: index == 0 ? 20 : 0,
          ),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '评论数据格式错误',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '索引: $index',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
              Text(
                '错误: ${e.toString()}',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        );
      }
    },
  );

  /// 评论项 - 现代化设计
  Widget _buildCommentItem(Map comment) {
    final String avatar = comment['avatar'] ?? comment['user_portrait'] ?? '';
    final String username =
        comment['username'] ?? comment['comment_name'] ?? '';
    final String nickname = comment['nickname'] ?? username;
    final String content =
        comment['content'] ?? comment['comment_content'] ?? '';
    final dynamic rawTime = comment['create_time'] ?? comment['comment_time'];
    final String time = _formatCommentTime(rawTime);
    final List children = comment['children'] ?? comment['replies'] ?? [];
    final int commentId =
        int.tryParse(comment['comment_id']?.toString() ?? '0') ?? 0;
    final bool expanded = _replyExpanded[commentId] ?? false;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像
            Container(
              width: 32,
              height: 32,
              margin: EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: avatar.isNotEmpty
                    ? Image.network(
                        _buildAvatarUrl(avatar),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            color: Colors.grey[400],
                            size: 16,
                          );
                        },
                      )
                    : Icon(
                        Icons.person,
                        color: Colors.grey[400],
                        size: 16,
                      ),
              ),
            ),
            
            // 评论内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 用户名和时间
                  Row(
                    children: [
                      Text(
                        nickname.isNotEmpty ? nickname : username,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        time,
                        style: TextStyle(
                          color: Color(0xFFB0B0B0),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 4),
                  
                  // 评论内容
                  Text(
                    content,
                    style: TextStyle(
                      color: Color(0xFF444444),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  
                  SizedBox(height: 8),
                  
                  // 回复按钮行
                  Row(
                    children: [
                      Spacer(),
                      // 回复按钮
                      GestureDetector(
                        onTap: () => _startReply(commentId, nickname),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply,
                              color: _primaryColor,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '回复',
                              style: TextStyle(
                                color: _primaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // 展开回复
                  if (children.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyExpanded[commentId] = !expanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Row(
                          children: [
                            Text(
                              expanded ? '收起回复' : '展开${children.length}条回复',
                              style: TextStyle(
                                color: Color(0xFFB0B0B0),
                                fontSize: 13,
                              ),
                            ),
                            Icon(
                              expanded ? Icons.expand_less : Icons.expand_more,
                              color: Color(0xFFB0B0B0),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // 回复列表
                  if (expanded)
                    ...children.map((reply) {
                      try {
                        return _buildReplyItem(reply);
                      } catch (e) {
                        print('构建回复项异常: $e');
                        return Container(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            '回复数据格式错误',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        );
                      }
                    }).toList(),
                ],
              ),
            ),
          ],
        ),
        
        // 添加分隔线
        Container(
          margin: EdgeInsets.only(top: 12),
          height: 0.5,
          color: Color(0xFFE8E8E8),
        ),
      ],
    );
  }

  /// 构建回复项
  Widget _buildReplyItem(Map reply) {
    final String avatar = reply['avatar'] ?? reply['user_portrait'] ?? '';
    final String username =
        reply['username'] ?? reply['comment_name'] ?? '匿名用户';
    final String nickname = reply['nickname'] ?? username;
    final String content = reply['content'] ?? reply['comment_content'] ?? '';
    final dynamic rawTime = reply['create_time'] ?? reply['comment_time'];
    final String time = _formatCommentTime(rawTime);

    return Padding(
      padding: const EdgeInsets.only(left: 0, top: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 回复头像 - 更小
          Container(
            width: 24,
            height: 24,
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: avatar.isNotEmpty
                  ? Image.network(
                      _buildAvatarUrl(avatar),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          color: Colors.grey[400],
                          size: 12,
                        );
                      },
                    )
                  : Icon(
                      Icons.person,
                      color: Colors.grey[400],
                      size: 12,
                    ),
            ),
          ),
          
          // 回复内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 用户名 - 与主评论保持一致
                Text(
                  nickname,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 1),
                
                // 时间信息 - 紧跟用户名下方
                Text(
                  time,
                  style: TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 10,
                  ),
                ),
                SizedBox(height: 4),
                
                Text(
                  content,
                  style: TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 13,
                    height: 1.4,
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
