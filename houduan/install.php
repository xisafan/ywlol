<?php
/**
 * OVO系统安装脚本
 * 
 * 该脚本用于安装OVO系统，创建管理员账户并生成安装锁定文件
 * 
 * @author Trae AI
 * @version 1.0
 * @date 2023-11-15
 */

// 设置错误报告
error_reporting(E_ALL);
ini_set('display_errors', 1);

// 检查是否已安装
$lock_file = __DIR__ . '/lock.log';
if (file_exists($lock_file)) {
    die('<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OVO系统安装</title>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&display=swap">
    <style>
        :root {
            --primary-color: #4285F4;
            --primary-hover: #3367d6;
            --error-color: #DB4437;
            --light-bg: #f8f9fa;
            --dark-text: #202124;
            --light-text: #5f6368;
            --border-color: #dadce0;
        }
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        body {
            font-family: "Roboto", Arial, sans-serif;
            line-height: 1.6;
            color: var(--dark-text);
            background: var(--light-bg);
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            width: 100%;
            max-width: 800px;
            background: #fff;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.08);
            overflow: hidden;
        }
        .header {
            background: var(--primary-color);
            color: white;
            padding: 25px 30px;
        }
        .header h1 {
            font-weight: 500;
            font-size: 24px;
            margin: 0;
        }
        .content {
            padding: 30px;
        }
        .error {
            color: var(--error-color);
            background-color: rgba(219, 68, 55, 0.1);
            border-left: 4px solid var(--error-color);
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
        }
        a.button {
            display: inline-block;
            background: var(--primary-color);
            color: white;
            padding: 12px 24px;
            text-decoration: none;
            border-radius: 4px;
            font-weight: 500;
            margin-top: 20px;
        }
        a.button:hover {
            background: var(--primary-hover);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>OVO系统安装</h1>
        </div>
        <div class="content">
            <div class="error">系统已安装，如需重新安装，请删除lock.log文件</div>
            <a href="./" class="button">返回首页</a>
        </div>
    </div>
</body>
</html>');
}

// 处理表单提交
$admin_username = 'admin'; // 默认用户名
$admin_password = 'admin888'; // 默认密码

// 初始化错误信息变量
$error_message = '';

// 初始化安装信息输出缓冲区
$install_output = '';

// 如果是POST请求，获取用户提交的管理员信息
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // 验证并获取用户名
    if (isset($_POST['admin_username']) && !empty($_POST['admin_username'])) {
        $admin_username = trim($_POST['admin_username']);
        // 验证用户名格式（只允许字母、数字和下划线，长度3-20）
        if (!preg_match('/^\w{3,20}$/', $admin_username)) {
            $error_message = "用户名格式不正确，只允许字母、数字和下划线，长度3-20";
            $is_initial_load = true; // 返回表单页面
        }
    }
    
    // 如果没有错误，继续验证密码
    if (empty($error_message)) {
        // 验证并获取密码
        if (isset($_POST['admin_password']) && !empty($_POST['admin_password'])) {
            $admin_password = trim($_POST['admin_password']);
            // 验证密码长度（至少6位）
            if (strlen($admin_password) < 6) {
                $error_message = "密码长度不能少于6位";
                $is_initial_load = true; // 返回表单页面
            }
        }
    }
    
    // 如果没有错误，继续验证确认密码
    if (empty($error_message)) {
        // 确认密码验证
        if (isset($_POST['confirm_password']) && $_POST['confirm_password'] !== $admin_password) {
            $error_message = "两次输入的密码不一致";
            $is_initial_load = true; // 返回表单页面
        }
    }

    // 只有全部校验通过才插入管理员账号
    if (empty($error_message)) {
        $admin_password_md5 = md5($admin_password); // 密码加密存储
    }
}

// 读取数据库配置
$db_config_file = __DIR__ . '/database.php';
if (!file_exists($db_config_file)) {
    die('<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OVO系统安装</title>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&display=swap">
    <style>
        :root {
            --primary-color: #4285F4;
            --primary-hover: #3367d6;
            --error-color: #DB4437;
            --light-bg: #f8f9fa;
            --dark-text: #202124;
            --light-text: #5f6368;
            --border-color: #dadce0;
        }
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        body {
            font-family: "Roboto", Arial, sans-serif;
            line-height: 1.6;
            color: var(--dark-text);
            background: var(--light-bg);
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            width: 100%;
            max-width: 800px;
            background: #fff;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.08);
            overflow: hidden;
        }
        .header {
            background: var(--primary-color);
            color: white;
            padding: 25px 30px;
        }
        .header h1 {
            font-weight: 500;
            font-size: 24px;
            margin: 0;
        }
        .content {
            padding: 30px;
        }
        .error {
            color: var(--error-color);
            background-color: rgba(219, 68, 55, 0.1);
            border-left: 4px solid var(--error-color);
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
        }
        a.button {
            display: inline-block;
            background: var(--primary-color);
            color: white;
            padding: 12px 24px;
            text-decoration: none;
            border-radius: 4px;
            font-weight: 500;
            margin-top: 20px;
        }
        a.button:hover {
            background: var(--primary-hover);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>OVO系统安装</h1>
        </div>
        <div class="content">
            <div class="error">数据库配置文件不存在</div>
            <a href="./" class="button">返回首页</a>
        </div>
    </div>
</body>
</html>');
}

$db_config = include($db_config_file);

// 连接数据库
try {
    $dsn = "mysql:host={$db_config['hostname']};port={$db_config['hostport']};dbname={$db_config['database']};charset={$db_config['charset']}";
    $pdo = new PDO($dsn, $db_config['username'], $db_config['password']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // 设置表前缀
    $table_prefix = $db_config['prefix'];
    
    // 检查数据库连接
    $install_output .= "<p class='success'>数据库连接成功</p>";
    
    // 创建管理员表
    $admin_table = $table_prefix . 'ovo_admin';
    $create_table_sql = "CREATE TABLE IF NOT EXISTS `{$admin_table}` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `username` varchar(50) NOT NULL COMMENT '用户名',
        `password` varchar(32) NOT NULL COMMENT '密码',
        `last_login_time` datetime DEFAULT NULL COMMENT '最后登录时间',
        `last_login_ip` varchar(50) DEFAULT NULL COMMENT '最后登录IP',
        `create_time` datetime NOT NULL COMMENT '创建时间',
        `update_time` datetime DEFAULT NULL COMMENT '更新时间',
        `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态 0:禁用 1:正常',
        PRIMARY KEY (`id`),
        UNIQUE KEY `username` (`username`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='管理员表';";
    
    $pdo->exec($create_table_sql);
    $install_output .= "<p class='success'>管理员表创建成功</p>";

    // 创建基础设置表
    $setting_table = $table_prefix . 'ovo_setting';
    $create_setting_sql = "CREATE TABLE IF NOT EXISTS `{$setting_table}` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `app_name` varchar(100) NOT NULL COMMENT '软件名称',
        `android_version` varchar(20) DEFAULT NULL COMMENT 'Android版本号',
        `ios_version` varchar(20) DEFAULT NULL COMMENT 'iOS版本号',
        `windows_version` varchar(20) DEFAULT NULL COMMENT 'Windows版本号',
        `linux_version` varchar(20) DEFAULT NULL COMMENT 'Linux版本号',
        `encrypt_key` varchar(32) DEFAULT NULL COMMENT '加密密钥',
        `create_time` datetime NOT NULL COMMENT '创建时间',
        `update_time` datetime DEFAULT NULL COMMENT '更新时间',
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='基础设置表';";

    $pdo->exec($create_setting_sql);
    $install_output .= "<p class='success'>基础设置表创建成功</p>";

    // 创建解析设置表
    $parser_table = $table_prefix . 'ovo_parser';
    $create_parser_sql = "CREATE TABLE IF NOT EXISTS `{$parser_table}` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `name` varchar(100) NOT NULL COMMENT '解析名称',
        `resolution` varchar(20) DEFAULT NULL COMMENT '解析度',
        `player_type` varchar(50) DEFAULT NULL COMMENT '播放器类型',
        `encoding` varchar(20) DEFAULT NULL COMMENT '编码方式',
        `parse_method` varchar(50) NOT NULL COMMENT '解析方法',
        `parse_url` text NOT NULL COMMENT '解析链接',
        `remark` text DEFAULT NULL COMMENT '备注信息',
        `sort` int(11) DEFAULT 0 COMMENT '排序',
        `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态 0:禁用 1:正常',
        `create_time` datetime NOT NULL COMMENT '创建时间',
        `update_time` datetime DEFAULT NULL COMMENT '更新时间',
        PRIMARY KEY (`id`),
        KEY `idx_sort` (`sort`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='解析设置表';";

    $pdo->exec($create_parser_sql);
    $install_output .= "<p class='success'>解析设置表创建成功</p>";

    // 创建公告表
    $announcement_table = $table_prefix . 'ovo_announcement';
    $create_announcement_sql = "CREATE TABLE IF NOT EXISTS `{$announcement_table}` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `title` varchar(200) NOT NULL COMMENT '公告标题',
        `content` text NOT NULL COMMENT '公告内容',
        `is_force` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否强制提醒 0:否 1:是',
        `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态 0:禁用 1:正常',
        `create_time` datetime NOT NULL COMMENT '创建时间',
        `update_time` datetime DEFAULT NULL COMMENT '更新时间',
        PRIMARY KEY (`id`),
        KEY `idx_create_time` (`create_time`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='公告表';";

    $pdo->exec($create_announcement_sql);
    $install_output .= "<p class='success'>公告表创建成功</p>";

    // 创建用户表 (API用)
    $user_table = $table_prefix . 'ovo_user';
    $create_user_sql = "CREATE TABLE IF NOT EXISTS `{$user_table}` (
        `user_id` int(11) NOT NULL AUTO_INCREMENT,
        `username` varchar(50) NOT NULL COMMENT '用户名',
        `password` varchar(32) NOT NULL COMMENT '密码',
        `nickname` varchar(50) DEFAULT NULL COMMENT '昵称',
        `avatar` varchar(255) DEFAULT NULL COMMENT '头像',
        `email` varchar(100) DEFAULT NULL COMMENT '邮箱',
        `phone` varchar(20) DEFAULT NULL COMMENT '手机号',
        `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态 0:禁用 1:正常',
        `last_login_time` datetime DEFAULT NULL COMMENT '最后登录时间',
        `last_login_ip` varchar(50) DEFAULT NULL COMMENT '最后登录IP',
        `create_time` datetime NOT NULL COMMENT '创建时间',
        `update_time` datetime DEFAULT NULL COMMENT '更新时间',
        PRIMARY KEY (`user_id`),
        UNIQUE KEY `username` (`username`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='用户表';";

    $pdo->exec($create_user_sql);
    $install_output .= "<p class='success'>用户表创建成功</p>";

    // 创建收藏表 (API用)
    $favorite_table = $table_prefix . 'ovo_favorite';
    $create_favorite_sql = "CREATE TABLE IF NOT EXISTS `{$favorite_table}` (
        `favorite_id` int(11) NOT NULL AUTO_INCREMENT,
        `user_id` int(11) NOT NULL COMMENT '用户ID',
        `vod_id` int(11) NOT NULL COMMENT '视频ID',
        `create_time` datetime NOT NULL COMMENT '创建时间',
        PRIMARY KEY (`favorite_id`),
        UNIQUE KEY `user_vod` (`user_id`,`vod_id`),
        KEY `user_id` (`user_id`),
        KEY `vod_id` (`vod_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='收藏表';";

    $pdo->exec($create_favorite_sql);
    $install_output .= "<p class='success'>收藏表创建成功</p>";

    // 创建播放历史表 (API用)
    $history_table = $table_prefix . 'ovo_history';
    $create_history_sql = "CREATE TABLE IF NOT EXISTS `{$history_table}` (
        `history_id` int(11) NOT NULL AUTO_INCREMENT,
        `user_id` int(11) NOT NULL COMMENT '用户ID',
        `vod_id` int(11) NOT NULL COMMENT '视频ID',
        `play_source` varchar(100) DEFAULT NULL COMMENT '播放源',
        `play_url` varchar(500) DEFAULT NULL COMMENT '播放地址',
        `play_progress` int(11) DEFAULT '0' COMMENT '播放进度(秒)',
        `create_time` datetime NOT NULL COMMENT '创建时间',
        `update_time` datetime DEFAULT NULL COMMENT '更新时间',
        PRIMARY KEY (`history_id`),
        UNIQUE KEY `user_vod` (`user_id`,`vod_id`),
        KEY `user_id` (`user_id`),
        KEY `vod_id` (`vod_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='播放历史表';";

    $pdo->exec($create_history_sql);
    $install_output .= "<p class='success'>播放历史表创建成功</p>";

    // 创建用户令牌表 (API用)
    $token_table = $table_prefix . 'ovo_user_token';
    $create_token_sql = "CREATE TABLE IF NOT EXISTS `{$token_table}` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `user_id` int(11) NOT NULL COMMENT '用户ID',
        `refresh_token` varchar(255) NOT NULL COMMENT '刷新令牌',
        `device_id` varchar(100) DEFAULT NULL COMMENT '设备ID',
        `expire_time` datetime NOT NULL COMMENT '过期时间',
        `create_time` datetime NOT NULL COMMENT '创建时间',
        `update_time` datetime DEFAULT NULL COMMENT '更新时间',
        PRIMARY KEY (`id`),
        KEY `user_id` (`user_id`),
        KEY `refresh_token` (`refresh_token`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='用户令牌表';";

    $pdo->exec($create_token_sql);
    $install_output .= "<p class='success'>用户令牌表创建成功</p>";

    // 创建播放器表
    $player_table = $table_prefix . 'ovo_player';
    $create_player_sql = "CREATE TABLE IF NOT EXISTS `{$player_table}` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `player` varchar(50) NOT NULL COMMENT '播放器编码',
        `type` varchar(50) DEFAULT NULL COMMENT '播放方式',
        `lib` varchar(100) DEFAULT NULL COMMENT '客户端播放器',
        `url` varchar(100) DEFAULT NULL COMMENT 'json解析地址',
        `referer` varchar(100) DEFAULT NULL COMMENT 'referer',
        `name` varchar(100) DEFAULT NULL COMMENT '播放器名称',
        `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态 0:禁用 1:正常',
        `sort` int(11) DEFAULT 0 COMMENT '排序',
        `create_time` datetime NOT NULL COMMENT '创建时间',
        `update_time` datetime DEFAULT NULL COMMENT '更新时间',
        PRIMARY KEY (`id`),
        UNIQUE KEY `player` (`player`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='播放器表';";
    $pdo->exec($create_player_sql);
    $install_output .= "<p class='success'>播放器表创建成功</p>";

    // 插入默认播放器数据
    $now = date('Y-m-d H:i:s');
    $default_players = [
        ['ovo', 'in', 'exo', '', '', '直链'],
        ['wedm', 'json', 'media', 'https://lolicaricature.cfd/suanfa/dm.php?target=', '', 'json'],
        ['nya', 'in', 'exo', '', 'https://play.nyadm.org/', 'zl'],
    ];
    foreach ($default_players as $idx => $row) {
        $insert_player_sql = "INSERT INTO `{$player_table}` (`player`, `type`, `lib`, `url`, `referer`, `name`, `status`, `sort`, `create_time`) 
            VALUES (:player, :type, :lib, :url, :referer, :name, 1, :sort, :create_time)
            ON DUPLICATE KEY UPDATE `type`=VALUES(`type`), `lib`=VALUES(`lib`), `url`=VALUES(`url`), `name`=VALUES(`name`), `status`=1, `update_time`=:create_time";
        $stmt = $pdo->prepare($insert_player_sql);
        $stmt->bindParam(':player', $row[0]);
        $stmt->bindParam(':type', $row[1]);
        $stmt->bindParam(':lib', $row[2]);
        $stmt->bindParam(':url', $row[3]);
        $stmt->bindParam(':referer', $row[4]);
        $stmt->bindParam(':name', $row[5]);
        $stmt->bindValue(':sort', $idx);
        $stmt->bindParam(':create_time', $now);
        $stmt->execute();
    }
    $install_output .= "<p class='success'>默认播放器数据添加成功</p>";

    // 插入默认设置
    $now = date('Y-m-d H:i:s');
    $insert_setting_sql = "INSERT INTO `{$setting_table}` 
        (`app_name`, `android_version`, `ios_version`, `windows_version`, `linux_version`, `encrypt_key`, `create_time`) 
        VALUES 
        ('OVO Fun', '1.0.0', '1.0.0', '1.0.0', '1.0.0', '" . md5(uniqid()) . "', :create_time)";
    $stmt = $pdo->prepare($insert_setting_sql);
    $stmt->bindParam(':create_time', $now);
    $stmt->execute();
    $install_output .= "<p class='success'>默认设置数据添加成功</p>";
    
    // 检查管理员是否已存在
    $check_sql = "SELECT COUNT(*) FROM `{$admin_table}` WHERE `username` = :username";
    $stmt = $pdo->prepare($check_sql);
    $stmt->bindParam(':username', $admin_username);
    $stmt->execute();
    
    if ($stmt->fetchColumn() > 0) {
        $install_output .= "<p class='info'>管理员账户已存在，跳过创建</p>";
    } else if ($_SERVER['REQUEST_METHOD'] === 'POST' && empty($error_message)) {
        // 插入管理员账户（只有校验全部通过才插入）
        $now = date('Y-m-d H:i:s');
        $insert_sql = "INSERT INTO `{$admin_table}` (`username`, `password`, `create_time`, `status`) 
                      VALUES (:username, :password, :create_time, 1)";
        $stmt = $pdo->prepare($insert_sql);
        $stmt->bindParam(':username', $admin_username);
        $stmt->bindParam(':password', $admin_password_md5);
        $stmt->bindParam(':create_time', $now);
        $stmt->execute();
        
        $install_output .= "<p class='success'>管理员账户创建成功</p>";
        $install_output .= "<div class='credentials'>";
        $install_output .= "<p><strong>用户名:</strong> {$admin_username}</p>";
        $install_output .= "<p><strong>密码:</strong> {$admin_password}</p>";
        $install_output .= "</div>";
    }
    
    // 创建评分表 (API用)
    $score_table = $table_prefix . 'ovo_score';
    $create_score_sql = "CREATE TABLE IF NOT EXISTS `{$score_table}` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `vod_id` int(11) NOT NULL,
        `username` varchar(50) NOT NULL,
        `score` float NOT NULL,
        `comment` varchar(255) NOT NULL,
        `likes` int(11) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='评分表';";
    $pdo->exec($create_score_sql);
    $install_output .= "<p class='success'>评分表创建成功</p>";

    // 创建点赞表 (API用)
    $like_table = $table_prefix . 'ovo_like';
    $create_like_sql = "CREATE TABLE IF NOT EXISTS `{$like_table}` (
        `vod_id` INT NOT NULL,
        `user_id` INT NOT NULL,
        `zan` TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`vod_id`, `user_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='点赞表';";
    $pdo->exec($create_like_sql);
    $install_output .= "<p class='success'>点赞表创建成功</p>";

    // 创建弹幕表 (API用)
    $danmaku_table = $table_prefix . 'danmaku';
    $create_danmaku_sql = "CREATE TABLE IF NOT EXISTS `{$danmaku_table}` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `vod_id` INT UNSIGNED NOT NULL,
        `episode_index` INT UNSIGNED DEFAULT 0,
        `user_id` INT UNSIGNED NOT NULL,
        `content` VARCHAR(255) NOT NULL,
        `color` VARCHAR(16) NOT NULL DEFAULT '#ffffff',
        `position` ENUM('right','top','bottom') NOT NULL DEFAULT 'right',
        `time` FLOAT NOT NULL,
        `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='弹幕表';";
    $pdo->exec($create_danmaku_sql);
    $install_output .= "<p class='success'>弹幕表创建成功</p>";

    // 创建安装锁定文件
    $lock_content = "安装时间：" . date('Y-m-d H:i:s') . "\n";
    $lock_content .= "安装IP：" . $_SERVER['REMOTE_ADDR'] . "\n";
    
    if (file_put_contents($lock_file, $lock_content)) {
        $install_output .= "<p class='success'>安装锁定文件创建成功</p>";
        $install_output .= "<p class='success'>系统安装完成！</p>";
        $install_output .= "<p><a href='./'>点击进入首页</a></p>";
    } else {
        $install_output .= "<p class='error'>警告：安装锁定文件创建失败，请手动创建lock.log文件以防止重复安装</p>";
    }
    
} catch (PDOException $e) {
    $install_output .= "<p class='error'>数据库错误: " . $e->getMessage() . "</p>";
    $is_initial_load = false; // 确保显示错误信息而不是表单
} catch (Exception $e) {
    $install_output .= "<p class='error'>安装错误: " . $e->getMessage() . "</p>";
    $is_initial_load = false; // 确保显示错误信息而不是表单
}
// 检查是否是初始页面加载（非POST请求）
$is_initial_load = ($_SERVER['REQUEST_METHOD'] !== 'POST');

?><!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OVO系统安装</title>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&display=swap">
    <style>
        :root {
            --primary-color: #4285F4;
            --primary-hover: #3367d6;
            --success-color: #0F9D58;
            --error-color: #DB4437;
            --warning-color: #F4B400;
            --light-bg: #f8f9fa;
            --dark-text: #202124;
            --light-text: #5f6368;
            --border-color: #dadce0;
        }
        
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        
        body {
            font-family: 'Roboto', Arial, sans-serif;
            line-height: 1.6;
            color: var(--dark-text);
            background: var(--light-bg);
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            width: 100%;
            max-width: 800px;
            background: #fff;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.08);
            overflow: hidden;
        }
        
        .header {
            background: var(--primary-color);
            color: white;
            padding: 25px 30px;
            position: relative;
        }
        
        .header h1 {
            font-weight: 500;
            font-size: 24px;
            margin: 0;
            padding: 0;
        }
        
        .header p {
            margin-top: 5px;
            opacity: 0.9;
            font-weight: 300;
        }
        
        .content {
            padding: 30px;
        }
        
        .install-step {
            margin-bottom: 20px;
            padding-bottom: 20px;
            border-bottom: 1px solid var(--border-color);
        }
        
        .install-step:last-child {
            border-bottom: none;
            margin-bottom: 0;
            padding-bottom: 0;
        }
        
        h2 {
            font-size: 18px;
            font-weight: 500;
            margin-bottom: 15px;
            color: var(--dark-text);
        }
        
        p {
            margin: 12px 0;
            color: var(--light-text);
            font-size: 14px;
        }
        
        .success {
            color: var(--success-color);
            background-color: rgba(15, 157, 88, 0.1);
            border-left: 4px solid var(--success-color);
            padding: 12px 15px;
            border-radius: 4px;
            margin: 12px 0;
        }
        
        .error {
            color: var(--error-color);
            background-color: rgba(219, 68, 55, 0.1);
            border-left: 4px solid var(--error-color);
            padding: 12px 15px;
            border-radius: 4px;
            margin: 12px 0;
        }
        
        .info {
            color: var(--primary-color);
            background-color: rgba(66, 133, 244, 0.1);
            border-left: 4px solid var(--primary-color);
            padding: 12px 15px;
            border-radius: 4px;
            margin: 12px 0;
        }
        
        .warning {
            color: var(--warning-color);
            background-color: rgba(244, 180, 0, 0.1);
            border-left: 4px solid var(--warning-color);
            padding: 12px 15px;
            border-radius: 4px;
            margin: 12px 0;
        }
        
        .credentials {
            background-color: rgba(15, 157, 88, 0.05);
            border: 1px solid rgba(15, 157, 88, 0.2);
            border-radius: 4px;
            padding: 15px;
            margin: 15px 0;
        }
        
        .credentials p {
            margin: 8px 0;
            color: var(--dark-text);
        }
        
        form {
            margin-top: 20px;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
            color: var(--dark-text);
        }
        
        input[type="text"],
        input[type="password"] {
            width: 100%;
            padding: 12px;
            border: 1px solid var(--border-color);
            border-radius: 4px;
            font-size: 14px;
            transition: border-color 0.3s;
        }
        
        input[type="text"]:focus,
        input[type="password"]:focus {
            border-color: var(--primary-color);
            outline: none;
        }
        
        button {
            background-color: var(--primary-color);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 500;
            transition: background-color 0.3s;
        }
        
        button:hover {
            background-color: var(--primary-hover);
        }
        
        a {
            color: var(--primary-color);
            text-decoration: none;
        }
        
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>OVO系统安装</h1>
            <p>安装向导将帮助您完成系统安装</p>
        </div>
        <div class="content">
            <?php if ($is_initial_load): ?>
                <?php if (!empty($error_message)): ?>
                    <div class="error"><?php echo $error_message; ?></div>
                <?php endif; ?>
                
                <div class="install-step">
                    <h2>1. 环境检测</h2>
                    <p>系统将自动检测您的服务器环境是否满足安装要求</p>
                    
                    <?php
                    // PHP版本检测
                    $php_version = phpversion();
                    $php_version_ok = version_compare($php_version, '7.0.0', '>=');
                    echo '<p class="' . ($php_version_ok ? 'success' : 'error') . '">PHP版本: ' . $php_version . ($php_version_ok ? ' (满足要求)' : ' (不满足要求，需要PHP 7.0.0或更高版本)') . '</p>';
                    
                    // PDO扩展检测
                    $pdo_ok = extension_loaded('pdo_mysql');
                    echo '<p class="' . ($pdo_ok ? 'success' : 'error') . '">PDO扩展: ' . ($pdo_ok ? '已安装' : '未安装') . '</p>';
                    
                    // 目录权限检测
                    $dir_writable = is_writable(__DIR__);
                    echo '<p class="' . ($dir_writable ? 'success' : 'error') . '">目录权限: ' . ($dir_writable ? '可写' : '不可写') . '</p>';
                    ?>
                </div>
                
                <div class="install-step">
                    <h2>2. 管理员设置</h2>
                    <p>请设置管理员账户信息，用于登录系统</p>
                    
                    <form method="post" action="">
                        <div class="form-group">
                            <label for="admin_username">管理员用户名</label>
                            <input type="text" id="admin_username" name="admin_username" value="<?php echo htmlspecialchars($admin_username); ?>" required>
                        </div>
                        
                        <div class="form-group">
                            <label for="admin_password">管理员密码</label>
                            <input type="password" id="admin_password" name="admin_password" value="<?php echo htmlspecialchars($admin_password); ?>" required>
                        </div>
                        
                        <div class="form-group">
                            <label for="confirm_password">确认密码</label>
                            <input type="password" id="confirm_password" name="confirm_password" value="<?php echo htmlspecialchars($admin_password); ?>" required>
                        </div>
                        
                        <button type="submit">开始安装</button>
                    </form>
                </div>
            <?php else: ?>
                <div class="install-step">
                    <h2>安装结果</h2>
                    <?php echo $install_output; ?>
                </div>
            <?php endif; ?>
        </div>
    </div>
</body>
</html>