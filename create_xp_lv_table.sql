-- 选择数据库
USE `dmw_0606666_xyz_`;

-- 创建经验等级表（匹配UserController.php中的字段名）
CREATE TABLE IF NOT EXISTS `xp_lv` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `lv` int(11) NOT NULL COMMENT '等级',
  `xp` int(11) NOT NULL COMMENT '达到该等级所需经验值',
  `level_name` varchar(50) NOT NULL DEFAULT '' COMMENT '等级名称',
  `level_icon` varchar(255) NOT NULL DEFAULT '' COMMENT '等级图标',
  `privileges` text COMMENT '等级特权',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `lv` (`lv`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='用户经验等级表';

-- 插入默认等级数据
INSERT IGNORE INTO `xp_lv` (`lv`, `xp`, `level_name`, `level_icon`, `privileges`) VALUES
(1, 0, '新手', '/assets/icon/lv/lv1.png', '{"daily_sign": true}'),
(2, 100, '初级用户', '/assets/icon/lv/lv2.png', '{"daily_sign": true, "comment": true}'),
(3, 300, '活跃用户', '/assets/icon/lv/lv3.png', '{"daily_sign": true, "comment": true, "upload": true}'),
(4, 600, '资深用户', '/assets/icon/lv/lv4.png', '{"daily_sign": true, "comment": true, "upload": true, "priority_support": true}'),
(5, 1000, '专家用户', '/assets/icon/lv/lv5.png', '{"daily_sign": true, "comment": true, "upload": true, "priority_support": true, "advanced_features": true}'),
(6, 1500, '超级用户', '/assets/icon/lv/lv6.png', '{"daily_sign": true, "comment": true, "upload": true, "priority_support": true, "advanced_features": true, "exclusive_content": true}'),
(7, 2100, '传奇用户', '/assets/icon/lv/lv7.png', '{"daily_sign": true, "comment": true, "upload": true, "priority_support": true, "advanced_features": true, "exclusive_content": true, "custom_avatar": true}'),
(8, 2800, '大师级', '/assets/icon/lv/lv8.png', '{"daily_sign": true, "comment": true, "upload": true, "priority_support": true, "advanced_features": true, "exclusive_content": true, "custom_avatar": true, "moderator": true}'),
(9, 3600, '宗师级', '/assets/icon/lv/lv9.png', '{"daily_sign": true, "comment": true, "upload": true, "priority_support": true, "advanced_features": true, "exclusive_content": true, "custom_avatar": true, "moderator": true, "special_badge": true}');
