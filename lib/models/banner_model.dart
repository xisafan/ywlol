import 'dart:convert';

/// Banner数据模型类
class BannerModel {
  final int vodId;
  final String vodName;
  final String imageUrl;

  /// 构造函数
  /// 
  /// @param vodId 视频ID
  /// @param vodName 视频名称
  /// @param imageUrl 图片URL
  BannerModel({
    required this.vodId,
    required this.vodName,
    required this.imageUrl,
  });

  /// 从JSON映射创建BannerModel对象
  /// 
  /// @param json JSON映射
  /// @return BannerModel对象
  factory BannerModel.fromJson(Map<String, dynamic> json) {
    // 打印原始JSON数据，便于调试
    print('Banner原始JSON数据: $json');
    
    // 增强类型安全处理，支持多种可能的字段名
    return BannerModel(
      vodId: _parseId(json),
      vodName: _parseName(json),
      imageUrl: _parseImageUrl(json),
    );
  }
  
  /// 解析ID字段，支持多种可能的字段名
  static int _parseId(Map<String, dynamic> json) {
    // 尝试多种可能的字段名
    if (json.containsKey('vod_id')) {
      return (json['vod_id'] as num?)?.toInt() ?? 0;
    } else if (json.containsKey('id')) {
      return (json['id'] as num?)?.toInt() ?? 0;
    } else if (json.containsKey('banner_id')) {
      return (json['banner_id'] as num?)?.toInt() ?? 0;
    }
    
    // 如果找不到匹配的字段，返回默认值
    print('警告: 找不到ID字段，使用默认值0');
    return 0;
  }
  
  /// 解析名称字段，支持多种可能的字段名
  static String _parseName(Map<String, dynamic> json) {
    // 尝试多种可能的字段名
    if (json.containsKey('vod_name')) {
      return (json['vod_name'] as String?) ?? '未知名称';
    } else if (json.containsKey('name')) {
      return (json['name'] as String?) ?? '未知名称';
    } else if (json.containsKey('title')) {
      return (json['title'] as String?) ?? '未知名称';
    } else if (json.containsKey('banner_title')) {
      return (json['banner_title'] as String?) ?? '未知名称';
    }
    
    // 如果找不到匹配的字段，返回默认值
    print('警告: 找不到名称字段，使用默认值"未知名称"');
    return '未知名称';
  }
  
  /// 解析图片URL字段，支持多种可能的字段名
  static String _parseImageUrl(Map<String, dynamic> json) {
    // 尝试多种可能的字段名
    String? url;
    
    if (json.containsKey('image_url')) {
      url = json['image_url'] as String?;
    } else if (json.containsKey('imageUrl')) {
      url = json['imageUrl'] as String?;
    } else if (json.containsKey('img')) {
      url = json['img'] as String?;
    } else if (json.containsKey('pic')) {
      url = json['pic'] as String?;
    } else if (json.containsKey('banner_img')) {
      url = json['banner_img'] as String?;
    } else if (json.containsKey('image')) {
      url = json['image'] as String?;
    }
    
    // 如果找不到匹配的字段，返回默认值
    if (url == null) {
      print('警告: 找不到图片URL字段，使用默认值""');
      return '';
    }
    
    // 处理URL转义
    return url.replaceAll(r'\/', '/');
  }
}
