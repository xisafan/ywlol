-- 修复历史记录数据库表结构问题
-- 执行此脚本前请先备份数据库
-- 
-- 问题描述：
-- 1. mac_ovo_history 表缺少 episode_index 字段
-- 2. 导致添加历史记录时SQL错误
-- 3. 客户端显示"服务器那边什么都没有"
--
-- 解决方案：
-- 1. 为 mac_ovo_history 表添加 episode_index 字段
-- 2. 修复表结构以支持完整的历史记录功能

-- 检查表结构
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'mac_ovo_history' 
ORDER BY ORDINAL_POSITION;

-- 为 mac_ovo_history 表添加 episode_index 字段
ALTER TABLE `mac_ovo_history` 
ADD COLUMN `episode_index` int(11) NOT NULL DEFAULT 0 COMMENT '集数索引' AFTER `vod_id`;

-- 创建复合索引以提高查询性能
ALTER TABLE `mac_ovo_history` 
DROP INDEX IF EXISTS `user_vod`;

ALTER TABLE `mac_ovo_history` 
ADD UNIQUE KEY `user_vod_episode` (`user_id`, `vod_id`);

-- 检查修复后的表结构
DESCRIBE `mac_ovo_history`;

-- 验证表是否可以正常插入数据（测试用，实际运行时可以注释掉）
-- INSERT INTO `mac_ovo_history` 
-- (`user_id`, `vod_id`, `episode_index`, `play_source`, `play_url`, `play_progress`, `create_time`, `update_time`) 
-- VALUES 
-- (1, 1, 1, 'test_source', 'test_url', 100, NOW(), NOW());

-- 查看表中的数据
SELECT COUNT(*) as total_records FROM `mac_ovo_history`;

-- 显示最近的几条记录（如果有的话）
SELECT * FROM `mac_ovo_history` ORDER BY `update_time` DESC LIMIT 5;

-- 检查用户token表状态
SELECT COUNT(*) as token_count FROM `mac_ovo_user_token`;
SELECT COUNT(*) as active_tokens FROM `mac_ovo_user_token` WHERE expire_time > NOW();

-- 显示过期的token（需要清理）
SELECT user_id, expire_time, TIMESTAMPDIFF(HOUR, expire_time, NOW()) as hours_expired 
FROM `mac_ovo_user_token` 
WHERE expire_time < NOW();

COMMIT;
