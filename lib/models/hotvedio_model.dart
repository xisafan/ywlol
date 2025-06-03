import 'dart:convert';

/// 热播视频数据模型类
class HotVedioModel {
  final int vodId;
  final String vodName;
  final String vodPic;
  final String vodRemarks;
  final int vodLevel;

  /// 构造函数
  /// 
  /// @param vodId 视频ID
  /// @param vodName 视频名称
  /// @param vodPic 视频图片URL
  /// @param vodRemarks 视频备注信息
  /// @param vodLevel 视频等级
  HotVedioModel({
    required this.vodId,
    required this.vodName,
    required this.vodPic,
    required this.vodRemarks,
    this.vodLevel = 6,
  });

  /// 从JSON映射创建HotVedioModel对象
  /// 
  /// @param json JSON映射
  /// @return HotVedioModel对象
  factory HotVedioModel.fromJson(Map<String, dynamic> json) {
    // 打印原始JSON数据，便于调试
    print('HotVedio原始JSON数据: $json');
    
    // 增强类型安全处理，支持多种可能的字段名
    return HotVedioModel(
      vodId: _parseId(json),
      vodName: _parseName(json),
      vodPic: _parsePic(json),
      vodRemarks: _parseRemarks(json),
      vodLevel: _parseLevel(json),
    );
  }
  
  /// 解析ID字段，支持多种可能的字段名
  static int _parseId(Map<String, dynamic> json) {
    // 尝试多种可能的字段名
    if (json.containsKey('vod_id')) {
      return (json['vod_id'] as num?)?.toInt() ?? 0;
    } else if (json.containsKey('id')) {
      return (json['id'] as num?)?.toInt() ?? 0;
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
    }
    
    // 如果找不到匹配的字段，返回默认值
    print('警告: 找不到名称字段，使用默认值"未知名称"');
    return '未知名称';
  }
  
  /// 解析图片URL字段，支持多种可能的字段名
  static String _parsePic(Map<String, dynamic> json) {
    // 尝试多种可能的字段名
    String? url;
    
    if (json.containsKey('vod_pic')) {
      url = json['vod_pic'] as String?;
    } else if (json.containsKey('pic')) {
      url = json['pic'] as String?;
    } else if (json.containsKey('image')) {
      url = json['image'] as String?;
    } else if (json.containsKey('img')) {
      url = json['img'] as String?;
    } else if (json.containsKey('image_url')) {
      url = json['image_url'] as String?;
    }
    
    // 如果找不到匹配的字段，返回默认值
    if (url == null) {
      print('警告: 找不到图片URL字段，使用默认值""');
      return '';
    }
    
    // 处理URL转义
    return url.replaceAll(r'\/', '/');
  }
  
  /// 解析备注字段，支持多种可能的字段名
  static String _parseRemarks(Map<String, dynamic> json) {
    // 尝试多种可能的字段名
    if (json.containsKey('vod_remarks')) {
      return (json['vod_remarks'] as String?) ?? '';
    } else if (json.containsKey('remarks')) {
      return (json['remarks'] as String?) ?? '';
    } else if (json.containsKey('note')) {
      return (json['note'] as String?) ?? '';
    } else if (json.containsKey('description')) {
      return (json['description'] as String?) ?? '';
    }
    
    // 如果找不到匹配的字段，返回默认值
    print('警告: 找不到备注字段，使用默认值""');
    return '';
  }
  
  /// 解析等级字段，支持多种可能的字段名
  static int _parseLevel(Map<String, dynamic> json) {
    // 尝试多种可能的字段名
    if (json.containsKey('vod_level')) {
      return (json['vod_level'] as num?)?.toInt() ?? 6;
    } else if (json.containsKey('level')) {
      return (json['level'] as num?)?.toInt() ?? 6;
    }
    
    // 如果找不到匹配的字段，返回默认值
    print('警告: 找不到等级字段，使用默认值6');
    return 6;
  }
  
  /// 转换为JSON映射
  Map<String, dynamic> toJson() {
    return {
      'vod_id': vodId,
      'vod_name': vodName,
      'vod_pic': vodPic,
      'vod_remarks': vodRemarks,
      'vod_level': vodLevel,
    };
  }
}
