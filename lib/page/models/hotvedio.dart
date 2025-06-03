import 'package:flutter/material.dart';
import '../../models/hotvedio_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ovofun/page/models/hotmore.dart'; // 导入 HotMorePage

class HotVedioModule extends StatelessWidget {
  final List<HotVedioModel> hotVedios;
  final Function(int) onTapItem;
  final VoidCallback? onTapMore;

  const HotVedioModule({
    Key? key,
    required this.hotVedios,
    required this.onTapItem,
    this.onTapMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Stack(
                clipBehavior: Clip.none, // 允许下划线超出Stack的边界，如果需要的话
                children: [
                  const Text(
                    '热门新番',
                    style: TextStyle(
                      fontFamily: 'AlibabaPuHuiTi',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.black, // 确保文字颜色是明确的
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: -2, // 调整下划线与文字的间距，负数使其在文字下方更近
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 计算第一个字的宽度
                        final TextPainter textPainter = TextPainter(
                          text: const TextSpan(
                            text: '热', // 第一个字
                            style: TextStyle(
                              fontFamily: 'AlibabaPuHuiTi',
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          textDirection: TextDirection.ltr,
                        )..layout();
                        final double firstCharWidth = textPainter.width;

                        return Container(
                          width: firstCharWidth + 4,
                          height: 2, // 下划线高度
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.withOpacity(0.6),
                                Colors.blue.withOpacity(0.0),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (onTapMore != null)
              GestureDetector(
                  onTap: onTapMore,
                  child: Text('更多', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        ),
        // 热门视频列表
        SizedBox(
          height: 115, // 降低高度以匹配新尺寸
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            itemCount: hotVedios.length,
            itemBuilder: (context, index) {
              final hotVedio = hotVedios[index];
              return _buildHotVedioItem(context, hotVedio, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHotVedioItem(BuildContext context, HotVedioModel hotVedio, int index) {
    return GestureDetector(
      onTap: () => onTapItem(hotVedio.vodId),
      child: Container(
        width: 160, // 调整Container宽度
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 视频封面
            Stack(
              children: [
                // 图片
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: CachedNetworkImage(
                    imageUrl: hotVedio.vodPic,
                    width: 160, // 调整图片宽度
                    height: 160 * 9 / 16, // 保持16:9比1
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),
                // 更新信息
                if (hotVedio.vodRemarks.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      padding: EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.grey.withOpacity(0.6),
                          ],
                        ),
                      ),
                      child: Text(
                        hotVedio.vodRemarks,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 1),
            // 视频标题
            Text(
              hotVedio.vodName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 安全构建副标题文本，只使用实际存在的字
  String _buildSubtitleText(HotVedioModel hotVedio) {
    // 由于模型中没有vodActor、vodClass等字段，我们只能使用现有字
    // 这里使用vodRemarks作为副标题，如果为空则返回空字符串
    if (hotVedio.vodRemarks.isNotEmpty) {
      return hotVedio.vodRemarks;
    }
    
    // 如果没有合适的字段作为副标题，返回空字符串
    return '';
  }
}
