import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ovofun/services/api/ssl_Management.dart';

class User {
  final String userId;
  final String username;
  final String nickname;
  final String? avatar;
  final String? qq;
  String? token;
  String? refreshToken;

  User({
    required this.userId,
    required this.username,
    required this.nickname,
    this.avatar,
    this.qq,
    this.token,
    this.refreshToken,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'username': username,
    'nickname': nickname,
    'avatar': avatar,
    'qq': qq,
    'token': token,
    'refresh_token': refreshToken,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    userId: json['user_id']?.toString() ?? '',
    username: json['username']?.toString() ?? '',
    nickname: json['nickname'] ?? '',
    avatar: json['avatar'],
    qq: json['qq'] ?? json['user_qq'],
    token: json['token'],
    refreshToken: json['refreshToken'] ?? json['refresh_token'],
  );

  bool get isLogin => userId != null && token != null && token!.isNotEmpty;
}

class WatchHistoryItem {
  final String videoId;
  final int episodeIndex;
  final int positionSeconds;
  final String playFrom;
  final DateTime timestamp;
  final String videoTitle;
  final String videoCover;

  WatchHistoryItem({
    required this.videoId,
    required this.episodeIndex,
    required this.positionSeconds,
    required this.playFrom,
    required this.timestamp,
    required this.videoTitle,
    required this.videoCover,
  });

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'episodeIndex': episodeIndex,
    'positionSeconds': positionSeconds,
    'playFrom': playFrom,
    'timestamp': timestamp.toIso8601String(),
    'videoTitle': videoTitle,
    'videoCover': videoCover,
  };

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) => WatchHistoryItem(
    videoId: json['videoId'],
    episodeIndex: json['episodeIndex'],
    positionSeconds: json['positionSeconds'],
    playFrom: json['playFrom'],
    timestamp: DateTime.parse(json['timestamp']),
    videoTitle: json['videoTitle'] ?? '',
    videoCover: json['videoCover'] ?? '',
  );
}

class UserStore {
  static final UserStore _instance = UserStore._internal();
  factory UserStore() => _instance;
  UserStore._internal();

  static const String _userKey = 'user_data';
  static const String _historyKey = 'watch_history';
  static const String _favoritesKey = 'favorites';
  static const String _extendsKeyPrefix = 'vod_extends_';

  User? _user;
  List<WatchHistoryItem> _watchHistory = [];
  Set<String> _favorites = {};

  User? get user => _user;
  List<WatchHistoryItem> get watchHistory => List.unmodifiable(_watchHistory);
  Set<String> get favorites => Set.unmodifiable(_favorites);

