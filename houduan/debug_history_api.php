<?php
/**
 * 调试历史记录API问题的辅助脚本
 * 
 * 用于诊断和修复历史记录功能问题
 * 
 * @author Assistant
 * @version 1.0.0
 * @date 2025-01-01
 */

// 设置响应头
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

// 处理OPTIONS请求
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// 引入数据库配置
$db_config_file = __DIR__ . '/database.php';
if (!file_exists($db_config_file)) {
    die(json_encode(['code' => 500, 'msg' => '数据库配置文件不存在']));
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
    die(json_encode(['code' => 500, 'msg' => '数据库连接失败: ' . $e->getMessage()]));
}

function response_success($data = null) {
    echo json_encode([
        'code' => 200,
        'msg' => 'success',
        'data' => $data,
        'timestamp' => time()
    ]);
    exit;
}

function response_error($code, $msg) {
    echo json_encode([
        'code' => $code,
        'msg' => $msg,
        'data' => null,
        'timestamp' => time()
    ]);
    exit;
}

/**
 * 调试历史记录表结构
 */
function debugHistoryTable($pdo) {
    $debug_info = [];
    
    try {
        // 检查表是否存在
        $sql = "SHOW TABLES LIKE '" . DB_PREFIX . "ovo_history'";
        $stmt = $pdo->query($sql);
        $table_exists = $stmt->rowCount() > 0;
        
        $debug_info['table_exists'] = $table_exists;
        
        if ($table_exists) {
            // 获取表结构
            $sql = "DESCRIBE " . DB_PREFIX . "ovo_history";
            $stmt = $pdo->query($sql);
            $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
            $debug_info['table_structure'] = $columns;
            
            // 检查是否有episode_index字段
            $has_episode_index = false;
            foreach ($columns as $column) {
                if ($column['Field'] === 'episode_index') {
                    $has_episode_index = true;
                    break;
                }
            }
            $debug_info['has_episode_index'] = $has_episode_index;
            
            // 统计记录数量
            $sql = "SELECT COUNT(*) as total FROM " . DB_PREFIX . "ovo_history";
            $stmt = $pdo->query($sql);
            $count = $stmt->fetch(PDO::FETCH_ASSOC);
            $debug_info['total_records'] = $count['total'];
            
            // 获取最近的几条记录
            $sql = "SELECT * FROM " . DB_PREFIX . "ovo_history ORDER BY update_time DESC LIMIT 5";
            $stmt = $pdo->query($sql);
            $recent_records = $stmt->fetchAll(PDO::FETCH_ASSOC);
            $debug_info['recent_records'] = $recent_records;
            
        }
        
        // 检查用户token表
        $sql = "SELECT COUNT(*) as total FROM " . DB_PREFIX . "ovo_user_token";
        $stmt = $pdo->query($sql);
        $token_count = $stmt->fetch(PDO::FETCH_ASSOC);
        $debug_info['token_total'] = $token_count['total'];
        
        // 检查有效token数量
        $sql = "SELECT COUNT(*) as active FROM " . DB_PREFIX . "ovo_user_token WHERE expire_time > NOW()";
        $stmt = $pdo->query($sql);
        $active_tokens = $stmt->fetch(PDO::FETCH_ASSOC);
        $debug_info['active_tokens'] = $active_tokens['active'];
        
        // 检查过期token
        $sql = "SELECT user_id, expire_time FROM " . DB_PREFIX . "ovo_user_token WHERE expire_time < NOW()";
        $stmt = $pdo->query($sql);
        $expired_tokens = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $debug_info['expired_tokens'] = $expired_tokens;
        
    } catch (Exception $e) {
        $debug_info['error'] = $e->getMessage();
    }
    
    return $debug_info;
}

/**
 * 测试添加历史记录
 */
