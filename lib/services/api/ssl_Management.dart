import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ovofun/models/user_model.dart';

/// OVO API管理器
///
/// 用于处理与OVO API的所有交互，包括请求、响应解密等
class OvoApiManager {
  static final OvoApiManager _instance = OvoApiManager._internal();

  /// 基础URL
  final String _baseUrl = 'http://192.168.31.102/ovo/api.php';

  /// Dio实例
  late Dio _dio;

  /// 加密密钥
  String? _encryptKey = '8f7c6447db47a8790492cfaa7fa80827';

  /// JWT Token
  String? _token;

  /// 工厂构造函数
  factory OvoApiManager() {
    return _instance;
  }

  /// 私有构造函数
  OvoApiManager._internal() {
    _initDio();
  }

  /// 初始化Dio
  void _initDio() {
    _dio = Dio();
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  /// 设置加密密钥
  void setEncryptKey(String key) {
    _encryptKey = key;
  }

  /// 获取加密密钥
  String? getEncryptKey() {
    return _encryptKey;
  }

  /// 设置Token
  void setToken(String token) {
    _token = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// 获取Token
  String? getToken() {
    return _token;
  }

  /// 清除Token
  void clearToken() {
    _token = null;
    _dio.options.headers.remove('Authorization');
  }

  /// 发送GET请求
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      print('*** Request ***');
      print('uri: $_baseUrl$path');
      print('method: GET');
      print('queryParameters: $queryParameters');

      final response = await _dio.get(path, queryParameters: queryParameters);

      print('*** Response ***');
      print('uri: $_baseUrl$path');
      print('statusCode: ${response.statusCode}');
      print('Response Text:');
      print(jsonEncode(response.data));

      return _handleResponse(response);
    } catch (e) {
      print('GET请求失败: $e');
      rethrow;
    }
  }

  /// 发送POST请求
  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      print('*** Request ***');
      print('uri: $_baseUrl$path');
      print('method: POST');
      print('data: $data');

      final response = await _dio.post(path, data: data);

      print('*** Response ***');
      print('uri: $_baseUrl$path');
      print('statusCode: ${response.statusCode}');
      print('Response Text:');
      print(jsonEncode(response.data));

