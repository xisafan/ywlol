class History {
  final int historyId;
  final int userId;
  final int vodId;
  final String vodName;
  final String vodPic;
  final int typeId;
  final String typeName;
  final int viewProgress;
  final int totalDuration;
  final String lastViewTime;
  final String createTime;

  History({
    required this.historyId,
    required this.userId,
    required this.vodId,
    required this.vodName,
    required this.vodPic,
    required this.typeId,
    required this.typeName,
    this.viewProgress = 0,
    this.totalDuration = 0,
    required this.lastViewTime,
    required this.createTime,
  });

  factory History.fromJson(Map<String, dynamic> json) {
    // 处理historyId可能是字符串的情况
    int parseHistoryId() {
      var historyId = json['history_id'];
      if (historyId is int) return historyId;
      if (historyId is String) {
        return int.tryParse(historyId) ?? 0;
      }
      return 0;
    }
    
    // 处理userId可能是字符串的情况
    int parseUserId() {
      var userId = json['user_id'];
      if (userId is int) return userId;
      if (userId is String) {
        return int.tryParse(userId) ?? 0;
      }
      return 0;
    }
    
    // 处理vodId可能是字符串的情况
    int parseVodId() {
      var vodId = json['vod_id'];
      if (vodId is int) return vodId;
      if (vodId is String) {
        return int.tryParse(vodId) ?? 0;
      }
      return 0;
    }
    
    // 处理typeId可能是字符串的情况
    int parseTypeId() {
      var typeId = json['type_id'];
      if (typeId is int) return typeId;
      if (typeId is String) {
        return int.tryParse(typeId) ?? 0;
      }
      return 0;
    }
    
    // 处理viewProgress可能是字符串的情况
    int parseViewProgress() {
      var viewProgress = json['view_progress'];
      if (viewProgress is int) return viewProgress;
      if (viewProgress is String) {
        return int.tryParse(viewProgress) ?? 0;
      }
      return 0;
    }
    
    // 处理totalDuration可能是字符串的情况
    int parseTotalDuration() {
      var totalDuration = json['total_duration'];
      if (totalDuration is int) return totalDuration;
      if (totalDuration is String) {
        return int.tryParse(totalDuration) ?? 0;
      }
      return 0;
    }

    return History(
      historyId: parseHistoryId(),
      userId: parseUserId(),
      vodId: parseVodId(),
      vodName: json['vod_name'] ?? '',
      vodPic: json['vod_pic'] ?? '',
      typeId: parseTypeId(),
      typeName: json['type_name'] ?? '',
      viewProgress: parseViewProgress(),
      totalDuration: parseTotalDuration(),
      lastViewTime: json['last_view_time'] ?? '',
      createTime: json['create_time'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'history_id': historyId,
      'user_id': userId,
      'vod_id': vodId,
      'vod_name': vodName,
      'vod_pic': vodPic,
      'type_id': typeId,
      'type_name': typeName,
      'view_progress': viewProgress,
      'total_duration': totalDuration,
      'last_view_time': lastViewTime,
      'create_time': createTime,
    };
  }
}
