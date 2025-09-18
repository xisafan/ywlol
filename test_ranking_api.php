<?php
/**
 * 排行榜API测试脚本
 * 
 * 用于验证改进后的排行榜API是否正确返回新字段
 */

// 包含数据库配置
$dbConfig = require_once 'houduan/database.php';

// 创建数据库连接
define('DB_PREFIX', $dbConfig['prefix']);

try {
    $dsn = "mysql:host={$dbConfig['hostname']};port={$dbConfig['hostport']};dbname={$dbConfig['database']};charset={$dbConfig['charset']}";
    $pdo = new PDO($dsn, $dbConfig['username'], $dbConfig['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES {$dbConfig['charset']}"
    ]);
    echo "数据库连接成功！\n";
} catch (PDOException $e) {
    die("数据库连接失败: " . $e->getMessage() . "\n");
}

// 包含控制器文件
require_once 'houduan/api/controllers/RankController.php';

// 模拟response_success函数
function response_success($data) {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
}

// 测试获取排行榜（全部）
echo "=== 测试获取全部排行榜 ===\n";
$controller = new app\api\controllers\RankController($pdo);
$controller->getTop([]);

echo "\n\n=== 测试获取指定分类排行榜（type=1） ===\n";
$controller->getTop(['type' => 1]);

echo "\n\n=== 测试获取日榜（全部） ===\n";
$controller->getDayTop([]);

echo "\n\n=== 测试获取指定分类日榜（type=1） ===\n";
$controller->getDayTop(['type' => 1]);

echo "\n\n测试完成！\n";

// 输出字段说明
echo "\n=== 新增字段说明 ===\n";
echo "vod_class: 视频分类标签\n";
echo "vod_director: 导演信息\n";
echo "vod_actor: 演员信息（已有字段，保持兼容）\n";
echo "vod_score: 评分信息（已有字段，保持兼容）\n";
echo "vod_hits: 点击量（已有字段，保持兼容）\n";
?>