function testAddHistory($pdo, $user_id = 1, $vod_id = 1) {
    $test_info = [];
    
    try {
        // 模拟添加历史记录的参数
        $params = [
            'vod_id' => $vod_id,
            'episode_index' => 1,
            'play_source' => 'test_source',
            'play_url' => 'test_url',
            'play_progress' => 100
        ];
        
        $test_info['test_params'] = $params;
        
        // 检查视频是否存在
        $check_vod_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "vod WHERE vod_id = :vod_id";
        $stmt = $pdo->prepare($check_vod_sql);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->execute();
        $vod_exists = $stmt->fetchColumn() > 0;
        
        $test_info['vod_exists'] = $vod_exists;
        
        if (!$vod_exists) {
            $test_info['error'] = '测试视频不存在，请先创建测试数据';
            return $test_info;
        }
        
        // 检查是否已有历史记录
        $check_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "ovo_history WHERE user_id = :user_id AND vod_id = :vod_id";
        $stmt = $pdo->prepare($check_sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->execute();
        $exists = $stmt->fetchColumn() > 0;
        
        $test_info['history_exists'] = $exists;
        
        $now = date('Y-m-d H:i:s');
        
        if ($exists) {
            // 测试更新
            $update_sql = "UPDATE " . DB_PREFIX . "ovo_history 
                SET play_source = :play_source, play_url = :play_url, play_progress = :play_progress, episode_index = :episode_index, update_time = :update_time 
                WHERE user_id = :user_id AND vod_id = :vod_id";
            
            $stmt = $pdo->prepare($update_sql);
            $stmt->bindParam(':play_source', $params['play_source']);
            $stmt->bindParam(':play_url', $params['play_url']);
            $stmt->bindParam(':play_progress', $params['play_progress']);
            $stmt->bindParam(':episode_index', $params['episode_index']);
            $stmt->bindParam(':update_time', $now);
            $stmt->bindParam(':user_id', $user_id);
            $stmt->bindParam(':vod_id', $vod_id);
            $stmt->execute();
            
            $test_info['operation'] = 'update';
            $test_info['affected_rows'] = $stmt->rowCount();
        } else {
            // 测试插入
            $insert_sql = "INSERT INTO " . DB_PREFIX . "ovo_history 
                (user_id, vod_id, episode_index, play_source, play_url, play_progress, create_time, update_time) 
                VALUES 
                (:user_id, :vod_id, :episode_index, :play_source, :play_url, :play_progress, :create_time, :update_time)";
            
            $stmt = $pdo->prepare($insert_sql);
            $stmt->bindParam(':user_id', $user_id);
            $stmt->bindParam(':vod_id', $vod_id);
            $stmt->bindParam(':episode_index', $params['episode_index']);
            $stmt->bindParam(':play_source', $params['play_source']);
            $stmt->bindParam(':play_url', $params['play_url']);
            $stmt->bindParam(':play_progress', $params['play_progress']);
            $stmt->bindParam(':create_time', $now);
            $stmt->bindParam(':update_time', $now);
            $stmt->execute();
            
            $test_info['operation'] = 'insert';
            $test_info['insert_id'] = $pdo->lastInsertId();
        }
        
        $test_info['success'] = true;
        
    } catch (Exception $e) {
        $test_info['success'] = false;
        $test_info['error'] = $e->getMessage();
        $test_info['error_code'] = $e->getCode();
    }
    
    return $test_info;
}

// 主要调试逻辑
$action = $_GET['action'] ?? 'debug';

switch ($action) {
    case 'debug':
        $debug_info = debugHistoryTable($pdo);
        response_success($debug_info);
        break;
        
    case 'test_add':
        $user_id = $_GET['user_id'] ?? 1;
        $vod_id = $_GET['vod_id'] ?? 1;
        $test_info = testAddHistory($pdo, $user_id, $vod_id);
        response_success($test_info);
        break;
        
    case 'fix_table':
        try {
            // 尝试添加episode_index字段
            $sql = "ALTER TABLE " . DB_PREFIX . "ovo_history ADD COLUMN episode_index int(11) NOT NULL DEFAULT 0 COMMENT '集数索引' AFTER vod_id";
            $pdo->exec($sql);
            response_success(['msg' => 'episode_index字段添加成功']);
        } catch (Exception $e) {
            if (strpos($e->getMessage(), 'Duplicate column name') !== false) {
                response_success(['msg' => 'episode_index字段已存在']);
            } else {
                response_error(500, '添加字段失败: ' . $e->getMessage());
            }
        }
        break;
        
    default:
        response_error(400, '未知的调试操作');
}
?>
