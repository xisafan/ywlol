import 'package:dio/dio.dart';
import 'package:ovofun/models/user_model.dart';
import 'package:ovofun/services/api/ssl_Management.dart';

/// Token拦截器
///
/// 自动处理token过期并刷新token
class TokenInterceptor extends Interceptor {
  bool _isRefreshing = false;

  TokenInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 确保每个请求都携带最新的token
    final user = UserStore().user;
    if (user != null && user.token != null && user.token!.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${user.token}';
      print('[Token拦截器] 添加Authorization头: Bearer ${user.token}');
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    print(
      '[Token拦截器] 请求错误: ${err.response?.statusCode}, ${err.response?.data}',
    );

    // 检查是否是token过期错误（401）
    if (err.response?.statusCode == 401) {
      final responseData = err.response?.data;

      // 检查错误消息是否与token过期相关
      bool isTokenExpired = false;
      if (responseData is Map) {
        final msg = responseData['msg']?.toString() ?? '';
        isTokenExpired =
            msg.contains('认证验证失败') ||
            msg.contains('令牌已过期') ||
            msg.contains('认证已过期') ||
            msg.contains('登录已过期') ||
            msg.contains('登录状态异常') ||
            msg.contains('token') ||
            msg.contains('未授权');
      }

      if (isTokenExpired && !_isRefreshing) {
        print('[Token拦截器] 检测到token过期，尝试刷新...');

        // 防止重复刷新
        _isRefreshing = true;

        try {
          // 尝试刷新token
          final refreshedUser = await UserStore.refreshTokenIfNeeded();

          if (refreshedUser != null) {
            print('[Token拦截器] Token刷新成功，重试原始请求');

            // 更新API Manager的token
            OvoApiManager().setToken(refreshedUser.token!);

            // 重试原始请求
            final clonedRequest = err.requestOptions;
            clonedRequest.headers['Authorization'] =
                'Bearer ${refreshedUser.token}';

            try {
              // 从当前context获取dio实例
              final dio = err.response?.requestOptions.extra['dio'] as Dio?;
              if (dio != null) {
                final response = await dio.fetch(clonedRequest);
                handler.resolve(response);
                return;
              } else {
                print('[Token拦截器] 无法获取dio实例，创建新请求');
                final response = await OvoApiManager().get(
                  clonedRequest.path,
                  queryParameters: clonedRequest.queryParameters,
                );
                handler.resolve(
                  Response(
                    data: response,
                    requestOptions: clonedRequest,
                    statusCode: 200,
                  ),
                );
                return;
              }
            } catch (retryError) {
              print('[Token拦截器] 重试请求失败: $retryError');
              handler.reject(
                DioException(
                  requestOptions: err.requestOptions,
                  error: '重试请求失败: $retryError',
                ),
              );
              return;
            }
          } else {
            print('[Token拦截器] Token刷新失败，用户需要重新登录');
          }
        } catch (refreshError) {
          print('[Token拦截器] Token刷新异常: $refreshError');
        } finally {
          _isRefreshing = false;
        }
      }
    }

    // 其他错误或刷新失败，继续传递错误
    handler.next(err);
  }
}
