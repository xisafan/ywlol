-- 为 mac_ovo_setting 表添加轮播图推荐等级和热门数据等级字段
-- 执行此脚本前请先备份数据库

USE DATABASE_NAME; -- 请替换为您的数据库名

-- 添加轮播图推荐等级字段（默认值为9）
ALTER TABLE `mac_ovo_setting` 
ADD COLUMN `banner_level` int(11) NOT NULL DEFAULT 9 COMMENT '轮播图推荐等级(1-9)' AFTER `encrypt_key`;

-- 添加热门数据等级字段（默认值为6）
ALTER TABLE `mac_ovo_setting` 
ADD COLUMN `hot_level` int(11) NOT NULL DEFAULT 6 COMMENT '热门数据等级(1-9)' AFTER `banner_level`;

-- 为已存在的记录设置默认值
UPDATE `mac_ovo_setting` SET 
    `banner_level` = 9,
    `hot_level` = 6 
WHERE `banner_level` IS NULL OR `hot_level` IS NULL;

-- 验证更新结果
SELECT * FROM `mac_ovo_setting`;