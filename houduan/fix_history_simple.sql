-- 简化版历史记录数据库表结构修复脚本
-- 此脚本只包含必要的修复操作，不需要特殊权限
--
-- 使用方法：
-- 1. 在 phpMyAdmin 或其他数据库管理工具中执行
-- 2. 如果字段已存在会报错，但不影响功能

-- 1. 为 mac_ovo_history 表添加 episode_index 字段
ALTER TABLE `mac_ovo_history` 
ADD COLUMN `episode_index` int(11) NOT NULL DEFAULT 0 COMMENT '集数索引' AFTER `vod_id`;

-- 2. 重新创建唯一索引（如果报错说索引已存在，可以忽略）
ALTER TABLE `mac_ovo_history` 
DROP INDEX `user_vod`;

ALTER TABLE `mac_ovo_history` 
ADD UNIQUE KEY `user_vod_episode` (`user_id`, `vod_id`);

-- 完成修复