      return _handleResponse(response);
    } catch (e) {
      print('POST请求失败: $e');
      rethrow;
    }
  }

  /// 处理响应
  Future<dynamic> _handleResponse(Response response) async {
    if (response.statusCode != 200) {
      throw Exception('请求失败，状态码: ${response.statusCode}');
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('响应格式错误');
    }

    final code = data['code'];
    if (code != 200) {
      throw Exception('API错误: [${data['code']}]${data['msg']}');
    }

    // 检查是否有加密数据
    if (data.containsKey('data') && data.containsKey('timestamp')) {
      if (data['data'] is String) {
        // 解密数据
        final decryptedData = await decryptApiResponse(data['data'], data['timestamp']);
        if (decryptedData == null) {
          throw Exception('数据解密失败');
        }
        return decryptedData['data'];
      } else {
        // 数据未加密
        return data['data'];
      }
    }

    return data;
  }

  /// 解密API响应
  Future<Map<String, dynamic>?> decryptApiResponse(String encryptedData, int timestamp) async {
    try {
      print('开始解密数据: $encryptedData');
      print('时间戳: $timestamp');

      // 获取加密密钥
      final key = getEncryptKey();
      if (key == null || key.isEmpty) {
        throw Exception('加密密钥未设置');
      }

      // Base64解码
      final Uint8List decodedData = base64Decode(encryptedData);
      print('Base64解码后数据长度: ${decodedData.length}');

      // 根据时间戳生成IV (api.php中timestamp是毫秒，这里需要秒)
      final int timestampInSeconds = (timestamp / 1000).floor();
      print('时间戳(秒): $timestampInSeconds');
      print('哈希输入: $timestampInSeconds');

      final String fullHash = sha256.convert(utf8.encode(timestampInSeconds.toString())).toString();
      print('完整哈希: $fullHash');

      final String ivString = fullHash.substring(0, 16);
      print('IV字符串: $ivString');

      // 确保密钥长度为16字节（AES-128-CBC）
      final String keyString = key.length > 16 ? key.substring(0, 16) : key.padRight(16, '0');
      print('16字节密钥: $keyString');

      // 创建AES密钥和IV
      final encrypt.Key aesKey = encrypt.Key.fromUtf8(keyString);
      final encrypt.IV iv = encrypt.IV.fromUtf8(ivString);

      // 输出IV的十六进制表示，便于调试
      print('IV: ${ivString.codeUnits.map((e) => e.toRadixString(16).padLeft(2, '0')).join('')}');

      // AES解密
      final encrypt.Encrypter encrypter = encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
      final encrypt.Encrypted encrypted = encrypt.Encrypted(decodedData);
      final String decrypted = encrypter.decrypt(encrypted, iv: iv);

      // JSON解码
      final Map<String, dynamic> decryptedData = jsonDecode(decrypted);
      print('解密后数据: $decryptedData');
      return decryptedData;
    } catch (e) {
      print('解密失败: $e');
      return null;
    }
  }

  // Banner相关API
  Future<List<dynamic>> getBanners() async {
    // 获取Banner数据
    final dynamic result = await get('/v1/banners');

    // 检查返回的数据结构
    if (result is Map<String, dynamic> && result.containsKey('list')) {
      // 如果是包含list字段的Map，则返回list字段的值
      return result['list'] as List<dynamic>;
    } else if (result is List<dynamic>) {
      // 如果已经是List，则直接返回
      return result;
    } else {
      // 如果是其他类型，则返回空列表
      print('Banner数据格式不符合预期: $result');
      return [];
    }
  }

  // 热播视频相关API
  Future<List<dynamic>> getHotVedios() async {
    // 获取热播视频数据
    final dynamic result = await get('/v1/hotvedios');

    // 检查返回的数据结构
    if (result is Map<String, dynamic> && result.containsKey('list')) {
      // 如果是包含list字段的Map，则返回list字段的值
      return result['list'] as List<dynamic>;
    } else if (result is List<dynamic>) {
      // 如果已经是List，则直接返回
      return result;
    } else {
      // 如果是其他类型，则返回空列表
      print('热播视频数据格式不符合预期: $result');
      return [];
    }
  }

  // 搜索视频相关API
  Future<dynamic> searchVideos(String keyword) async {
    // 搜索视频数据
    final dynamic result = await get('/v1/search', queryParameters: {
      'keyword': keyword,
    });

    return result;
  }

  // 分类相关API

  /// 获取所有分类列表
  Future<List<dynamic>> getAllTypes() async {
    // 获取所有分类数据
    final dynamic result = await get('/v1/types');

    // 检查返回的数据结构
    if (result is Map<String, dynamic> && result.containsKey('list')) {
      // 如果是包含list字段的Map，则返回list字段的值
      return result['list'] as List<dynamic>;
    } else if (result is List<dynamic>) {
      // 如果已经是List，则直接返回
      return result;
    } else {
      // 如果是其他类型，则返回空列表
      print('分类数据格式不符合预期: $result');
      return [];
    }
  }

  /// 获取分类下的视频列表
  Future<Map<String, dynamic>> getVideosByType({
    required int typeId,
    int page = 1,
    int limit = 20,
  }) async {
    // 获取分类下的视频数据
    final dynamic result = await get('/v1/classify', queryParameters: {
      'type_id': typeId,
      'page': page,
      'limit': limit,
    });

    // 检查返回的数据结构
    if (result is Map<String, dynamic>) {
      return result;
    } else {
      // 如果是其他类型，则返回空Map
      print('分类视频数据格式不符合预期: $result');
      return {
        'list': [],
        'type': {'type_id': typeId, 'type_name': '', 'type_en': ''},
        'total': 0,
        'page': page,
        'limit': limit,
        'pages': 0
      };
    }
  }

  /// 获取视频详情
  Future<Map<String, dynamic>> getVideoDetail(int vodId) async {
    try {
      print('获取视频详情，ID: $vodId');

      // 获取视频详情数据
      final dynamic result = await get('/v1/videos/$vodId');

      // 检查返回的数据结构
      if (result is Map<String, dynamic>) {
        print('获取视频详情成功: ${result.keys}');
        return result;
      } else {
        // 如果是其他类型，则抛出异常
        print('视频详情数据格式不符合预期: $result');
        throw Exception('视频详情数据格式不符合预期');
      }
    } catch (e) {
      print('获取视频详情失败: $e');
      rethrow;
    }
  }

  /// 解析播放地址
  List<Map<String, dynamic>> parsePlayUrl(String playFrom, String playUrl) {
    List<Map<String, dynamic>> result = [];

    try {
      // 解析播放源
      List<String> playFromList = [];
      if (playFrom.isNotEmpty) {
        playFromList = playFrom.split('\$\$\$');
      }

      // 解析播放地址
      List<List<Map<String, String>>> playUrlsList = [];
      if (playUrl.isNotEmpty) {
        // 分割不同播放源的地址
        final List<String> playUrlsBySource = playUrl.split('\$\$\$');

        // 处理每个播放源的地址
        for (var i = 0; i < playUrlsBySource.length; i++) {
          final String sourceUrl = playUrlsBySource[i];
          final List<Map<String, String>> episodes = [];

          // 分割每一集
          final List<String> episodeItems = sourceUrl.split('#');

          for (var episodeItem in episodeItems) {
            // 分割集数名称和URL
            final List<String> parts = episodeItem.split('\$');
            if (parts.length == 2) {
              episodes.add({
                'name': parts[0],
                'url': parts[1].replaceAll(r'\/', '/'),
              });
            }
          }

          playUrlsList.add(episodes);
        }
      }

      // 组装结果
      for (var i = 0; i < playFromList.length; i++) {
        if (i < playUrlsList.length) {
          result.add({
            'source': playFromList[i],
            'episodes': playUrlsList[i],
          });
        }
      }

      return result;
    } catch (e) {
      print('解析播放地址失败: $e');
      return [];
    }
  }

  /// 获取视频评论列表
  Future<Map<String, dynamic>> getVideoComments(int vodId, {int page = 1, int limit = 20}) async {
    try {
      // 构建请求参数
      final Map<String, dynamic> params = {
        'vod_id': vodId,
        'page': page,
        'limit': limit,
      };

      // 调用API获取评论列表
      final response = await get('/v1/comment/getComments', queryParameters: params);

      // 解析响应数据
      if (response is Map<String, dynamic> && response['code'] == 0) {
        return {
          'code': 0,
          'msg': 'success',
          'total': response['total'] ?? 0,
          'list': response['list'] ?? [],
          'page': response['page'] ?? 1,
          'pages': response['pages'] ?? 1,
        };
      } else {
        return {
          'code': response['code'] ?? 1001,
          'msg': response['msg'] ?? '获取评论失败',
          'list': [],
        };
      }
    } catch (e) {
      print('获取评论列表异常: $e');
      return {
        'code': 5001,
        'msg': '获取评论列表异常: ${e.toString()}',
        'list': [],
      };
    }
  }

  /// 发表评论
  Future<Map<String, dynamic>> addComment(int vodId, String content, {int pid = 0}) async {
    try {
      // 构建请求参数
      final Map<String, dynamic> params = {
        'vod_id': vodId,
        'content': content,
        'pid': pid,
        'user_id': 1, // 模拟用户ID，实际应从用户会话中获取
        'user_name': '用户${DateTime.now().millisecondsSinceEpoch % 1000}', // 模拟用户名
      };

      // 调用API发表评论
      final response = await post('/v1/comment/addComment', data: params);

      // 解析响应数据
      if (response is Map<String, dynamic> && response['code'] == 0) {
        return {
          'code': 0,
          'msg': 'success',
          'data': response['data'] ?? {},
        };
      } else {
        return {
          'code': response['code'] ?? 1002,
          'msg': response['msg'] ?? '发表评论失败',
        };
      }
    } catch (e) {
      print('发表评论异常: $e');
      return {
        'code': 5002,
        'msg': '发表评论异常: ${e.toString()}',
      };
    }
  }

  /// 点赞评论
  Future<Map<String, dynamic>> likeComment(int commentId) async {
    try {
      // 构建请求参数
      final Map<String, dynamic> params = {
        'comment_id': commentId,
        'user_id': 1, // 模拟用户ID，实际应从用户会话中获取
      };

      // 调用API点赞评论
      final response = await post('/v1/comment/likeComment', data: params);

      // 解析响应数据
      if (response is Map<String, dynamic> && response['code'] == 0) {
        return {
          'code': 0,
          'msg': 'success',
          'data': response['data'] ?? {},
        };
      } else {
        return {
          'code': response['code'] ?? 1003,
          'msg': response['msg'] ?? '点赞失败',
        };
      }
    } catch (e) {
      print('点赞评论异常: $e');
      return {
        'code': 5003,
        'msg': '点赞评论异常: ${e.toString()}',
      };
    }
  }

  /// 删除评论
  Future<Map<String, dynamic>> deleteComment(int commentId) async {
    try {
      // 构建请求参数
      final Map<String, dynamic> params = {
        'comment_id': commentId,
        'user_id': 1, // 模拟用户ID，实际应从用户会话中获取
        'is_admin': 0, // 模拟普通用户权限
      };

      // 调用API删除评论
      final response = await post('/v1/comment/deleteComment', data: params);

      // 解析响应数据
      if (response is Map<String, dynamic> && response['code'] == 0) {
        return {
          'code': 0,
          'msg': 'success',
        };
      } else {
        return {
          'code': response['code'] ?? 1004,
          'msg': response['msg'] ?? '删除评论失败',
        };
      }
    } catch (e) {
      print('删除评论异常: $e');
      return {
        'code': 5004,
        'msg': '删除评论异常: ${e.toString()}',
      };
    }
  }

  /// 模拟获取评论数据（当后端API未就绪时使用）
  Future<Map<String, dynamic>> getMockComments(int vodId, {int page = 1, int limit = 20}) async {
    // 延迟500ms模拟网络请求
    await Future.delayed(Duration(milliseconds: 500));

    // 模拟评论数据
    final List<Map<String, dynamic>> mockComments = [
      {
        'comment_id': 1,
        'comment_mid': 1,
        'comment_rid': vodId,
        'comment_pid': 0,
        'user_id': 1,
        'comment_status': 1,
        'comment_name': '站长',
        'comment_time': DateTime.now().subtract(Duration(days: 2)).millisecondsSinceEpoch ~/ 1000,
        'comment_content': '这部番剧真的很好看，推荐大家观看！',
        'comment_up': 42,
        'comment_down': 0,
        'comment_reply': 2,
        'user_portrait': '',
        'replies': [
          {
            'comment_id': 3,
            'comment_mid': 1,
            'comment_rid': vodId,
            'comment_pid': 1,
            'user_id': 2,
            'comment_status': 1,
            'comment_name': '动漫迷',
            'comment_time': DateTime.now().subtract(Duration(days: 1, hours: 12)).millisecondsSinceEpoch ~/ 1000,
            'comment_content': '同意，画面和剧情都很棒！',
            'comment_up': 15,
            'comment_down': 0,
            'comment_reply': 0,
            'user_portrait': '',
          },
          {
            'comment_id': 4,
            'comment_mid': 1,
            'comment_rid': vodId,
            'comment_pid': 1,
            'user_id': 3,
            'comment_status': 1,
            'comment_name': '二次元控',
            'comment_time': DateTime.now().subtract(Duration(hours: 18)).millisecondsSinceEpoch ~/ 1000,
            'comment_content': '我已经看了三遍了，每次都有新发现',
            'comment_up': 8,
            'comment_down': 0,
            'comment_reply': 0,
            'user_portrait': '',
          }
        ]
      },
      {
        'comment_id': 2,
        'comment_mid': 1,
        'comment_rid': vodId,
        'comment_pid': 0,
        'user_id': 4,
        'comment_status': 1,
        'comment_name': '路人甲',
        'comment_time': DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
        'comment_content': '剧情发展有点慢，但是人物刻画很细腻',
        'comment_up': 18,
        'comment_down': 2,
        'comment_reply': 0,
        'user_portrait': '',
        'replies': []
      },
      {
        'comment_id': 5,
        'comment_mid': 1,
        'comment_rid': vodId,
        'comment_pid': 0,
        'user_id': 5,
        'comment_status': 1,
        'comment_name': '番剧爱好者',
        'comment_time': DateTime.now().subtract(Duration(hours: 6)).millisecondsSinceEpoch ~/ 1000,
        'comment_content': '音乐配得真好，尤其是高潮部分的背景音乐',
        'comment_up': 27,
        'comment_down': 0,
        'comment_reply': 0,
        'user_portrait': '',
        'replies': []
      },
      {
        'comment_id': 6,
        'comment_mid': 1,
        'comment_rid': vodId,
        'comment_pid': 0,
        'user_id': 6,
        'comment_status': 1,
        'comment_name': '动漫迷小王',
        'comment_time': DateTime.now().subtract(Duration(hours: 3)).millisecondsSinceEpoch ~/ 1000,
        'comment_content': '期待下一集，希望能快点更新',
        'comment_up': 12,
        'comment_down': 0,
        'comment_reply': 0,
        'user_portrait': '',
        'replies': []
      },
    ];

    // 返回模拟数据
    return {
      'code': 0,
      'msg': 'success',
      'total': mockComments.length,
      'list': mockComments,
      'page': page,
      'pages': 1,
    };
  }

  /// 获取视频平均分
  Future<dynamic> getScoreAverage(int vodId) async {
    try {
      final result = await get('/v1/score/average', queryParameters: {'vod_id': vodId});
      return result;
    } catch (e) {
      print('获取平均分失败: $e');
      rethrow;
    }
  }

  /// 获取评分详情
  Future<dynamic> getScoreDetails(int vodId) async {
    try {
      final result = await get('/v1/score/details', queryParameters: {'vod_id': vodId});
      return result;
    } catch (e) {
      print('获取评分详情失败: $e');
      rethrow;
    }
  }

  /// 新增评分
  Future<dynamic> addScore({
    required int vodId,
    required String username,
    required double score,
    String? comment,
  }) async {
    try {
      final data = {
        'vod_id': vodId,
        'username': username,
        'score': score,
        if (comment != null) 'comment': comment,
      };
      final result = await post('/v1/score/add', data: data);
      return result;
    } catch (e) {
      print('新增评分失败: $e');
      rethrow;
    }
  }

  /// 用户注册
  Future<dynamic> registerUser({
    required String username,
    required String password,
    required String nickname,
    required String email,
    String? userQq,
  }) async {
    try {
      final data = {
        'username': username,
        'password': password,
        'nickname': nickname,
        'email': email,
        'user_qq': userQq ?? '',
      };
      final result = await post('/user/register', data: data);
      return result;
    } catch (e) {
      print('注册失败: ' + e.toString());
      rethrow;
    }
  }

  /// 获取云端观看历史
  Future<Map<String, dynamic>> getCloudHistory({int page = 1, int limit = 20}) async {
    final response = await get('/user/history', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return response;
  }

  /// 添加云端观看历史
  Future<Map<String, dynamic>> addCloudHistory({
    required int vodId,
    int? episodeIndex,
    String? playSource,
    String? playUrl,
    int? playProgress,
  }) async {
    final params = {
      'vod_id': vodId,
      if (episodeIndex != null) 'episode_index': episodeIndex,
      if (playSource != null) 'play_source': playSource,
      if (playUrl != null) 'play_url': playUrl,
      if (playProgress != null) 'play_progress': playProgress,
    };
    final response = await post('/user/history', data: params);
    return response;
  }

  /// 删除单个历史记录
  Future<bool> deleteHistoryItem(String vodId) async {
    try {
      final response = await _dio.delete('/user/history/$vodId');
      if (response.statusCode == 200 && (response.data['code'] == 200 || response.data['code'] == 0)) {
        return true;
      }
      return false;
    } catch (e) {
      print('删除单个历史记录失败: $e');
      return false;
    }
  }

  /// 删除全部历史记录
  Future<bool> deleteAllHistory() async {
    try {
      final response = await _dio.delete('/user/history/all');
      if (response.statusCode == 200 && (response.data['code'] == 200 || response.data['code'] == 0)) {
        return true;
      }
      return false;
    } catch (e) {
      print('删除全部历史记录失败: $e');
      return false;
    }
  }

  /// 获取节目表
  Future<Map<String, List<dynamic>>> getSchedule() async {
    final result = await get('/schedule');
    if (result is Map<String, dynamic> && result.containsKey('schedule')) {
      final schedule = result['schedule'] as Map<String, dynamic>;
      // 转换为 Map<String, List<dynamic>>
      return schedule.map((k, v) => MapEntry(k, v as List<dynamic>));
    }
    return {};
  }

  /// 获取正在观看人数
  Future<int?> getWatchingCount(int vodId) async {
    try {
      final result = await get('/v1/watching', queryParameters: {'vod_id': vodId});
      if (result is Map && result['msg'] == 'ok' && result['watching_count'] != null) {
        return int.tryParse(result['watching_count'].toString());
      }
      return null;
    } catch (e) {
      print('获取正在观看人数失败: $e');
      return null;
    }
  }

  /// 查询视频是否已点赞
  Future<bool> isVideoLiked(int vodId) async {
    // 确保token已设置
    if (_token == null || _token!.isEmpty) {
      final userToken = UserStore().user?.token;
      if (userToken != null && userToken.isNotEmpty) {
        setToken(userToken);
      }
    }
    try {
      final result = await get('/v1/user/isliked', queryParameters: {'vod_id': vodId});
      // result 实际就是 {vod_id: 87, liked: true}
      if (result is Map && result['liked'] != null) {
        return result['liked'] == true;
      }
      return false;
    } catch (e) {
      print('查询视频点赞状态失败: $e');
      return false;
    }
  }

  /// 点赞/取消点赞视频
  Future<Map<String, dynamic>> likeVideo(int vodId, bool like) async {
    // 确保token已设置
    if (_token == null || _token!.isEmpty) {
      final userToken = UserStore().user?.token;
      if (userToken != null && userToken.isNotEmpty) {
        setToken(userToken);
      }
    }
    try {
      final result = await post('/v1/user/like', data: {
        'vod_id': vodId,
        'dianzan': like,
      });
      if (result is Map && result['code'] == 200 && result.containsKey('zan')) {
        return {
          'zan': result['zan'] == true,
          'vod_up': result['vod_up'] ?? 0,
        };
      }
      return {'zan': false, 'vod_up': 0};
    } catch (e) {
      print('视频点赞/取消点赞失败: $e');
      return {'zan': false, 'vod_up': 0};
    }
  }

  /// 查询视频是否已收藏
  Future<bool> isVideoFavorited(int vodId) async {
    // 确保token已设置
    if (_token == null || _token!.isEmpty) {
      final userToken = UserStore().user?.token;
      if (userToken != null && userToken.isNotEmpty) {
        setToken(userToken);
      }
    }
    try {
      final result = await get('/v1/user/isfavorite', queryParameters: {'vod_id': vodId});
      if (result is Map && result['code'] == 200 && result.containsKey('favorites')) {
        return result['favorites'] == true;
      }
      return false;
    } catch (e) {
      print('查询视频收藏状态失败: $e');
      return false;
    }
  }

  /// 添加收藏
  Future<bool> addVideoFavorite(int vodId) async {
    // 确保token已设置
    if (_token == null || _token!.isEmpty) {
      final userToken = UserStore().user?.token;
      if (userToken != null && userToken.isNotEmpty) {
        setToken(userToken);
      }
    }
    try {
      final result = await post('/v1/user/favorites', data: {'vod_id': vodId});
      // result 实际就是 {favorite_id: 3, user_id: 5, vod_id: 87, create_time: ...}
      if (result is Map && result['favorite_id'] != null) {
        return true;
      }
      return false;
    } catch (e) {
      print('添加收藏失败: $e');
      return false;
    }
  }

  /// 取消收藏
  Future<bool> removeVideoFavorite(int vodId) async {
    // 确保token已设置
    if (_token == null || _token!.isEmpty) {
      final userToken = UserStore().user?.token;
      if (userToken != null && userToken.isNotEmpty) {
        setToken(userToken);
      }
    }
    try {
      final response = await _dio.delete('/v1/user/favorites/$vodId');
      if (response.statusCode == 200 && (response.data['code'] == 200 || response.data['msg'] == 'success')) {
        return true;
      }
      return false;
    } catch (e) {
      print('取消收藏失败: $e');
      return false;
    }
  }
}

