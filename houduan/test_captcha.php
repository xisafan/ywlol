<?php
/**
 * 验证码功能测试页面
 * 
 * 用于测试验证码生成和验证功能
 */

// 引入必要的文件
require_once __DIR__ . '/api/controllers/CaptchaController.php';

// 通用响应函数
function response_success($data = null, $message = 'success') {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'code' => 0,
        'msg' => $message,
        'data' => $data,
        'timestamp' => time() * 1000
    ]);
    exit;
}

function response_error($code, $message, $data = null) {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'code' => $code,
        'msg' => $message,
        'data' => $data,
        'timestamp' => time() * 1000
    ]);
    exit;
}

$action = $_GET['action'] ?? 'generate';

$controller = new CaptchaController();

switch ($action) {
    case 'generate':
        $controller->generate();
        break;
    case 'verify':
        $captcha = $_GET['captcha'] ?? $_POST['captcha'] ?? '';
        $controller->verify(['captcha' => $captcha]);
        break;
    case 'refresh':
        $controller->refresh();
        break;
    default:
        echo '<h2>验证码测试页面</h2>';
        echo '<p><a href="?action=generate">生成验证码</a></p>';
        echo '<p><a href="?action=refresh">刷新验证码</a></p>';
        echo '<p>验证验证码: <a href="?action=verify&captcha=test">测试验证码</a></p>';
        break;
}
?>
