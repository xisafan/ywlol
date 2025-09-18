<?php
/**
 * Session调试页面
 * 
 * 用于调试验证码Session问题
 */

// 启动Session
if (session_status() == PHP_SESSION_NONE) {
    session_set_cookie_params([
        'lifetime' => 1800, // 30分钟
        'path' => '/',
        'domain' => '',
        'secure' => false, // HTTP环境设置为false
        'httponly' => false, // 允许JavaScript访问
        'samesite' => 'None' // 跨域访问必需
    ]);
    session_start();
}

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Access-Control-Allow-Credentials: true');

$action = $_GET['action'] ?? 'info';

switch ($action) {
    case 'info':
        // 显示Session信息
        echo json_encode([
            'session_id' => session_id(),
            'session_status' => session_status(),
            'session_name' => session_name(),
            'session_data' => $_SESSION,
            'cookies' => $_COOKIE,
            'php_session_config' => [
                'session.cookie_lifetime' => ini_get('session.cookie_lifetime'),
                'session.cookie_path' => ini_get('session.cookie_path'),
                'session.cookie_domain' => ini_get('session.cookie_domain'),
                'session.cookie_secure' => ini_get('session.cookie_secure'),
                'session.cookie_httponly' => ini_get('session.cookie_httponly'),
                'session.cookie_samesite' => ini_get('session.cookie_samesite'),
            ],
            'timestamp' => time(),
            'captcha_exists' => isset($_SESSION['captcha_code']),
            'captcha_code' => $_SESSION['captcha_code'] ?? null,
            'captcha_time' => $_SESSION['captcha_time'] ?? null,
            'captcha_age' => isset($_SESSION['captcha_time']) ? (time() - $_SESSION['captcha_time']) : null,
        ]);
        break;
        
    case 'set_test':
        // 设置测试验证码
        $_SESSION['captcha_code'] = 'test';
        $_SESSION['captcha_time'] = time();
        echo json_encode([
            'message' => '测试验证码已设置',
            'captcha_code' => $_SESSION['captcha_code'],
            'captcha_time' => $_SESSION['captcha_time'],
            'session_id' => session_id(),
        ]);
        break;
        
    case 'clear':
        // 清除Session
        session_destroy();
        echo json_encode([
            'message' => 'Session已清除',
        ]);
        break;
        
    default:
        echo json_encode([
            'error' => '未知操作',
            'available_actions' => ['info', 'set_test', 'clear']
        ]);
        break;
}
?>
