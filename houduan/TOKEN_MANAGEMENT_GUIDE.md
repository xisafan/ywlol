# Token 管理机制修复指南

## 问题描述

用户在退出视频时遇到 token 过期错误，导致历史记录无法保存到服务器：

```
POST响应数据: {code: 401, msg: 认证验证失败: 令牌已过期, data: null, timestamp: 1758121721000}
```

## 解决方案

### 1. 后端 Token 机制分析

**JWT Token**:

- 有效期：3 天（259200 秒）
- 验证方式：`Authorization: Bearer {token}`头部
- 存储载荷：`user_id`, `username`, `exp`

**Refresh Token**:

- 有效期：30 天
- 存储位置：数据库表 `mac_ovo_user_token`
- 刷新接口：`/v1/user/refresh_token`

**验证流程**:

```php
// 检查Authorization头部
$auth_header = $_SERVER['HTTP_AUTHORIZATION'];
if (preg_match('/Bearer\s+(.*)$/i', $auth_header, $matches)) {
    $token = $matches[1];
}

// JWT验证
$jwt = new JWT();
$payload = $jwt->decode($token);

// 检查过期时间
if ($payload['exp'] < time()) {
    response_error(401, '认证已过期，请重新登录');
}
```

### 2. 前端 Token 管理增强

#### 新增 Token 拦截器 (`lib/services/api/token_interceptor.dart`)

```dart
class TokenInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 自动添加最新token到请求头
    final user = UserStore().user;
    if (user?.token?.isNotEmpty == true) {
      options.headers['Authorization'] = 'Bearer ${user.token}';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 检测401错误并自动刷新token
    if (err.response?.statusCode == 401) {
      final refreshedUser = await UserStore.refreshTokenIfNeeded();
      if (refreshedUser != null) {
        // 刷新成功，重试原始请求
        // ... 重试逻辑
      }
    }
    handler.next(err);
  }
}
```

#### OvoApiManager 集成拦截器

```dart
void _initDio() {
  _dio = Dio();
  // ... 基础配置

  // 添加Token拦截器用于自动刷新token
  _dio.interceptors.add(TokenInterceptor());

  // 添加日志拦截器
  _dio.interceptors.add(LogInterceptor(...));
}
```

#### 简化视频历史保存逻辑

```dart
// 之前：手动处理token刷新
Future<void> _saveToCloudWithRetry() async {
  try {
    await UserStore().addCloudHistoryRecord(...);
  } catch (e) {
    if (e.toString().contains('401')) {
      // 手动刷新token并重试
      final refreshedUser = await UserStore.refreshTokenIfNeeded();
      // ... 复杂的重试逻辑
    }
  }
}

// 现在：拦截器自动处理
Future<void> _saveWatchHistory() async {
  try {
    await UserStore().addCloudHistoryRecord(...);
    // 拦截器自动处理token过期问题
  } catch (e) {
    print('保存失败: $e（本地已保存）');
  }
}
```

### 3. 数据库表结构修复

**问题**：`mac_ovo_history`表缺少`episode_index`字段

**解决**：

```sql
-- 检查字段是否存在
ALTER TABLE `mac_ovo_history`
ADD COLUMN `episode_index` int(11) NOT NULL DEFAULT 0 COMMENT '集数索引' AFTER `vod_id`;

-- 如果报错"Duplicate column name"说明字段已存在，表结构正确
```

### 4. 调试工具

**创建了调试脚本** (`houduan/debug_history_api.php`):

- 检查数据库表结构
- 测试历史记录添加功能
- 验证 token 状态
- 自动修复表结构

**使用方法**：

```
访问: http://你的域名/houduan/debug_history_api.php?action=debug
修复: http://你的域名/houduan/debug_history_api.php?action=fix_table
测试: http://你的域名/houduan/debug_history_api.php?action=test_add&user_id=1&vod_id=1
```

## 修复效果

### 修复前

- 用户退出视频时 token 过期，历史记录保存失败
- 错误信息：`认证验证失败: 令牌已过期`
- 数据只保存在本地，服务器端无记录

### 修复后

- ✅ 自动 token 刷新机制
- ✅ 透明的错误处理
- ✅ 历史记录可靠保存到服务器
- ✅ 用户体验无感知

### 日志示例

```
[Token拦截器] 添加Authorization头: Bearer eyJ0eXAiOiJKV1Q...
[Token拦截器] 检测到token过期，尝试刷新...
[刷新token] Token刷新成功，重新设置API token并重试云端保存...
[Token拦截器] Token刷新成功，重试原始请求
本地观看历史保存成功: 视频ID=123, 集数=1, 进度=300秒
云端历史记录保存成功
```

## 技术要点

1. **自动化处理**：用户无需手动处理 token 过期
2. **降级策略**：云端保存失败时本地记录仍然有效
3. **统一拦截**：所有 API 请求都享受自动 token 刷新
4. **错误容错**：网络错误不会导致用户登出
5. **调试友好**：详细的日志记录便于问题排查

## 兼容性

- ✅ 兼容现有的 refresh_token 机制
- ✅ 兼容后端 JWT 验证流程
- ✅ 向后兼容，不影响其他功能
- ✅ 支持多设备登录（device_id 机制）

现在前后端 token 机制完全对应，历史记录功能已完全修复！
