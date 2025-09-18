<?php
/**
 * OVO API 数据解密脚本
 *
 * 根据 api.php 中的加密逻辑，用于解密从 API 获取的数据。
 *
 * @author Manus AI
 * @version 1.0.0
 * @date 2024-05-23
 */

// 引入数据库配置
$db_config_file = __DIR__ . '/database.php';
if (!file_exists($db_config_file)) {
    die('数据库配置文件不存在');
}

// 加载数据库配置
$db_config = include($db_config_file);

// 连接数据库
try {
    $dsn = "mysql:host={$db_config['hostname']};port={$db_config['hostport']};dbname={$db_config['database']};charset={$db_config['charset']}";
    $pdo = new PDO($dsn, $db_config['username'], $db_config['password']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die('数据库连接失败: ' . $e->getMessage());
}

/**
 * 解密 API 响应数据
 *
 * @param string $encrypted_data Base64 编码的加密数据
 * @param int $timestamp 用于生成 IV 的时间戳 (毫秒)
 * @return mixed 解密后的数据 (通常是关联数组) 或 false (解密失败)
 */
function decryptApiResponse($encrypted_data, $timestamp) {
    global $pdo;

    // 获取加密密钥
    try {
        $stmt = $pdo->prepare('SELECT encrypt_key FROM mac_ovo_setting LIMIT 1');
        $stmt->execute();
        $setting = $stmt->fetch(PDO::FETCH_ASSOC);
        $encrypt_key = $setting['encrypt_key'] ?? '';

        if (empty($encrypt_key)) {
            echo "错误: 未找到加密密钥\n";
            return false;
        }
    } catch (PDOException $e) {
        echo "错误: 获取加密密钥失败 - " . $e->getMessage() . "\n";
        return false;
    }

    // Base64 解码
    $decoded_data = base64_decode($encrypted_data);
    if ($decoded_data === false) {
        echo "错误: Base64 解码失败\n";
        return false;
    }

    // 根据时间戳生成 IV (api.php 中 timestamp 是毫秒，这里需要秒)
    $iv = substr(hash('sha256', (string)($timestamp / 1000)), 0, 16);

    // AES 解密
    $decrypted_json = openssl_decrypt(
        $decoded_data,
        'AES-128-CBC',
        $encrypt_key,
        OPENSSL_RAW_DATA,
        $iv
    );

    if ($decrypted_json === false) {
        echo "错误: AES 解密失败 - " . openssl_error_string() . "\n";
        return false;
    }

    // JSON 解码
    $decrypted_data = json_decode($decrypted_json, true);
    if ($decrypted_data === null && json_last_error() !== JSON_ERROR_NONE) {
        echo "错误: JSON 解码失败 - " . json_last_error_msg() . "\n";
        return false;
    }

    return $decrypted_data;
}


// 处理 POST 请求
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // 获取 POST 参数
    $encrypted_data = $_POST['encrypted_data'] ?? '';
    $timestamp = $_POST['timestamp'] ?? '';

    // 验证参数
    if (empty($encrypted_data) || empty($timestamp)) {
        echo "错误: 请提供加密数据和时间戳";
    } else {
        // 调用解密函数
        $decrypted_result = decryptApiResponse($encrypted_data, (int)$timestamp);

        // 输出解密结果
        if ($decrypted_result !== false) {
            echo "解密成功:\n";
            // 使用 json_encode 格式化输出，方便HTML页面处理
            echo json_encode($decrypted_result, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        } else {
            // decryptApiResponse 函数内部已输出错误信息
            // echo "解密失败.";
        }
    }
} else {
    echo "请通过 POST 请求提交数据";
}

?>