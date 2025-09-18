-- 创建验证码表
CREATE TABLE IF NOT EXISTS `mac_captcha` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `captcha_id` varchar(32) NOT NULL COMMENT '验证码唯一标识',
  `captcha_code` varchar(10) NOT NULL COMMENT '验证码内容',
  `create_time` int(11) NOT NULL COMMENT '创建时间',
  `expire_time` int(11) NOT NULL COMMENT '过期时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `captcha_id` (`captcha_id`),
  KEY `expire_time` (`expire_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='验证码表';

-- 清理过期记录的事件（可选）
-- SET GLOBAL event_scheduler = ON;
-- CREATE EVENT IF NOT EXISTS `clean_expired_captcha`
-- ON SCHEDULE EVERY 1 HOUR
-- DO DELETE FROM `mac_captcha` WHERE `expire_time` < UNIX_TIMESTAMP();
