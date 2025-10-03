import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../services/api/ssl_Management.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../page/vedios.dart' show VideoStreaming;

/// 视频简介页组件
/// 负责视频信息展示、相关推荐、选集等功能
class VideoInfoComponent extends StatefulWidget {
  final Map<String, dynamic>? videoDetail;
  final ScrollController mainScrollController;
  final int currentEpisodeIndex;
  final List<List<Map<String, String>>> playUrlsList;
  final bool isReverseSort;
  final bool isLiked;
  final bool isFavorited;
  final ValueChanged<int>? onEpisodeSelected;
  final VoidCallback? onShowEpisodePopup;
  final VoidCallback? onLikePressed;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onDownloadPressed;

  const VideoInfoComponent({
    Key? key,
    this.videoDetail,
    required this.mainScrollController,
    required this.currentEpisodeIndex,
    required this.playUrlsList,
    required this.isReverseSort,
    this.isLiked = false,
    this.isFavorited = false,
    this.onEpisodeSelected,
    this.onShowEpisodePopup,
    this.onLikePressed,
    this.onFavoritePressed,
    this.onDownloadPressed,
  }) : super(key: key);

  @override
  VideoInfoComponentState createState() => VideoInfoComponentState();
}

class VideoInfoComponentState extends State<VideoInfoComponent>
    with AutomaticKeepAliveClientMixin {
  
  final OvoApiManager _apiManager = OvoApiManager();
  
  bool _isDetailExpanded = false;
  
  // 主题色
  Color get _primaryColor => AppTheme.primaryColor;
  final Color _backgroundColor = kBackgroundColor;
  final Color _cardColor = Color(0xFFFFFFFF);
  final Color _textColor = kTextColor;
  final Color _secondaryTextColor = kSecondaryTextColor;
  
  // 选集相关
  final ScrollController _episodeScrollController = ScrollController();
  int _currentPlayFromIndex = 0;
  
  // 播放源列表
  List<String> get _playFromList {
    if (widget.videoDetail == null) return [];
    
    List<String> playFromList = [];
    for (int i = 0; i < widget.playUrlsList.length; i++) {
      if (widget.playUrlsList[i].isNotEmpty) {
        // 这里可以根据实际数据结构调整
        playFromList.add('播放源${i + 1}');
      }
    }
    return playFromList.isNotEmpty ? playFromList : ['默认播放源'];
  }
  
  // 评分相关
  double? _averageScore;
  bool _isLoadingScore = false;
  int? _watchingCount;
  
  // 固定的切换栏高度常量
  static const double kTabBarFixedHeight = 42.0;
  

  @override
  bool get wantKeepAlive => true;
  
  @override
  void dispose() {
    _episodeScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      controller: widget.mainScrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVideoInfo(),
          SizedBox(height: 12),
          _buildRelatedVideos(),
        ],
      ),
    );
  }
  
  // 创建标题第一个字符特殊效果的通用方法
  Widget _buildTitleWithFirstCharEffect(String title, {double fontSize = 14}) {
    if (title.isEmpty) return Container();

    return Stack(
      children: <Widget>[
        Positioned(
          left: 0.0,
          top: 0.0,
          bottom: 1.4,
          width: fontSize * 1.6, // 根据字体大小调整宽度
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withOpacity(0.58),
                  _primaryColor.withOpacity(0.0),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(2.0, 0.0, 0.0, 0.0),
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'FZLanTingHeiS-EB-GB',
              fontSize: fontSize,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );
  }

  /// 构建视频信息区域
  Widget _buildVideoInfo() {
    if (widget.videoDetail == null) {
      return SizedBox.shrink();
    }

    final String title = widget.videoDetail!['vod_name'] ?? '';
    final String remarks = widget.videoDetail!['vod_remarks'] ?? '';
    final String year = widget.videoDetail!['vod_year']?.toString() ?? '';
    final String director = widget.videoDetail!['vod_director'] ?? '';
    final String type =
        widget.videoDetail?['type_name'] ??
        widget.videoDetail?['type'] ??
        widget.videoDetail?['typeName'] ??
        '';
    final String status = widget.videoDetail!['vod_remarks'] ?? '';
    final String zan = widget.videoDetail!['vod_up']?.toString() ?? '';
    final String content = widget.videoDetail!['vod_content'] ?? '';
    final int vodTotal =
        int.tryParse(widget.videoDetail?['vod_total']?.toString() ?? '') ?? 0;

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行 - 首字特殊效果 + 简介>
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child:
                    // 首字特殊显示 - 完全复制首页热门新番效果
                    title.isNotEmpty
                        ? Stack(
                          children: <Widget>[
                            Positioned(
                              left: 0.0,
                              top: 0.0,
                              bottom: 1.4,
                              width: 25.0, // 只覆盖第一个字的宽度
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _primaryColor.withOpacity(0.58),
                                      _primaryColor.withOpacity(0.0),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                2.0,
                                0.0,
                                0.0,
                                0.0,
                              ),
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontFamily: 'FZLanTingHeiS-EB-GB',
                                  fontSize: 14, // 从18缩小到17
                                  fontWeight:
                                      FontWeight.w400, // 从w500改为w400，去掉加粗效果
                                  color: Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ],
                        )
                        : Container(),
              ),
              // 简介> 按钮 - 修改为显示详细信息弹窗
              GestureDetector(
                onTap: () => _showVideoDetailBottomSheet(),
                child: Container(
                  width: 60, // 固定宽度，与展开按钮统一
                  height: 26, // 固定高度，与展开按钮统一
                  alignment: Alignment.centerRight, // 右对齐
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end, // 内容右对齐
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '简介',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_right, // 使用右箭头图标，与展开按钮风格一致
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),

          // 简介内容预览显示（点击"简介>"按钮查看完整信息）
          Container(
            width: double.infinity,
            child: Text(
              content.isNotEmpty ? content : '暂无简介',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 10),
          // vod_remarks 总集数 语言 + 正在观看人数同行居中
          Builder(
            builder: (context) {
              List<Widget> infoWidgets = [];
              
              if (infoWidgets.isEmpty &&
                  _watchingCount == null &&
                  (_averageScore == null || _isLoadingScore))
                return SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 0.0, bottom: 2.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ...infoWidgets,
                    if (_watchingCount != null) ...[
                      SizedBox(width: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.remove_red_eye,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 0),
                          Text(
                            '${_watchingCount}人在看',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                    Spacer(),
                  ],
                ),
              );
            },
          ),
          
          SizedBox(height: 12), // 恢复原有间距
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 0,
            ), // 移除垂直padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 选集标题行：左边"选集"(带首字特效)，右边当前播放源和展开按钮
                Row(
                  children: [
                    _buildTitleWithFirstCharEffect(
                      '选集',
                      fontSize: 14,
                    ), // 从15缩小到14
                    // 很小的间距，让播放源紧挨着"选集"
                    SizedBox(width: 8),
                    // 当前播放源显示（空心胶囊，灰色字体，字号比选集小）
                    if (_playFromList.isNotEmpty &&
                        _currentPlayFromIndex < _playFromList.length)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.transparent, // 透明背景
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[400]!, // 灰色边框
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _playFromList[_currentPlayFromIndex],
                          style: TextStyle(
                            fontSize: 12, // 比选集(16)小一个字号
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    // 占据剩余空间，将展开按钮推到右边
                    Spacer(),
                    // 展开按钮（箭头）
                    GestureDetector(
                      onTap: _showNewEpisodeSheet,
                      child: Container(
                        width: 60, // 固定宽度，与简介按钮统一
                        height: 26, // 固定高度，与简介按钮统一
                        alignment: Alignment.centerRight, // 右对齐
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end, // 内容右对齐
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '展开',
                              style: TextStyle(
                                fontSize: 14, // 与简介按钮统一字体大小
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500, // 与简介按钮统一字体粗细
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8), // 与标题-简介间距统一
                // 集数水平滚动显示
                if (_currentPlayFromIndex < widget.playUrlsList.length &&
                    widget.playUrlsList[_currentPlayFromIndex].isNotEmpty)
                  Container(
                    height: 32, // 减少固定高度，更紧凑
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      controller: _episodeScrollController, // 使用现有的滚动控制器
                      itemCount: widget.playUrlsList[_currentPlayFromIndex].length,
                      separatorBuilder: (_, __) => SizedBox(width: 12),
                      itemBuilder: (context, idx) {
                        final episode =
                            widget.playUrlsList[_currentPlayFromIndex][idx];
                        final selected = idx == widget.currentEpisodeIndex;

                        return GestureDetector(
                          onTap: () {
                            if (!selected && widget.onEpisodeSelected != null) {
                              widget.onEpisodeSelected!(idx);
                            }
                          },
                          child: Container(
                            width: 75, // 固定宽度
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  selected ? _primaryColor : Colors.grey[100],
                              borderRadius: BorderRadius.circular(6), // 减小圆角
                              border:
                                  selected
                                      ? Border.all(
                                        color: _primaryColor,
                                        width: 2,
                                      )
                                      : Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                            ),
                            child: Text(
                              episode['name'] ?? '第${idx + 1}集',
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontWeight:
                                    selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                fontSize: 12, // 从13缩小到12
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                SizedBox(height: 16), // 选集与相关推荐的间距
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 动态计算弹窗高度 - 从切换栏下方到屏幕底部的可用空间
  double _calculatePopupHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // 播放器高度：16:9 宽高比
    final playerHeight = screenWidth * 9 / 16;

    // 切换栏下方的剩余高度
    final usedHeight = statusBarHeight + playerHeight + kTabBarFixedHeight;
    final availableHeight = screenHeight - usedHeight - bottomPadding;

    return availableHeight;
  }
  
  // 清理简介内容中的特殊符号
  String _cleanContent(String content) {
    if (content.isEmpty) return content;

    // 移除或替换常见的特殊符号和格式字符
    return content
        .replaceAll(
          RegExp(
            r'[【】『』「」〖〗〔〕［］\[\]{}（）()《》<>""'
            '\"\'`~!@#\$%\^&\*_\+=\|\\:;,\?/]',
          ),
          '',
        ) // 移除括号、引号等符号
        .replaceAll(RegExp(r'\s+'), ' ') // 多个空格替换为单个空格
        .replaceAll(RegExp(r'\n+'), '\n') // 多个换行替换为单个换行
        .trim(); // 去除首尾空白
  }

  // 新的视频详细信息弹窗
  void _showVideoDetailBottomSheet() {
    if (widget.videoDetail == null) return;

    final String title = widget.videoDetail!['vod_name'] ?? '';
    final String content = widget.videoDetail!['vod_content'] ?? '';
    final String year = widget.videoDetail!['vod_year']?.toString() ?? '';
    final String director = widget.videoDetail!['vod_director'] ?? '';
    final String status = widget.videoDetail!['vod_remarks'] ?? '';
    final String type = widget.videoDetail!['vod_type_name'] ?? '';
    final String coverImage = widget.videoDetail!['vod_pic'] ?? ''; // 获取封面图URL
    final int vodTotal =
        int.tryParse(widget.videoDetail?['vod_total']?.toString() ?? '') ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true, // 允许拖拽
      isDismissible: true, // 允许点击外部关闭
      elevation: 0, // 移除阴影
      clipBehavior: Clip.none, // 不裁剪，确保外部可见
      constraints: BoxConstraints.loose(Size.infinite), // 宽松约束
      barrierColor: Colors.transparent, // 透明遮罩，确保上方可操作
      builder: (context) {
        return Container(
          height: _calculatePopupHeight(context), // 使用可用高度，不使用margin
          decoration: BoxDecoration(
            // 使用封面图作为背景
            image:
                coverImage.isNotEmpty
                    ? DecorationImage(
                      image: CachedNetworkImageProvider(coverImage),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.6), // 稍微减少遮罩以保留封面图的色彩
                        BlendMode.darken,
                      ),
                    )
                    : null,
            // 如果没有封面图则使用白色背景
            color: coverImage.isEmpty ? Colors.white : null,
            // 矩形样式，无圆角，无阴影
            boxShadow: [], // 明确移除阴影
          ),
          child: Stack(
            children: [
              // 渐变遮罩层 - 仅在有封面图时显示
              if (coverImage.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3), // 顶部稍微暗一些
                        Colors.transparent, // 中间透明
                        Colors.transparent, // 中间透明
                        Colors.black.withOpacity(0.4), // 底部稍微暗一些，便于阅读
                      ],
                      stops: [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
              // 主要内容
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 20), // 减少顶部空白
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 标题 - 根据背景调整颜色
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15, // 从18缩小到17
                              fontWeight: FontWeight.bold,
                              color:
                                  coverImage.isNotEmpty
                                      ? Colors.white
                                      : Colors.black,
                              // 添加阴影以提高可读性
                              shadows:
                                  coverImage.isNotEmpty
                                      ? [
                                        Shadow(
                                          offset: Offset(1.0, 1.0),
                                          blurRadius: 3.0,
                                          color: Colors.black.withOpacity(0.8),
                                        ),
                                      ]
                                      : null,
                            ),
                          ),
                          SizedBox(height: 12),

                          // 评分 - 根据背景调整颜色
                          if (_averageScore != null) ...[
                            Text(
                              '评分：${_averageScore!.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 14, // 从16缩小到15
                                color:
                                    coverImage.isNotEmpty
                                        ? Colors.white.withOpacity(0.9)
                                        : Colors.grey[700],
                                // 添加阴影以提高可读性
                                shadows:
                                    coverImage.isNotEmpty
                                        ? [
                                          Shadow(
                                            offset: Offset(1.0, 1.0),
                                            blurRadius: 2.0,
                                            color: Colors.black.withOpacity(
                                              0.7,
                                            ),
                                          ),
                                        ]
                                        : null,
                              ),
                            ),
                            SizedBox(height: 8),
                          ],

                          // 年份 - 根据背景调整颜色
                          if (year.isNotEmpty) ...[
                            Text(
                              '年份：$year',
                              style: TextStyle(
                                fontSize: 15, // 从16缩小到15
                                color:
                                    coverImage.isNotEmpty
                                        ? Colors.white.withOpacity(0.9)
                                        : Colors.grey[700],
                                shadows:
                                    coverImage.isNotEmpty
                                        ? [
                                          Shadow(
                                            offset: Offset(1.0, 1.0),
                                            blurRadius: 2.0,
                                            color: Colors.black.withOpacity(
                                              0.7,
                                            ),
                                          ),
                                        ]
                                        : null,
                              ),
                            ),
                            SizedBox(height: 8),
                          ],

                          // 导演 - 根据背景调整颜色
                          if (director.isNotEmpty) ...[
                            Text(
                              '导演：$director',
                              style: TextStyle(
                                fontSize: 15, // 从16缩小到15
                                color:
                                    coverImage.isNotEmpty
                                        ? Colors.white.withOpacity(0.9)
                                        : Colors.grey[700],
                                shadows:
                                    coverImage.isNotEmpty
                                        ? [
                                          Shadow(
                                            offset: Offset(1.0, 1.0),
                                            blurRadius: 2.0,
                                            color: Colors.black.withOpacity(
                                              0.7,
                                            ),
                                          ),
                                        ]
                                        : null,
                              ),
                            ),
                            SizedBox(height: 8),
                          ],

                          // 状态 - 根据背景调整颜色
                          if (status.isNotEmpty) ...[
                            Text(
                              '状态：$status',
                              style: TextStyle(
                                fontSize: 15, // 从16缩小到15
                                color:
                                    coverImage.isNotEmpty
                                        ? Colors.white.withOpacity(0.9)
                                        : Colors.grey[700],
                                shadows:
                                    coverImage.isNotEmpty
                                        ? [
                                          Shadow(
                                            offset: Offset(1.0, 1.0),
                                            blurRadius: 2.0,
                                            color: Colors.black.withOpacity(
                                              0.7,
                                            ),
                                          ),
                                        ]
                                        : null,
                              ),
                            ),
                            SizedBox(height: 8),
                          ],

                          // 类型 - 根据背景调整颜色
                          if (type.isNotEmpty) ...[
                            Text(
                              '类型：$type',
                              style: TextStyle(
                                fontSize: 15, // 从16缩小到15
                                color:
                                    coverImage.isNotEmpty
                                        ? Colors.white.withOpacity(0.9)
                                        : Colors.grey[700],
                                shadows:
                                    coverImage.isNotEmpty
                                        ? [
                                          Shadow(
                                            offset: Offset(1.0, 1.0),
                                            blurRadius: 2.0,
                                            color: Colors.black.withOpacity(
                                              0.7,
                                            ),
                                          ),
                                        ]
                                        : null,
                              ),
                            ),
                            SizedBox(height: 12),
                          ],

                          // 简介标题 - 根据背景调整颜色
                          if (content.isNotEmpty) ...[
                            Text(
                              '简介',
                              style: TextStyle(
                                fontSize: 15, // 从18缩小到17
                                fontWeight: FontWeight.bold,
                                color:
                                    coverImage.isNotEmpty
                                        ? Colors.white
                                        : Colors.black,
                                shadows:
                                    coverImage.isNotEmpty
                                        ? [
                                          Shadow(
                                            offset: Offset(1.0, 1.0),
                                            blurRadius: 3.0,
                                            color: Colors.black.withOpacity(
                                              0.8,
                                            ),
                                          ),
                                        ]
                                        : null,
                              ),
                            ),
                            SizedBox(height: 8),
                            // 简介内容 - 根据背景调整颜色
                            Text(
                              _cleanContent(content),
                              style: TextStyle(
                                fontSize: 15, // 从16缩小到15
                                color:
                                    coverImage.isNotEmpty
                                        ? Colors.white.withOpacity(0.9)
                                        : Colors.grey[700],
                                height: 1.5,
                                shadows:
                                    coverImage.isNotEmpty
                                        ? [
                                          Shadow(
                                            offset: Offset(1.0, 1.0),
                                            blurRadius: 2.0,
                                            color: Colors.black.withOpacity(
                                              0.7,
                                            ),
                                          ),
                                        ]
                                        : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // 右上角关闭按钮 - 与标题对齐
              Positioned(
                top: 20, // 与调整后的标题顶部padding对齐
                right: 20, // 调整右边距
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 24, // 调整为与标题大小匹配
                    height: 24, // 调整为与标题大小匹配
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 14, // 图标大小改为14
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建详细信息行的辅助方法
  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                color: _secondaryTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? _textColor,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建相关推荐
  Widget _buildRelatedVideos() {
    return _VideoIntroTab(
      videoDetail: widget.videoDetail,
      buildRelatedVideos: () => VideoStreaming(
            currentVideoId:
                widget.videoDetail?['vod_id'] != null
                    ? int.tryParse(widget.videoDetail!['vod_id'].toString())
                    : null,
            typeId:
                widget.videoDetail?['type_id'] != null
                    ? int.tryParse(widget.videoDetail!['type_id'].toString())
                    : null,
          ),
    );
  }
  
  // 新的选集弹窗设计，参考vedios_backup.dart - 矩形样式，从切换栏下方开始
  void _showNewEpisodeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true, // 允许拖拽
      isDismissible: true, // 允许点击外部关闭
      elevation: 0, // 移除阴影
      clipBehavior: Clip.none, // 不裁剪，确保外部可见
      constraints: BoxConstraints.loose(Size.infinite), // 宽松约束
      barrierColor: Colors.transparent, // 透明遮罩，确保上方可操作
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: _calculatePopupHeight(context), // 使用可用高度，不使用margin
              decoration: BoxDecoration(
                color: Colors.white,
                // 矩形样式，无圆角，无阴影
                boxShadow: [], // 明确移除阴影
              ),
              child: _buildEpisodeSheetContent(setModalState),
            );
          },
        );
      },
    );
  }
  
  // 构建选集弹窗内容
  Widget _buildEpisodeSheetContent(StateSetter setModalState) {
    if (widget.playUrlsList.isEmpty) return SizedBox.shrink();
    
    return Stack(
      children: [
        // 主要内容
        Column(
          children: [
            // 标题和播放源区域 - 确保都靠左对齐
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 50, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 选集标题 - 靠左显示
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '选集',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  // 当前播放源显示 - 靠左显示，无标签
                  if (_playFromList.isNotEmpty &&
                      _currentPlayFromIndex < _playFromList.length)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _playFromList[_currentPlayFromIndex],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 分隔线
            Container(
              height: 1,
              color: Colors.grey[200],
              margin: EdgeInsets.symmetric(horizontal: 20),
            ),
            SizedBox(height: 10),
            // 选集网格
            Expanded(
              child: _buildEpisodeGrid(),
            ),
          ],
        ),
        // 右上角关闭按钮
        Positioned(
          top: 20,
          right: 20,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // 构建选集网格
  Widget _buildEpisodeGrid() {
    if (_currentPlayFromIndex >= widget.playUrlsList.length) {
      return Center(child: Text('暂无选集信息'));
    }
    
    final episodes = widget.playUrlsList[_currentPlayFromIndex];
    final displayEpisodes = widget.isReverseSort ? episodes.reversed.toList() : episodes;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        padding: EdgeInsets.only(bottom: 20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, // 4列布局
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2, // 调整宽高比
        ),
        itemCount: displayEpisodes.length,
        itemBuilder: (context, index) {
          final actualIndex = widget.isReverseSort ? episodes.length - 1 - index : index;
          final episode = displayEpisodes[index];
          final isSelected = actualIndex == widget.currentEpisodeIndex;
          
          return GestureDetector(
            onTap: () {
              if (widget.onEpisodeSelected != null) {
                widget.onEpisodeSelected!(actualIndex);
              }
              Navigator.pop(context);
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor : Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? _primaryColor : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                episode['name'] ?? '第${actualIndex + 1}集',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}

// 新增：简介Tab，防止相关推荐重载
class _VideoIntroTab extends StatefulWidget {
  final Map<String, dynamic>? videoDetail;
  final Widget Function() buildRelatedVideos;
  const _VideoIntroTab({
    Key? key,
    required this.videoDetail,
    required this.buildRelatedVideos,
  }) : super(key: key);
  @override
  __VideoIntroTabState createState() => __VideoIntroTabState();
}

class __VideoIntroTabState extends State<_VideoIntroTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.buildRelatedVideos();
  }
}