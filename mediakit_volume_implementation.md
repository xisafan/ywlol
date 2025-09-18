  // 添加弹幕到控制器
  void _addDanmaku(
    String text,
    Color color, {
    DanmakuItemType type = DanmakuItemType.scroll,
  }) {
    if (_danmakuController == null || !mounted) return;

    try {
      _danmakuController!.addDanmaku(
        DanmakuContentItem(text, color: color, type: type),
      );
    } catch (e) {
      print('添加弹幕失败: $e');
    }
  }