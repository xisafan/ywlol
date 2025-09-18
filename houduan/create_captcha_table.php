<?php
/**
 * 创建验证码表的脚本
 * 运行此脚本来创建验证码表
 */

require_once __DIR__ . '/database.php';

try {
    // 创建验证码表
    $sql = "CREATE TABLE IF NOT EXISTS `" . DB_PREFIX . "captcha` (
      `id` int(11) NOT NULL AUTO_INCREMENT,
      `captcha_id` varchar(32) NOT NULL COMMENT '验证码唯一标识',
      `captcha_code` varchar(10) NOT NULL COMMENT '验证码内容',
      `create_time` int(11) NOT NULL COMMENT '创建时间',
      `expire_time` int(11) NOT NULL COMMENT '过期时间',
      PRIMARY KEY (`id`),
      UNIQUE KEY `captcha_id` (`captcha_id`),
      KEY `expire_time` (`expire_time`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='验证码表'";
    
    $pdo->exec($sql);
    
    echo "✅ 验证码表创建成功：" . DB_PREFIX . "captcha\n";
    
    // 检查表是否存在
    $check_sql = "SHOW TABLES LIKE '" . DB_PREFIX . "captcha'";
    $result = $pdo->query($check_sql);
    
    if ($result->rowCount() > 0) {
        echo "✅ 表验证通过，验证码功能可以正常使用\n";
        
        // 清理可能存在的过期数据
        $cleanup_sql = "DELETE FROM " . DB_PREFIX . "captcha WHERE expire_time < " . time();
        $deleted = $pdo->exec($cleanup_sql);
        echo "✅ 清理了 $deleted 条过期验证码记录\n";
        
    } else {
        echo "❌ 表创建失败，请检查数据库权限\n";
    }
    
} catch (Exception $e) {
    echo "❌ 错误: " . $e->getMessage() . "\n";
}
?>
