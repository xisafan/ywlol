<?php
/**
 * 测试验证码数据库功能
 */

require_once __DIR__ . '/api.php';

echo "=== 验证码数据库测试 ===\n\n";

try {
    // 1. 检查数据库连接
    echo "1. 检查数据库连接...\n";
    if (!$pdo) {
        throw new Exception("数据库连接失败");
    }
    echo "✅ 数据库连接正常\n\n";
    
    // 2. 检查验证码表是否存在
    echo "2. 检查验证码表...\n";
    $table_check = "SHOW TABLES LIKE '" . DB_PREFIX . "captcha'";
    $result = $pdo->query($table_check);
    
    if ($result->rowCount() == 0) {
        echo "❌ 验证码表不存在，正在创建...\n";
        
        // 创建表
        $create_sql = "CREATE TABLE IF NOT EXISTS `" . DB_PREFIX . "captcha` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `captcha_id` varchar(32) NOT NULL COMMENT '验证码唯一标识',
          `captcha_code` varchar(10) NOT NULL COMMENT '验证码内容',
          `create_time` int(11) NOT NULL COMMENT '创建时间',
          `expire_time` int(11) NOT NULL COMMENT '过期时间',
          PRIMARY KEY (`id`),
          UNIQUE KEY `captcha_id` (`captcha_id`),
          KEY `expire_time` (`expire_time`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='验证码表'";
        
        $pdo->exec($create_sql);
        echo "✅ 验证码表创建成功\n";
    } else {
        echo "✅ 验证码表已存在\n";
    }
    
    // 3. 测试验证码存储
    echo "\n3. 测试验证码存储...\n";
    $test_id = md5(uniqid() . time());
    $test_code = 'TEST';
    $current_time = time();
    $expire_time = $current_time + 600;
    
    $insert_sql = "INSERT INTO " . DB_PREFIX . "captcha (captcha_id, captcha_code, create_time, expire_time) VALUES (?, ?, ?, ?)";
    $stmt = $pdo->prepare($insert_sql);
    $result = $stmt->execute([$test_id, strtolower($test_code), $current_time, $expire_time]);
    
    if ($result) {
        echo "✅ 验证码存储成功\n";
        echo "   测试ID: $test_id\n";
        echo "   测试代码: " . strtolower($test_code) . "\n";
    } else {
        throw new Exception("验证码存储失败");
    }
    
    // 4. 测试验证码查询
    echo "\n4. 测试验证码查询...\n";
    $select_sql = "SELECT * FROM " . DB_PREFIX . "captcha WHERE captcha_id = ?";
    $stmt = $pdo->prepare($select_sql);
    $stmt->execute([$test_id]);
    $captcha_record = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($captcha_record) {
        echo "✅ 验证码查询成功\n";
        echo "   查询到的代码: {$captcha_record['captcha_code']}\n";
        echo "   过期时间: " . date('Y-m-d H:i:s', $captcha_record['expire_time']) . "\n";
        
        // 测试验证逻辑
        if (strtolower($test_code) === $captcha_record['captcha_code']) {
            echo "✅ 验证码匹配测试通过\n";
        } else {
            echo "❌ 验证码匹配测试失败\n";
        }
    } else {
        throw new Exception("验证码查询失败");
    }
    
    // 5. 清理测试数据
    echo "\n5. 清理测试数据...\n";
    $delete_sql = "DELETE FROM " . DB_PREFIX . "captcha WHERE captcha_id = ?";
    $stmt = $pdo->prepare($delete_sql);
    $stmt->execute([$test_id]);
    echo "✅ 测试数据清理完成\n";
    
    // 6. 显示当前验证码表内容
    echo "\n6. 当前验证码表内容...\n";
    $list_sql = "SELECT captcha_id, captcha_code, FROM_UNIXTIME(create_time) as create_time, FROM_UNIXTIME(expire_time) as expire_time FROM " . DB_PREFIX . "captcha ORDER BY create_time DESC LIMIT 10";
    $stmt = $pdo->query($list_sql);
    $records = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($records)) {
        echo "   表中暂无验证码记录\n";
    } else {
        echo "   最近的10条记录:\n";
        foreach ($records as $record) {
            $expired = time() > strtotime($record['expire_time']) ? '[已过期]' : '[有效]';
            echo "   - ID: {$record['captcha_id']}, 代码: {$record['captcha_code']}, 创建: {$record['create_time']}, 过期: {$record['expire_time']} $expired\n";
        }
    }
    
    echo "\n✅ 所有测试完成！验证码数据库功能正常\n";
    
} catch (Exception $e) {
    echo "❌ 测试失败: " . $e->getMessage() . "\n";
    echo "错误详情: " . $e->getTraceAsString() . "\n";
}
?>