  Future<void> init() async {
    await _loadUser();
    await _loadWatchHistory();
    await _loadFavorites();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _user = User.fromJson(Map<String, dynamic>.from(jsonDecode(userJson)));
    }
  }

  Future<void> _loadWatchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    if (historyJson != null) {
      final List<dynamic> historyList = jsonDecode(historyJson);
      _watchHistory = historyList
          .map((item) => WatchHistoryItem.fromJson(item))
          .toList();
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString(_favoritesKey);
    if (favoritesJson != null) {
      final List<dynamic> favoritesList = jsonDecode(favoritesJson);
      _favorites = favoritesList.map((e) => e.toString()).toSet();
    }
  }

  Future<void> saveUser(User? user) async {
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    if (user != null) {
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } else {
      await prefs.remove(_userKey);
    }
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _user = User.fromJson(Map<String, dynamic>.from(jsonDecode(userJson)));
    }
  }

  Future<void> loadWatchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    if (historyJson != null) {
      final List<dynamic> historyList = jsonDecode(historyJson);
      _watchHistory = historyList
          .map((item) => WatchHistoryItem.fromJson(item))
          .toList();
    }
  }

  Future<void> addWatchHistory(WatchHistoryItem item) async {
    _watchHistory.removeWhere((element) => 
      element.videoId == item.videoId && 
      element.episodeIndex == item.episodeIndex
    );
    _watchHistory.insert(0, item);
    
    // 只保留最近100条记录
    if (_watchHistory.length > 100) {
      _watchHistory = _watchHistory.sublist(0, 100);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, 
      jsonEncode(_watchHistory.map((e) => e.toJson()).toList())
    );
  }

  Future<void> clearWatchHistory() async {
    _watchHistory.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<void> toggleFavorite(String videoId) async {
    if (_favorites.contains(videoId)) {
      _favorites.remove(videoId);
    } else {
      _favorites.add(videoId);
  }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favoritesKey, jsonEncode(_favorites.toList()));
  }

  Future<void> clearFavorites() async {
    _favorites.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesKey);
  }

  Future<void> logout() async {
    _user = null;
    _watchHistory.clear();
    _favorites.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_historyKey);
    await prefs.remove(_favoritesKey);
  }

  // 刷新token方法
  static Future<User?> refreshTokenIfNeeded() async {
    final user = UserStore().user;
    print('[刷新token] 刷新前本地user: userId=${user?.userId}, qq=${user?.qq}, refreshToken=${user?.refreshToken}');
    if (user == null || user.refreshToken == null || user.refreshToken!.isEmpty) {
      print('[刷新token] 未登录或无refreshToken, 不刷新');
      return null;
    }
    try {
      final api = OvoApiManager();
      final result = await api.post('/user/refresh_token', data: {
        'refresh_token': user.refreshToken,
      });
      print('[刷新token] 接口返回: $result');
      // 新增：如果 result 为空，直接清除本地登录状态
      if (result == null) {
        print('[刷新token] result为null，清除本地登录状态');
        await UserStore().logout();
        return null;
      }
      // 检查token失效
      if (result is Map && result['code'] == 401 && (result['msg']?.toString().contains('refresh_token无效') ?? false)) {
        print('[刷新token] refresh_token无效，清除本地登录状态');
        await UserStore().logout();
        return null;
      }
      // 直接用result作为新用户数据
      final newUser = User.fromJson(Map<String, dynamic>.from(result));
      print('[刷新token] newUser: userId=${newUser.userId}, username=${newUser.username}, nickname=${newUser.nickname}, qq=${newUser.qq}, token=${newUser.token}, refreshToken=${newUser.refreshToken}');
      await UserStore().saveUser(newUser);
      await UserStore().loadUser();
      print('[刷新token] 存储后本地user: userId=${UserStore().user?.userId}, qq=${UserStore().user?.qq}, token=${UserStore().user?.token}, refreshToken=${UserStore().user?.refreshToken}');
      return newUser;
    } catch (e) {
      print('[刷新token] 异常: $e');
      // 新增：异常时也清除本地登录状态
      await UserStore().logout();
      return null;
    }
  }

  /// 获取云端观看历史（分页）
  Future<List<Map<String, dynamic>>> fetchCloudHistory({int page = 1, int limit = 20}) async {
    final api = OvoApiManager();
    final res = await api.getCloudHistory(page: page, limit: limit);
    // 适配后端响应结构
    if (res is Map && res['list'] is List) {
      return List<Map<String, dynamic>>.from(res['list']);
    } else if (res is Map && res['data'] is Map && res['data']['list'] is List) {
      // 兼容旧结构
      return List<Map<String, dynamic>>.from(res['data']['list']);
    }
    return [];
  }

  /// 添加云端观看历史1
  Future<Map<String, dynamic>> addCloudHistoryRecord({
    required int vodId,
    required int episodeIndex,
    String? playSource,
    String? playUrl,
    int? playProgress,
  }) async {
    final api = OvoApiManager();
    final res = await api.addCloudHistory(
      vodId: vodId,
      episodeIndex: episodeIndex,
      playSource: playSource,
      playUrl: playUrl,
      playProgress: playProgress,
    );
    return res;
  }

  Future<void> saveWatchHistoryList(List<WatchHistoryItem> list) async {
    _watchHistory = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(_watchHistory.map((e) => e.toJson()).toList()));
  }

  /// 删除单个云端历史记录
  Future<bool> deleteCloudHistoryItem(String vodId) async {
    final api = OvoApiManager();
    final success = await api.deleteHistoryItem(vodId);
    if (success) {
      // 本地同步删除
      _watchHistory.removeWhere((item) => item.videoId == vodId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, jsonEncode(_watchHistory.map((e) => e.toJson()).toList()));
    }
    return success;
  }

  /// 删除全部云端历史记录
  Future<bool> deleteAllCloudHistory() async {
    final api = OvoApiManager();
    final success = await api.deleteAllHistory();
    if (success) {
      _watchHistory.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    }
    return success;
  }

  // 保存扩展分类信息到本地
  static Future<void> saveExtends(int typeId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_extendsKeyPrefix + typeId.toString(), jsonEncode(data));
  }

  // 获取本地扩展分类信息
  static Future<Map<String, dynamic>?> getExtends(int typeId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_extendsKeyPrefix + typeId.toString());
    if (jsonStr != null) {
      try {
        return Map<String, dynamic>.from(jsonDecode(jsonStr));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // 异步获取扩展分类并存储
  static Future<void> fetchAndSaveExtends(int typeId) async {
    try {
      final api = OvoApiManager();
      final res = await api.get('/v1/vod_extends', queryParameters: {'type_id': typeId});
      if (res is Map) {
        await saveExtends(typeId, Map<String, dynamic>.from(res));
      }
    } catch (e) {
      // ignor
    }
  }
}
