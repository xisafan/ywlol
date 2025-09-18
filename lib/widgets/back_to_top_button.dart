import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme_notifier.dart';

/// 返回顶部悬浮按钮组件
/// 支持动态主题颜色，自动显示/隐藏，平滑滚动动画
class BackToTopButton extends StatefulWidget {
  final ScrollController scrollController;
  final double showOffset; // 滚动多少距离后显示按钮
  final Duration animationDuration; // 滚动到顶部的动画时长
  final double? bottomOffset; // 可选的底部偏移量，用于适配不同导航栏高度

  const BackToTopButton({
    Key? key,
    required this.scrollController,
    this.showOffset = 200.0,
    this.animationDuration = const Duration(milliseconds: 600),
    this.bottomOffset,
  }) : super(key: key);

  @override
  State<BackToTopButton> createState() => _BackToTopButtonState();
}

class _BackToTopButtonState extends State<BackToTopButton>
    with SingleTickerProviderStateMixin {
  bool _showButton = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 缩放动画
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    // 透明度动画
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 监听滚动
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _animationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShow = widget.scrollController.offset > widget.showOffset;
    if (shouldShow != _showButton) {
      setState(() {
        _showButton = shouldShow;
      });

      if (_showButton) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _scrollToTop() {
    widget.scrollController.animateTo(
      0.0,
      duration: widget.animationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return Positioned(
          right: 16,
          bottom: widget.bottomOffset ?? 50, // 使用传入的偏移量或默认值50
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: themeNotifier.primaryColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: themeNotifier.primaryColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _scrollToTop,
                        child: Center(
                          child: Icon(
                            Icons.keyboard_arrow_up,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// 带返回顶部按钮的Scaffold包装器
/// 方便在各个页面中快速使用
class ScaffoldWithBackToTop extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final ScrollController scrollController;
  final double showOffset;
  final Duration animationDuration;
  final double? bottomOffset; // 新增底部偏移量参数

  const ScaffoldWithBackToTop({
    Key? key,
    required this.body,
    required this.scrollController,
    this.appBar,
    this.backgroundColor,
    this.showOffset = 200.0,
    this.animationDuration = const Duration(milliseconds: 600),
    this.bottomOffset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      body: Stack(
        children: [
          body,
          BackToTopButton(
            scrollController: scrollController,
            showOffset: showOffset,
            animationDuration: animationDuration,
            bottomOffset: bottomOffset, // 传递底部偏移量
          ),
        ],
      ),
    );
  }
}