/// 评论区组件
class CommentSection extends StatefulWidget {
  final int vodId;

  const CommentSection({
    Key? key,
    required this.vodId,
  }) : super(key: key);

  @override
  _CommentSectionState createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final OvoApiManager _apiManager = OvoApiManager();
  final TextEditingController _commentController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<dynamic> _commentList = [];
  int _currentPage = 1;
  int _totalPages = 1;

  // 展开回复的评论ID
  int? _expandedCommentId;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// 获取评论列表
  Future<void> _fetchComments({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
      });
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 调用评论服务获取评论
      // 注意：这里使用模拟数据，实际应用中应使用真实API
      final result = await _apiManager.getMockComments(
        widget.vodId,
        page: _currentPage,
      );

      if (result['code'] == 0) {
        setState(() {
          _commentList = result['list'] as List<dynamic>;
          _totalPages = result['pages'] as int;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['msg'] as String;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '获取评论失败: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// 发表评论
  Future<void> _submitComment({int pid = 0}) async {
    final String content = _commentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('评论内容不能为空')),
      );
      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
      });

      // 调用评论服务发表评论
      final result = await _apiManager.addComment(
        widget.vodId,
        content,
        pid: pid,
      );

      if (result['code'] == 0) {
        // 清空输入框
        _commentController.clear();

        // 刷新评论列表
        _fetchComments(refresh: true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('评论发表成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['msg'] as String),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('发表评论失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  /// 点赞评论
  Future<void> _likeComment(int commentId, int index) async {
    try {
      // 调用评论服务点赞评论
      final result = await _apiManager.likeComment(commentId);

      if (result['code'] == 0) {
        // 更新本地评论数据
        setState(() {
          _commentList[index]['comment_up'] = (_commentList[index]['comment_up'] as int) + 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('点赞成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['msg'] as String),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('点赞失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 切换回复展开状态
  void _toggleReplies(int commentId) {
    setState(() {
      if (_expandedCommentId == commentId) {
        _expandedCommentId = null;
      } else {
        _expandedCommentId = commentId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Colors.pink),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchComments(refresh: true),
              child: Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 评论列表
        Expanded(
          child: _commentList.isEmpty
              ? _buildEmptyComments()
              : _buildCommentList(),
        ),

        // 评论输入框
        _buildCommentInput(),
      ],
    );
  }

  /// 构建空评论提示
  Widget _buildEmptyComments() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 48),
          SizedBox(height: 16),
          Text(
            '暂无评论，快来发表你的看法吧',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// 构建评论列表
  Widget _buildCommentList() {
    return RefreshIndicator(
      onRefresh: () => _fetchComments(refresh: true),
      color: Colors.pink,
      child: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: _commentList.length,
        separatorBuilder: (context, index) => Divider(height: 32),
        itemBuilder: (context, index) {
          final comment = _commentList[index];

          final int commentId = comment['comment_id'] as int;
          final String userName = comment['comment_name'] as String;
          final String content = comment['comment_content'] as String;
          final int timestamp = comment['comment_time'] as int;
          final int upCount = comment['comment_up'] as int;
          final int replyCount = comment['comment_reply'] as int;
          final List<dynamic> replies = comment['replies'] as List<dynamic>;

          // 将时间戳转换为日期
          final DateTime commentDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          final String formattedDate = '${commentDate.year}-${commentDate.month.toString().padLeft(2, '0')}-${commentDate.day.toString().padLeft(2, '0')}';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 主评论
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 用户头像
                  CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                  SizedBox(width: 12),

                  // 评论内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 用户名和日期
                        Row(
                          children: [
                            Text(
                              userName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            Spacer(),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),

                        // 评论内容
                        Text(
                          content,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),

                        // 操作按钮
                        Row(
                          children: [
                            // 点赞按钮
                            GestureDetector(
                              onTap: () => _likeComment(commentId, index),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.thumb_up_outlined,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    upCount.toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16),

                            // 回复按钮
                            GestureDetector(
                              onTap: () {
                                // 显示回复对话框
                                _showReplyDialog(commentId, userName);
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.reply,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '回复',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 回复列表
              if (replyCount > 0) ...[
                SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _toggleReplies(commentId),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _expandedCommentId == commentId
                          ? '收起 $replyCount 条回复'
                          : '查看 $replyCount 条回复',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),

                // 展开的回复列表
                if (_expandedCommentId == commentId) ...[
                  SizedBox(height: 12),
                  ...replies.map((reply) {
                    final String replyUserName = reply['comment_name'] as String;
                    final String replyContent = reply['comment_content'] as String;
                    final int replyTimestamp = reply['comment_time'] as int;
                    final int replyUpCount = reply['comment_up'] as int;

                    // 将时间戳转换为日期
                    final DateTime replyDate = DateTime.fromMillisecondsSinceEpoch(replyTimestamp * 1000);
                    final String formattedReplyDate = '${replyDate.year}-${replyDate.month.toString().padLeft(2, '0')}-${replyDate.day.toString().padLeft(2, '0')}';

                    return Padding(
                      padding: EdgeInsets.only(left: 40, top: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 用户头像
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.grey.shade200,
                            child: Text(
                              replyUserName.isNotEmpty ? replyUserName[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),

                          // 回复内容
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 用户名和日期
                                Row(
                                  children: [
                                    Text(
                                      replyUserName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Spacer(),
                                    Text(
                                      formattedReplyDate,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),

                                // 回复内容
                                Text(
                                  replyContent,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 4),

                                // 点赞按钮
                                Row(
                                  children: [
                                    Icon(
                                      Icons.thumb_up_outlined,
                                      size: 12,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      replyUpCount.toString(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  /// 构建评论输入框
  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // 输入框
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: '发表你的评论...',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitComment(),
            ),
          ),
          SizedBox(width: 8),

          // 发送按钮
          ElevatedButton(
            onPressed: _isSubmitting ? null : () => _submitComment(),
            child: _isSubmitting
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Text('发送'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示回复对话框
  void _showReplyDialog(int commentId, String userName) {
    final TextEditingController replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('回复 @$userName'),
        content: TextField(
          controller: replyController,
          decoration: InputDecoration(
            hintText: '输入回复内容...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final String content = replyController.text.trim();
              if (content.isNotEmpty) {
                Navigator.pop(context);
                // 发表回复
                _apiManager.addComment(
                  widget.vodId,
                  content,
                  pid: commentId,
                ).then((_) {
                  // 刷新评论列表
                  _fetchComments(refresh: true);
                });
              }
            },
            child: Text('回复'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
            ),
          ),
        ],
      ),
    );
  }
}

