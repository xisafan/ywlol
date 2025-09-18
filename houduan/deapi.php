<?php
/**
 * OVO API 入口文件
 * 
 * 提供RESTful API接口，支持Flutter跨平台应用
 * 
 * @author Manus AI
 * @version 1.0.2
 * @date 2025-05-20
 */

// 设置响应头
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

// 处理OPTIONS请求（预检请求）
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// 定义API版本和基础路径
define('API_VERSION', 'v1');
define('API_BASE_PATH', '/api/' . API_VERSION);

// 引入数据库配置
$db_config_file = __DIR__ . '/database.php';
if (!file_exists($db_config_file)) {
    response_error(500, '数据库配置文件不存在');
}

// 加载数据库配置
$db_config = include($db_config_file);

// 连接数据库
try {
    $dsn = "mysql:host={$db_config['hostname']};port={$db_config['hostport']};dbname={$db_config['database']};charset={$db_config['charset']}";
    $pdo = new PDO($dsn, $db_config['username'], $db_config['password']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->exec("SET NAMES 'utf8mb4'");      
    
    // 设置表前缀
    define('DB_PREFIX', $db_config['prefix']);
} catch (PDOException $e) {
    response_error(500, '数据库连接失败: ' . $e->getMessage());
}

// 引入JWT库
require_once __DIR__ . '/api/lib/jwt.php';

// 引入API控制器
require_once __DIR__ . '/api/controllers/UserController.php';
require_once __DIR__ . '/api/controllers/VideoController.php';
require_once __DIR__ . '/api/controllers/ParseController.php';
require_once __DIR__ . '/api/controllers/SystemController.php';
require_once __DIR__ . '/api/controllers/BannerController.php';
require_once __DIR__ . '/api/controllers/HotvedioController.php';
require_once __DIR__ . '/api/controllers/ClassifyController.php';
require_once __DIR__ . '/api/controllers/commentController.php'; // 引入评论控制器
require_once __DIR__ . '/api/controllers/ScoreController.php';
require_once __DIR__ . '/api/controllers/RankController.php';

use app\api\controllers\CommentController;

// 获取请求路径
$request_uri = $_SERVER['REQUEST_URI'];

// 支持两种URL格式:
// 1. /ovo/api.php/v1/videos (直接路径风格)
// 2. /ovo/api.php?s=/api/v1/videos (查询参数风格)

// 检查是否使用查询参数风格
if (isset($_GET['s'])) {
    $path = $_GET['s'];
} else {
    // 使用直接路径风格
    $path = parse_url($request_uri, PHP_URL_PATH);
    
    // 移除脚本名称部分
    $script_name = $_SERVER['SCRIPT_NAME'];
    if (strpos($path, $script_name) === 0) {
        $path = substr($path, strlen($script_name));
    }
}

// 如果路径以/v1开头，添加/api前缀
if (strpos($path, '/' . API_VERSION) === 0) {
    $path = '/api' . $path;
}

// 移除基础路径前缀，获取实际API路径
$api_path = preg_replace('#^' . preg_quote(API_BASE_PATH) . '#', '', $path);

// 获取请求方法
$method = $_SERVER['REQUEST_METHOD'];

// 获取请求参数
$params = [];
if ($method == 'GET') {
    $params = $_GET;
    // 移除s参数
    if (isset($params['s'])) {
        unset($params['s']);
    }
} else if ($method == 'POST' || $method == 'PUT' || $method == 'DELETE') {
    $input = file_get_contents('php://input');
    if (!empty($input)) {
        $json_params = json_decode($input, true);
        if ($json_params) {
            $params = $json_params;
        }
    }
    
    // 合并POST参数
    if (!empty($_POST)) {
        $params = array_merge($params, $_POST);
    }
}

// 获取认证信息
$auth_header = isset($_SERVER['HTTP_AUTHORIZATION']) ? $_SERVER['HTTP_AUTHORIZATION'] : '';
$token = null;

if (!empty($auth_header) && preg_match('/Bearer\s+(.*)$/i', $auth_header, $matches)) {
    $token = $matches[1];
}

// 路由处理
try {
    // 定义需要认证的路由
    $auth_routes = [
        '#^/user/favorites(/.+)?$#' => true,
        '#^/user/history(/.+)?$#' => true,
        '#^/user/profile(/.+)?$#' => true,
        '#^/user/refresh_token$#' => false, // 刷新令牌不需要验证token
        '#^/user/danmaku$#' => true,
    ];
    
    // 检查是否需要认证
    $need_auth = false;
    foreach ($auth_routes as $pattern => $required) {
        if (preg_match($pattern, $api_path)) {
            $need_auth = $required;
            break;
        }
    }
    
    // 如果需要认证，验证token
    $user_id = null;
    if ($need_auth) {
        if (empty($token)) {
            response_error(401, '未授权访问，请先登录');
        }
        
        try {
            $jwt = new JWT();
            $payload = $jwt->decode($token);
            
            if (!isset($payload['user_id']) || empty($payload['user_id'])) {
                response_error(401, '无效的认证信息');
            }
            
            $user_id = $payload['user_id'];
            
            // 检查token是否过期
            if (isset($payload['exp']) && $payload['exp'] < time()) {
                response_error(401, '认证已过期，请重新登录');
            }
        } catch (Exception $e) {
            response_error(401, '认证验证失败: ' . $e->getMessage());
        }
    }
    
    // 路由分发
    if (preg_match('#^/user/login$#', $api_path) && ($method == 'POST' || $method == 'GET')) {
        // 用户登录 - 支持GET和POST
        $controller = new UserController($pdo);
        $controller->login($params);
    } else if (preg_match('#^/user/refresh_token$#', $api_path) && ($method == 'POST' || $method == 'GET')) {
        // 刷新令牌 - 支持GET和POST
        $controller = new UserController($pdo);
        $controller->refreshToken($params);
    } else if (preg_match('#^/user/register$#', $api_path) && ($method == 'POST' || $method == 'GET')) {
        // 用户注册 - 支持GET和POST
        $controller = new UserController($pdo);
        $controller->register($params);
    } else if (preg_match('#^/user/profile$#', $api_path) && $method == 'GET') {
        // 获取用户信息
        $controller = new UserController($pdo);
        $controller->getProfile($user_id);
    } else if (preg_match('#^/user/favorites$#', $api_path) && $method == 'GET') {
        // 获取收藏列表
        $controller = new UserController($pdo);
        $controller->getFavorites($user_id, $params);
    } else if (preg_match('#^/user/favorites$#', $api_path) && ($method == 'POST' || $method == 'GET')) {
        // 添加收藏 - 支持GET和POST
        $controller = new UserController($pdo);
        $controller->addFavorite($user_id, $params);
    } else if (preg_match('#^/user/favorites/(\d+)$#', $api_path, $matches) && ($method == 'DELETE' || $method == 'GET')) {
        // 删除收藏 - 支持GET和DELETE
        $vod_id = $matches[1];
        $controller = new UserController($pdo);
        $controller->deleteFavorite($user_id, $vod_id);
    } else if (preg_match('#^/user/history$#', $api_path) && $method == 'GET') {
        // 获取播放历史
        $controller = new UserController($pdo);
        $controller->getHistory($user_id, $params);
    } else if (preg_match('#^/user/history$#', $api_path) && ($method == 'POST' || $method == 'GET')) {
        // 添加播放历史 - 支持GET和POST
        $controller = new UserController($pdo);
        $controller->addHistory($user_id, $params);
    } else if (preg_match('#^/user/history/(\d+)$#', $api_path, $matches) && ($method == 'DELETE' || $method == 'GET')) {
        // 删除播放历史 - 支持GET和DELETE
        $vod_id = $matches[1];
        $controller = new UserController($pdo);
        $controller->deleteHistory($user_id, $vod_id);
    } else if (preg_match('#^/videos$#', $api_path) && $method == 'GET') {
        // 获取视频列表
        $controller = new VideoController($pdo);
        $controller->getList($params);
    } else if (preg_match('#^/videos/(\d+)$#', $api_path, $matches) && $method == 'GET') {
        // 获取视频详情
        $vod_id = $matches[1];
        $controller = new VideoController($pdo);
        $controller->getDetail($vod_id);
    } else if (preg_match('#^/search$#', $api_path) && $method == 'GET') {
        // 搜索视频
        $controller = new VideoController($pdo);
        $controller->search($params);
    } else if (preg_match('#^/parse$#', $api_path) && ($method == 'POST' || $method == 'GET')) {
        // 解析视频地址 - 支持GET和POST
        $controller = new ParseController($pdo);
        $controller->parseUrl($params);
    } else if (preg_match('#^/parsers$#', $api_path) && $method == 'GET') {
        // 获取解析器列表
        $controller = new ParseController($pdo);
        $controller->getList();
    } else if (preg_match('#^/announcements$#', $api_path) && $method == 'GET') {
        // 获取公告
        $controller = new SystemController($pdo);
        $controller->getAnnouncements();
    } else if (preg_match('#^/check_update$#', $api_path) && $method == 'GET') {
        // 检查更新
        $controller = new SystemController($pdo);
        $controller->checkUpdate($params);
    } else if (preg_match('#^/config$#', $api_path) && $method == 'GET') {
        // 获取应用配置
        $controller = new SystemController($pdo);
        $controller->getConfig();
    } else if (preg_match('#^/banners$#', $api_path) && $method == 'GET') {
        // 获取轮播图列表
        $controller = new BannerController($pdo);
        $controller->getList();
    } else if (preg_match('#^/hotvedios$#', $api_path) && $method == 'GET') {
        // 获取热播视频列表
        $controller = new HotvedioController($pdo);
        $controller->getList($params);
    } else if (preg_match('#^/types$#', $api_path) && $method == 'GET') {
        // 获取所有分类列表
        $controller = new ClassifyController($pdo);
        $controller->getAllTypes();
    } else if (preg_match('#^/classify$#', $api_path) && $method == 'GET') {
        // 获取分类下的视频列表
        $controller = new ClassifyController($pdo);
        $controller->getListByType($params);
    } else if (preg_match('#^/schedule$#', $api_path) && $method == 'GET') {
        // 获取排期表
        $controller = new VideoController($pdo);
        $controller->getSchedule($params);
    } else if (preg_match('#^/vod_extends$#', $api_path) && $method == 'GET') {
        // 获取视频扩展分类
        $controller = new ClassifyController($pdo);
        $controller->getVodExtends();
    } else if (preg_match('#^/vod_extend_list$#', $api_path) && $method == 'GET') {
        // 通过扩展分类筛选视频
        $controller = new ClassifyController($pdo);
        $controller->getListByExtend($params);
    } else if (preg_match('#^/watching$#', $api_path) && $method == 'GET') {
        // 用户在看状态上报
        $controller = new SystemController($pdo);
        $controller->watching($user_id, $params);
    } 
    // 评论相关API路由
    else if (preg_match('#^/comment/getComments$#', $api_path) && $method == 'GET') {
        // 获取评论列表
        $controller = new CommentController($pdo);
        $controller->getComments($params);
    } else if (preg_match('#^/comment/addComment$#', $api_path) && ($method == 'POST' || $method == 'GET')) {
        // 添加评论 - 支持GET和POST
        $controller = new CommentController($pdo);
        $controller->addComment($params);
    } else if (preg_match('#^/comment/likeComment$#', $api_path) && ($method == 'POST' || $method == 'GET')) {
        // 点赞评论 - 支持GET和POST
        $controller = new CommentController($pdo);
        $controller->likeComment($params);
    } else if (preg_match('#^/comment/deleteComment$#', $api_path) && ($method == 'POST' || $method == 'GET')) {
        // 删除评论 - 支持GET和POST
        $controller = new CommentController($pdo);
        $controller->deleteComment($params);
    } else if (preg_match('#^/score/average$#', $api_path) && $method == 'GET') {
        $controller = new \app\api\controllers\ScoreController($pdo);
        $controller->getAverageScore($params);
    } else if (preg_match('#^/score/details$#', $api_path) && $method == 'GET') {
        $controller = new \app\api\controllers\ScoreController($pdo);
        $controller->getScoreDetails($params);
    } else if (preg_match('#^/score/add$#', $api_path) && ($method == 'POST' || $method == 'GET')) {
        $controller = new \app\api\controllers\ScoreController($pdo);
        $controller->addScore($params);
    } else if (preg_match('#^/top$#', $api_path) && $method == 'GET') {
        $controller = new \app\api\controllers\RankController($pdo);
        $controller->getTop($params);
    } else if (preg_match('#^/user/like$#', $api_path) && $method == 'POST') {
        // 用户点赞/取消点赞
        $controller = new UserController($pdo);
        $controller->likeVod($user_id, $params);
    } else if (preg_match('#^/user/isliked$#', $api_path) && $method == 'GET') {
        // 查询用户是否点赞
        $controller = new UserController($pdo);
        $controller->isLiked($user_id, $params);
    } else if (preg_match('#^/checkconnent$#', $api_path) && $method == 'GET') {
        // 数据库连接检测
        $controller = new SystemController($pdo);
        $controller->checkConnent();
    } else if (preg_match('#^/user/danmaku$#', $api_path) && $method == 'POST') {
        // 发送弹幕（需要token）
        $controller = new UserController($pdo);
        $controller->sendDanmaku($user_id, $params);
    } else if (preg_match('#^/danmaku$#', $api_path) && $method == 'GET') {
        // 查询弹幕（不需要token）
        $controller = new UserController($pdo);
        $controller->getDanmaku($params);
    } else {
        // 未找到匹配的路由
        response_error(404, '请求的API接口不存在: ' . $api_path);
    }
} catch (Exception $e) {
    response_error(500, '服务器错误: ' . $e->getMessage());
}

/**
 * 输出成功响应
 *
 * @param mixed $data 响应数据
 * @return void
 */
function response_success($data = null) {
    global $pdo;
    $stmt = $pdo->prepare('SELECT encrypt_key FROM mac_ovo_setting LIMIT 1');
    $stmt->execute();
    $setting = $stmt->fetch(PDO::FETCH_ASSOC);
    $encrypt_key = $setting['encrypt_key'] ?? '';
    
    // 设置HTTP状态码为200
    http_response_code(200);
    
    // 原始响应数据 - 修改code为0以匹配前端期望
    $original_response = [
        'code' => 0, // 修改：从200改为0，与前端期望一致
        'msg' => 'success',
        'data' => $data,
        'timestamp' => time() * 1000
    ];
    
    // AES加密原始响应
    $timestamp = time();
    $iv = substr(hash('sha256', $timestamp), 0, 16); // 修改：使用秒级时间戳生成IV
    $encrypted = openssl_encrypt(
        json_encode($original_response, JSON_UNESCAPED_UNICODE),
        'AES-128-CBC',
        $encrypt_key,
        OPENSSL_RAW_DATA,
        $iv
    );
    
    // 构建新的JSON响应，将加密数据放在data字段中
    $json_response = [
        'code' => 200,
        'msg' => 'success',
        'data' => $original_response,
        'timestamp' => $timestamp * 1000 // 修改：使用与IV生成一致的时间戳
    ];
    
    // 输出JSON响应
    echo json_encode($json_response, JSON_UNESCAPED_UNICODE);
    exit;
}

/**
 * 输出错误响应
 *
 * @param int $code 错误码
 * @param string $msg 错误信息
 * @return void
 */
function response_error($code, $msg) {
    global $pdo;
    $stmt = $pdo->prepare('SELECT encrypt_key FROM mac_ovo_setting LIMIT 1');
    $stmt->execute();
    $setting = $stmt->fetch(PDO::FETCH_ASSOC);
    $encrypt_key = $setting['encrypt_key'] ?? '';
    
    // 设置HTTP状态码为200（始终返回200，错误信息在响应内容中体现）
    http_response_code(200);
    
    // 原始错误响应数据
    $original_response = [
        'code' => $code,
        'msg' => $msg,
        'data' => null,
        'timestamp' => time() * 1000
    ];
    
    // AES加密原始响应
    $timestamp = time();
    $iv = substr(hash('sha256', $timestamp), 0, 16); // 修改：使用秒级时间戳生成IV
    $encrypted = openssl_encrypt(
        json_encode($original_response, JSON_UNESCAPED_UNICODE),
        'AES-128-CBC',
        $encrypt_key,
        OPENSSL_RAW_DATA,
        $iv
    );
    
    // 构建新的JSON响应，将加密数据放在data字段中
    $json_response = [
        'code' => 200,
        'msg' => 'success',
        'data' => $original_response,
        'timestamp' => $timestamp * 1000 // 修改：使用与IV生成一致的时间戳
    ];
    
    // 输出JSON响应
    echo json_encode($json_response, JSON_UNESCAPED_UNICODE);
    exit;
}
