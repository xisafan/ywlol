<?php
// +----------------------------------------------------------------------
// | OVO Fun 管理系统
// +----------------------------------------------------------------------
// | 设置管理页面
// +----------------------------------------------------------------------

// 启动会话
session_start();

// 检查用户是否已登录
if (!isset($_SESSION['admin_id']) || $_SESSION['admin_id'] <= 0) {
    header('Location: login.php');
    exit;
}

// 引入数据库配置
$db_config_file = __DIR__ . '/database.php';
if (!file_exists($db_config_file)) {
    die('数据库配置文件不存在');
}

// 加载数据库配置
$db_config = include($db_config_file);

// 初始化消息变量
$success_message = '';
$error_message = '';

try {
    // 连接数据库
    $dsn = "mysql:host={$db_config['hostname']};port={$db_config['hostport']};dbname={$db_config['database']};charset={$db_config['charset']}";
    $pdo = new PDO($dsn, $db_config['username'], $db_config['password']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // 设置表前缀
    $table_prefix = $db_config['prefix'];
    
    // 处理表单提交
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $action = isset($_POST['action']) ? $_POST['action'] : '';
        
        switch ($action) {
            case 'update_basic':
                // 更新基础设置
                $setting_table = 'mac_ovo_setting';
                $update_sql = "UPDATE `{$setting_table}` SET 
                    `app_name` = :app_name,
                    `android_version` = :android_version,
                    `ios_version` = :ios_version,
                    `windows_version` = :windows_version,
                    `linux_version` = :linux_version,
                    `encrypt_key` = :encrypt_key,
                    `banner_level` = :banner_level,
                    `hot_level` = :hot_level,
                    `update_time` = :update_time
                    WHERE `id` = :id";
                
                $stmt = $pdo->prepare($update_sql);
                $stmt->execute([
                    ':app_name' => $_POST['app_name'],
                    ':android_version' => $_POST['android_version'],
                    ':ios_version' => $_POST['ios_version'],
                    ':windows_version' => $_POST['windows_version'],
                    ':linux_version' => $_POST['linux_version'],
                    ':encrypt_key' => $_POST['encrypt_key'],
                    ':banner_level' => intval($_POST['banner_level']),
                    ':hot_level' => intval($_POST['hot_level']),
                    ':update_time' => date('Y-m-d H:i:s'),
                    ':id' => $_POST['id']
                ]);
                
                $success_message = '基础设置更新成功';
                break;
                
            case 'add_parser':
                // 添加播放器设置（直接操作player表）
                $player_table = 'mac_ovo_player';
                
                // 生成播放器编码，使用解析名称的拼音或简写
                $player_code = $_POST['player_type'] ?: strtolower($_POST['parser_name']);
                $player_code = preg_replace('/[^a-z0-9]/', '', $player_code); // 只保留字母数字
                
                // 映射解析方法到播放器类型
                $type_mapping = [
                    '解析' => 'json',
                    '直链' => 'in', 
                    'iframe' => 'iframe',
                    'json' => 'json'
                ];
                $player_type = $type_mapping[$_POST['parse_method']] ?? 'json';
                
                // 映射编码到客户端播放器
                $lib_mapping = [
                    'json' => 'media',
                    'm3u8' => 'exo',
                    'mp4' => 'exo'
                ];
                $player_lib = $lib_mapping[$_POST['encoding']] ?? 'exo';
                
                $insert_sql = "INSERT INTO `{$player_table}` 
                    (`player`, `type`, `lib`, `url`, `referer`, `name`, `sort`, `status`, `create_time`) 
                    VALUES 
                    (:player, :type, :lib, :url, :referer, :name, :sort, :status, :create_time)";
                
                $stmt = $pdo->prepare($insert_sql);
                $stmt->execute([
                    ':player' => $player_code,  // 播放器编码
                    ':type' => $player_type,    // 播放方式 (json/in/iframe)
                    ':lib' => $player_lib,      // 客户端播放器 (exo/media)
                    ':url' => $_POST['parse_url'], // json解析地址
                    ':referer' => '',           // referer（可后续扩展）
                    ':name' => $_POST['parser_name'], // 播放器名称
                    ':sort' => intval($_POST['sort']),
                    ':status' => 1,
                    ':create_time' => date('Y-m-d H:i:s')
                ]);
                
                // 同时保存到parser表作为备份记录
                $parser_table = 'mac_ovo_parser';
                $backup_sql = "INSERT INTO `{$parser_table}` 
                    (`name`, `resolution`, `player_type`, `encoding`, `parse_method`, `parse_url`, `remark`, `sort`, `status`, `create_time`) 
                    VALUES 
                    (:name, :resolution, :player_type, :encoding, :parse_method, :parse_url, :remark, :sort, :status, :create_time)";
                
                $backup_stmt = $pdo->prepare($backup_sql);
                $backup_stmt->execute([
                    ':name' => $_POST['parser_name'],
                    ':resolution' => $_POST['resolution'],
                    ':player_type' => $player_code, // 保存生成的播放器编码
                    ':encoding' => $_POST['encoding'],
                    ':parse_method' => $_POST['parse_method'],
                    ':parse_url' => $_POST['parse_url'],
                    ':remark' => "自动同步到播放器表，编码: {$player_code}",
                    ':sort' => intval($_POST['sort']),
                    ':status' => 1,
                    ':create_time' => date('Y-m-d H:i:s')
                ]);
                
                $success_message = "播放器添加成功，编码: {$player_code}";
                break;
                
            case 'update_parser':
                // 更新播放器设置（主要更新player表）
                $player_table = 'mac_ovo_player';
                
                // 获取当前播放器记录以获取player编码
                $query_sql = "SELECT `player` FROM `{$player_table}` WHERE `id` = :id";
                $query_stmt = $pdo->prepare($query_sql);
                $query_stmt->execute([':id' => $_POST['parser_id']]);
                $current_player = $query_stmt->fetch(PDO::FETCH_ASSOC);
                
                if (!$current_player) {
                    $error_message = '播放器记录不存在';
                    break;
                }
                
                // 映射解析方法到播放器类型
                $type_mapping = [
                    '解析' => 'json',
                    '直链' => 'in', 
                    'iframe' => 'iframe',
                    'json' => 'json'
                ];
                $player_type = $type_mapping[$_POST['parse_method']] ?? 'json';
                
                // 映射编码到客户端播放器
                $lib_mapping = [
                    'json' => 'media',
                    'm3u8' => 'exo',
                    'mp4' => 'exo'
                ];
                $player_lib = $lib_mapping[$_POST['encoding']] ?? 'exo';
                
                $update_sql = "UPDATE `{$player_table}` SET 
                    `type` = :type,
                    `lib` = :lib,
                    `url` = :url,
                    `name` = :name,
                    `sort` = :sort,
                    `status` = :status,
                    `update_time` = :update_time
                    WHERE `id` = :id";
                
                $stmt = $pdo->prepare($update_sql);
                $stmt->execute([
                    ':type' => $player_type,
                    ':lib' => $player_lib,
                    ':url' => $_POST['parse_url'],
                    ':name' => $_POST['parser_name'],
                    ':sort' => intval($_POST['sort']),
                    ':status' => isset($_POST['status']) ? 1 : 0,
                    ':update_time' => date('Y-m-d H:i:s'),
                    ':id' => $_POST['parser_id']
                ]);
                
                // 同时更新parser表的记录
                $parser_table = 'mac_ovo_parser';
                $parser_update_sql = "UPDATE `{$parser_table}` SET 
                    `name` = :name,
                    `resolution` = :resolution,
                    `player_type` = :player_type,
                    `encoding` = :encoding,
                    `parse_method` = :parse_method,
                    `parse_url` = :parse_url,
                    `remark` = :remark,
                    `sort` = :sort,
                    `status` = :status,
                    `update_time` = :update_time
                    WHERE `player_type` = :player_code";
                
                $parser_stmt = $pdo->prepare($parser_update_sql);
                $parser_stmt->execute([
                    ':name' => $_POST['parser_name'],
                    ':resolution' => $_POST['resolution'],
                    ':player_type' => $current_player['player'],
                    ':encoding' => $_POST['encoding'],
                    ':parse_method' => $_POST['parse_method'],
                    ':parse_url' => $_POST['parse_url'],
                    ':remark' => "同步更新，播放器编码: {$current_player['player']}",
                    ':sort' => intval($_POST['sort']),
                    ':status' => isset($_POST['status']) ? 1 : 0,
                    ':update_time' => date('Y-m-d H:i:s'),
                    ':player_code' => $current_player['player']
                ]);
                
                $success_message = '播放器设置更新成功';
                break;
                
            case 'delete_parser':
                // 删除播放器设置（同时删除两个表的记录）
                if (isset($_POST['parser_id'])) {
                    // 先获取播放器编码
                    $player_table = 'mac_ovo_player';
                    $query_sql = "SELECT `player` FROM `{$player_table}` WHERE `id` = :id";
                    $query_stmt = $pdo->prepare($query_sql);
                    $query_stmt->execute([':id' => $_POST['parser_id']]);
                    $player_record = $query_stmt->fetch(PDO::FETCH_ASSOC);
                    
                    // 删除player表记录
                    $delete_player_sql = "DELETE FROM `{$player_table}` WHERE `id` = :id";
                    $player_stmt = $pdo->prepare($delete_player_sql);
                    $player_stmt->execute([':id' => $_POST['parser_id']]);
                    
                    // 删除parser表对应记录
                    if ($player_record) {
                        $parser_table = 'mac_ovo_parser';
                        $delete_parser_sql = "DELETE FROM `{$parser_table}` WHERE `player_type` = :player_code";
                        $parser_stmt = $pdo->prepare($delete_parser_sql);
                        $parser_stmt->execute([':player_code' => $player_record['player']]);
                    }
                    
                    $success_message = '播放器删除成功';
                }
                break;
                
            case 'add_announcement':
                // 添加公告
                $announcement_table = 'mac_ovo_announcement';
                $insert_sql = "INSERT INTO `{$announcement_table}` 
                    (`title`, `content`, `is_force`, `status`, `create_time`) 
                    VALUES 
                    (:title, :content, :is_force, :status, :create_time)";
                
                $stmt = $pdo->prepare($insert_sql);
                $stmt->execute([
                    ':title' => $_POST['title'],
                    ':content' => $_POST['content'],
                    ':is_force' => isset($_POST['is_force']) ? 1 : 0,
                    ':status' => 1,
                    ':create_time' => date('Y-m-d H:i:s')
                ]);
                
                $success_message = '公告添加成功';
                break;
                
            case 'update_announcement':
                // 更新公告
                $announcement_table = 'mac_ovo_announcement';
                $update_sql = "UPDATE `{$announcement_table}` SET 
                    `title` = :title,
                    `content` = :content,
                    `is_force` = :is_force,
                    `status` = :status,
                    `update_time` = :update_time
                    WHERE `id` = :id";
                
                $stmt = $pdo->prepare($update_sql);
                $stmt->execute([
                    ':title' => $_POST['title'],
                    ':content' => $_POST['content'],
                    ':is_force' => isset($_POST['is_force']) ? 1 : 0,
                    ':status' => isset($_POST['status']) ? 1 : 0,
                    ':update_time' => date('Y-m-d H:i:s'),
                    ':id' => $_POST['announcement_id']
                ]);
                
                $success_message = '公告更新成功';
                break;
                
            case 'delete_announcement':
                // 删除公告
                if (isset($_POST['announcement_id'])) {
                    $announcement_table = 'mac_ovo_announcement';
                    $delete_sql = "DELETE FROM `{$announcement_table}` WHERE `id` = :id";
                    $stmt = $pdo->prepare($delete_sql);
                    $stmt->execute([':id' => $_POST['announcement_id']]);
                    $success_message = '公告删除成功';
                }
                break;
        }
    }
    
    // 获取基础设置
    $setting_table = 'mac_ovo_setting';
    $stmt = $pdo->query("SELECT * FROM `{$setting_table}` LIMIT 1");
    $basic_setting = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // 获取播放器列表（从player表获取，用于前端显示）
    $player_table = 'mac_ovo_player';
    $stmt = $pdo->query("SELECT *, 
                           CASE 
                             WHEN `type` = 'json' THEN '解析'
                             WHEN `type` = 'in' THEN '直链'
                             WHEN `type` = 'iframe' THEN 'iframe'
                             ELSE `type`
                           END as `parse_method`,
                           CASE 
                             WHEN `lib` = 'media' THEN 'json'
                             WHEN `lib` = 'exo' THEN 'm3u8'
                             ELSE `lib`
                           END as `encoding`,
                           '1080P' as `resolution`,
                           `player` as `player_type`
                         FROM `{$player_table}` ORDER BY `sort` ASC, `id` DESC");
    $parsers = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // 补充字段映射，确保前端显示正常
    foreach ($parsers as &$parser) {
        $parser['parser_name'] = $parser['name'];
        $parser['parse_url'] = $parser['url'];
        $parser['remark'] = "播放器编码: {$parser['player']}, 类型: {$parser['type']}, 库: {$parser['lib']}";
    }
    
    // 获取公告列表
    $announcement_table = 'mac_ovo_announcement';
    $stmt = $pdo->query("SELECT * FROM `{$announcement_table}` ORDER BY `create_time` DESC");
    $announcements = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
} catch (PDOException $e) {
    $error_message = '数据库错误：' . $e->getMessage();
}
?>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OVO Fun - 系统设置</title>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        :root {
            --primary-blue: #2563eb;
            --light-blue: #dbeafe;
            --dark-blue: #1e40af;
            --sidebar-width: 280px;
            --header-height: 70px;
            --white: #ffffff;
            --gray-50: #f9fafb;
            --gray-100: #f3f4f6;
            --gray-200: #e5e7eb;
            --gray-300: #d1d5db;
            --gray-600: #4b5563;
            --gray-700: #374151;
            --gray-800: #1f2937;
            --gray-900: #111827;
            --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
            --shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1);
            --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1);
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background-color: var(--gray-50);
            color: var(--gray-800);
            line-height: 1.6;
        }

        /* 布局容器 */
        .admin-layout {
            display: flex;
            min-height: 100vh;
        }

        /* 侧边栏 */
        .sidebar {
            width: var(--sidebar-width);
            background: var(--white);
            border-right: 1px solid var(--gray-200);
            box-shadow: var(--shadow);
            position: fixed;
            height: 100vh;
            overflow-y: auto;
            z-index: 1000;
        }

        .sidebar-header {
            padding: 1.5rem;
            border-bottom: 1px solid var(--gray-200);
            background: linear-gradient(135deg, var(--primary-blue), var(--dark-blue));
        }

        .logo {
            display: flex;
            align-items: center;
            color: var(--white);
            font-size: 1.5rem;
            font-weight: 700;
            text-decoration: none;
        }

        .logo i {
            margin-right: 0.75rem;
            font-size: 1.75rem;
        }

        .sidebar-nav {
            padding: 1rem 0;
        }

        .nav-section {
            margin-bottom: 2rem;
        }

        .nav-section-title {
            padding: 0.5rem 1.5rem;
            font-size: 0.75rem;
            font-weight: 600;
            color: var(--gray-600);
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }

        .nav-item {
            display: block;
            padding: 0.75rem 1.5rem;
            color: var(--gray-700);
            text-decoration: none;
            transition: all 0.2s ease;
            border-left: 3px solid transparent;
        }

        .nav-item:hover {
            background-color: var(--light-blue);
            color: var(--primary-blue);
            border-left-color: var(--primary-blue);
        }

        .nav-item.active {
            background-color: var(--light-blue);
            color: var(--primary-blue);
            border-left-color: var(--primary-blue);
            font-weight: 600;
        }

        .nav-item i {
            margin-right: 0.75rem;
            width: 1.25rem;
            text-align: center;
        }

        /* 主内容区域 */
        .main-content {
            margin-left: var(--sidebar-width);
            flex: 1;
            display: flex;
            flex-direction: column;
        }

        /* 顶部导航 */
        .top-header {
            height: var(--header-height);
            background: var(--white);
            border-bottom: 1px solid var(--gray-200);
            box-shadow: var(--shadow-sm);
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 2rem;
            position: sticky;
            top: 0;
            z-index: 999;
        }

        .header-left {
            display: flex;
            align-items: center;
            gap: 1rem;
        }

        .header-title {
            font-size: 1.5rem;
            font-weight: 600;
            color: var(--gray-800);
        }

        /* 移动端菜单按钮 */
        .mobile-menu-btn {
            display: none;
            background: none;
            border: none;
            font-size: 1.25rem;
            color: var(--gray-600);
            cursor: pointer;
            padding: 0.5rem;
            border-radius: 0.375rem;
            transition: all 0.2s ease;
        }

        .mobile-menu-btn:hover {
            background: var(--gray-100);
            color: var(--primary-blue);
        }

        .mobile-menu-btn:active {
            transform: scale(0.95);
        }

        .header-actions {
            display: flex;
            align-items: center;
            gap: 1rem;
        }

        .user-menu {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            padding: 0.5rem 1rem;
            background: var(--gray-100);
            border-radius: 0.5rem;
            transition: background-color 0.2s ease;
        }

        .user-menu:hover {
            background: var(--gray-200);
        }

        .user-avatar {
            width: 2rem;
            height: 2rem;
            background: var(--primary-blue);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            color: var(--white);
            font-weight: 600;
        }

        .user-info {
            display: flex;
            flex-direction: column;
        }

        .user-name {
            font-size: 0.875rem;
            font-weight: 500;
            color: var(--gray-800);
        }

        .user-role {
            font-size: 0.75rem;
            color: var(--gray-600);
        }

        .logout-btn {
            color: var(--gray-600);
            text-decoration: none;
            font-size: 0.875rem;
            transition: color 0.2s ease;
        }

        .logout-btn:hover {
            color: var(--primary-blue);
        }

        /* 内容区域 */
        .content-area {
            flex: 1;
            padding: 2rem;
        }

        /* 卡片样式 */
        .card {
            background: var(--white);
            border-radius: 0.75rem;
            box-shadow: var(--shadow);
            overflow: hidden;
            margin-bottom: 1.5rem;
        }

        .card-header {
            padding: 1.5rem;
            border-bottom: 1px solid var(--gray-200);
            background: var(--gray-50);
        }

        .card-title {
            font-size: 1.25rem;
            font-weight: 600;
            color: var(--gray-900);
        }

        .card-body {
            padding: 1.5rem;
        }

        /* 表单样式 */
        .form-group {
            margin-bottom: 1.5rem;
        }

        .form-label {
            display: block;
            margin-bottom: 0.5rem;
            font-size: 0.875rem;
            font-weight: 500;
            color: var(--gray-700);
        }

        .form-control {
            width: 100%;
            padding: 0.75rem 1rem;
            border: 1px solid var(--gray-300);
            border-radius: 0.5rem;
            font-size: 0.875rem;
            transition: border-color 0.2s ease, box-shadow 0.2s ease;
        }

        .form-control:focus {
            outline: none;
            border-color: var(--primary-blue);
            box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
        }

        .form-control:disabled {
            background-color: var(--gray-100);
            color: var(--gray-600);
        }

        /* 按钮样式 */
        .btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            padding: 0.625rem 1.25rem;
            border: none;
            border-radius: 0.5rem;
            font-size: 0.875rem;
            font-weight: 500;
            text-decoration: none;
            cursor: pointer;
            transition: all 0.2s ease;
            gap: 0.5rem;
        }

        .btn-primary {
            background: var(--primary-blue);
            color: var(--white);
        }

        .btn-primary:hover {
            background: var(--dark-blue);
        }

        .btn-danger {
            background: #dc2626;
            color: var(--white);
        }

        .btn-danger:hover {
            background: #b91c1c;
        }

        .btn-secondary {
            background: var(--gray-100);
            color: var(--gray-700);
        }

        .btn-secondary:hover {
            background: var(--gray-200);
        }

        /* 标签页 */
        .nav-tabs {
            display: flex;
            list-style: none;
            border-bottom: 1px solid var(--gray-200);
            margin-bottom: 2rem;
            background: var(--white);
            border-radius: 0.75rem 0.75rem 0 0;
            overflow: hidden;
        }

        .nav-tabs li {
            flex: 1;
        }

        .nav-tabs a {
            display: block;
            padding: 1rem 1.5rem;
            text-decoration: none;
            color: var(--gray-600);
            text-align: center;
            transition: all 0.2s ease;
            border-bottom: 3px solid transparent;
            font-weight: 500;
        }

        .nav-tabs a:hover {
            background: var(--gray-50);
            color: var(--primary-blue);
        }

        .nav-tabs a.active {
            background: var(--light-blue);
            color: var(--primary-blue);
            border-bottom-color: var(--primary-blue);
        }

        .tab-content > div {
            display: none;
        }

        .tab-content > div.active {
            display: block;
        }

        /* 表格样式 */
        .table-container {
            overflow-x: auto;
            border-radius: 0.5rem;
            border: 1px solid var(--gray-200);
        }

        .table {
            width: 100%;
            border-collapse: collapse;
            margin: 0;
        }

        .table th,
        .table td {
            padding: 1rem;
            text-align: left;
            border-bottom: 1px solid var(--gray-200);
        }

        .table th {
            background: var(--gray-50);
            font-weight: 600;
            color: var(--gray-700);
            font-size: 0.875rem;
        }

        .table td {
            font-size: 0.875rem;
            color: var(--gray-600);
        }

        .table tbody tr:hover {
            background: var(--gray-50);
        }

        /* 消息样式 */
        .alert {
            padding: 1rem 1.5rem;
            border-radius: 0.5rem;
            margin-bottom: 1.5rem;
            border: 1px solid;
        }

        .alert-success {
            background: #f0fdf4;
            border-color: #bbf7d0;
            color: #166534;
        }

        .alert-error {
            background: #fef2f2;
            border-color: #fecaca;
            color: #dc2626;
        }

        /* 复选框样式 */
        .form-check {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            margin-bottom: 1rem;
        }

        .form-check-input {
            width: 1rem;
            height: 1rem;
        }

        .form-check-label {
            font-size: 0.875rem;
            color: var(--gray-700);
        }

        /* 响应式设计 */
        @media (max-width: 1024px) {
            .sidebar {
                transform: translateX(-100%);
                transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
                box-shadow: var(--shadow-xl);
            }

            .sidebar.mobile-open {
                transform: translateX(0);
            }

            .main-content {
                margin-left: 0;
            }

            .mobile-menu-btn {
                display: flex;
            }

            /* 添加移动端遮罩层 */
            .mobile-overlay {
                position: fixed;
                top: 0;
                left: 0;
                right: 0;
                bottom: 0;
                background: rgba(0, 0, 0, 0.5);
                backdrop-filter: blur(4px);
                z-index: 999;
                opacity: 0;
                visibility: hidden;
                transition: all 0.3s ease;
            }

            .mobile-overlay.active {
                opacity: 1;
                visibility: visible;
            }
        }

        @media (max-width: 768px) {
            .content-area {
                padding: 1rem;
            }

            .top-header {
                padding: 0 1rem;
            }

            .header-title {
                font-size: 1.25rem;
            }

            .nav-tabs {
                flex-direction: column;
                border-radius: 0.5rem;
            }

        .nav-tabs li {
                flex: none;
        }

        .nav-tabs a {
                padding: 0.75rem 1rem;
                border-bottom: 1px solid var(--gray-200);
                border-radius: 0;
            }

            .nav-tabs li:first-child a {
                border-radius: 0.5rem 0.5rem 0 0;
            }

            .nav-tabs li:last-child a {
                border-radius: 0 0 0.5rem 0.5rem;
            border-bottom: none;
            }

            .user-menu {
                padding: 0.25rem 0.75rem;
            }

            .user-info {
            display: none;
        }

            .logout-btn {
                font-size: 0.75rem;
                padding: 0.5rem;
            }

            .card {
                margin-bottom: 1rem;
            }

            .card-body {
                padding: 1rem;
            }

            .table-container {
                font-size: 0.875rem;
            }

            .table th,
            .table td {
                padding: 0.75rem 0.5rem;
            }
        }
    </style>
</head>
<body>
    <div class="admin-layout">
        <!-- 移动端遮罩层 -->
        <div class="mobile-overlay" id="mobileOverlay"></div>
        
        <!-- 侧边栏 -->
        <aside class="sidebar" id="sidebar">
            <div class="sidebar-header">
                <a href="index.php" class="logo">
                    <i class="fas fa-video"></i>
                    星星NB
                </a>
            </div>
            
            <nav class="sidebar-nav">
                <div class="nav-section">
                    <div class="nav-section-title">主要功能</div>
                    <a href="index.php" class="nav-item">
                        <i class="fas fa-home"></i>
                        控制台
                    </a>
                    <a href="setting.php" class="nav-item active">
                        <i class="fas fa-cog"></i>
                        系统设置
                    </a>
                    <a href="setting.php#parser" class="nav-item">
                        <i class="fas fa-play-circle"></i>
                        解析管理
                    </a>
                    <a href="setting.php#announcement" class="nav-item">
                        <i class="fas fa-bullhorn"></i>
                        公告管理
                    </a>
                </div>
                
                <div class="nav-section">
                    <div class="nav-section-title">系统工具</div>
                    <a href="system_logs.php" class="nav-item">
                        <i class="fas fa-file-alt"></i>
                        系统日志
                    </a>
                    <a href="backup.php" class="nav-item">
                        <i class="fas fa-database"></i>
                        数据备份
                    </a>
                    <a href="cache.php" class="nav-item">
                        <i class="fas fa-broom"></i>
                        清理缓存
                    </a>
                    <a href="system_info.php" class="nav-item">
                        <i class="fas fa-info-circle"></i>
                        系统信息
                    </a>
                </div>
                
                <div class="nav-section">
                    <div class="nav-section-title">API管理</div>
                    <a href="api.php?s=/api/v1/config" class="nav-item" target="_blank">
                        <i class="fas fa-code"></i>
                        API文档
                    </a>
                    <a href="#" class="nav-item" onclick="alert('功能开发中')">
                        <i class="fas fa-chart-line"></i>
                        API统计
                    </a>
                </div>
            </nav>
        </aside>

        <!-- 主内容区域 -->
        <div class="main-content">
            <!-- 顶部导航 -->
            <header class="top-header">
                <div class="header-left">
                    <!-- 移动端菜单按钮 -->
                    <button class="mobile-menu-btn" id="mobileMenuBtn">
                        <i class="fas fa-bars"></i>
                    </button>
                    <h1 class="header-title">系统设置</h1>
                </div>
                <div class="header-actions">
                    <div class="user-menu">
                        <div class="user-avatar">
                            A
                        </div>
                        <div class="user-info">
                            <span class="user-name">管理员</span>
                            <span class="user-role">系统管理员</span>
                        </div>
                    </div>
                    <a href="login.php?logout=1" class="logout-btn">
                        <i class="fas fa-sign-out-alt"></i> 退出登录
                    </a>
                </div>
            </header>

            <!-- 内容区域 -->
            <main class="content-area">
                <!-- 消息提示 -->
        <?php if (!empty($success_message)): ?>
                <div class="alert alert-success">
                    <i class="fas fa-check-circle"></i>
                    <?php echo htmlspecialchars($success_message); ?>
                </div>
        <?php endif; ?>
        
        <?php if (!empty($error_message)): ?>
                <div class="alert alert-error">
                    <i class="fas fa-exclamation-circle"></i>
                    <?php echo htmlspecialchars($error_message); ?>
                </div>
        <?php endif; ?>
        
                <!-- 标签页导航 -->
        <ul class="nav-tabs">
                    <li><a href="#basic" class="active"><i class="fas fa-cog"></i> 基础设置</a></li>
                    <li><a href="#parser"><i class="fas fa-play-circle"></i> 解析设置</a></li>
                    <li><a href="#announcement"><i class="fas fa-bullhorn"></i> 公告管理</a></li>
        </ul>
        
                <!-- 标签页内容 -->
        <div class="tab-content">
            <!-- 基础设置 -->
            <div id="basic" class="active">
                <div class="card">
                    <div class="card-header">
                                <h2 class="card-title">
                                    <i class="fas fa-cog"></i>
                                    基础设置
                                </h2>
                    </div>
                            <div class="card-body">
                    <form method="POST" action="">
                        <input type="hidden" name="action" value="update_basic">
                        <input type="hidden" name="id" value="<?php echo $basic_setting['id']; ?>">
                        
                        <div class="form-group">
                                        <label for="app_name" class="form-label">
                                            <i class="fas fa-tag"></i>
                                            软件名称
                                        </label>
                            <input type="text" class="form-control" id="app_name" name="app_name" 
                                               value="<?php echo htmlspecialchars($basic_setting['app_name']); ?>" 
                                               placeholder="请输入软件名称" required>
                        </div>
                        
                        <div class="form-group">
                                        <label for="android_version" class="form-label">
                                            <i class="fab fa-android"></i>
                                            Android版本号
                                        </label>
                            <input type="text" class="form-control" id="android_version" name="android_version" 
                                               value="<?php echo htmlspecialchars($basic_setting['android_version']); ?>"
                                               placeholder="例：1.0.0">
                        </div>
                        
                        <div class="form-group">
                                        <label for="ios_version" class="form-label">
                                            <i class="fab fa-apple"></i>
                                            iOS版本号
                                        </label>
                            <input type="text" class="form-control" id="ios_version" name="ios_version" 
                                               value="<?php echo htmlspecialchars($basic_setting['ios_version']); ?>"
                                               placeholder="例：1.0.0">
                        </div>
                        
                        <div class="form-group">
                                        <label for="windows_version" class="form-label">
                                            <i class="fab fa-windows"></i>
                                            Windows版本号
                                        </label>
                            <input type="text" class="form-control" id="windows_version" name="windows_version" 
                                               value="<?php echo htmlspecialchars($basic_setting['windows_version']); ?>"
                                               placeholder="例：1.0.0">
                        </div>
                        
                        <div class="form-group">
                                        <label for="linux_version" class="form-label">
                                            <i class="fab fa-linux"></i>
                                            Linux版本号
                                        </label>
                            <input type="text" class="form-control" id="linux_version" name="linux_version" 
                                               value="<?php echo htmlspecialchars($basic_setting['linux_version']); ?>"
                                               placeholder="例：1.0.0">
                        </div>
                        
                        <div class="form-group">
                                        <label for="encrypt_key" class="form-label">
                                            <i class="fas fa-key"></i>
                                            加密密钥
                                        </label>
                            <input type="text" class="form-control" id="encrypt_key" name="encrypt_key" 
                                               value="<?php echo htmlspecialchars($basic_setting['encrypt_key']); ?>"
                                               placeholder="请输入加密密钥">
                        </div>
                        
                        <div class="form-group">
                                        <label for="banner_level" class="form-label">
                                            <i class="fas fa-images"></i>
                                            轮播图推荐等级
                                        </label>
                            <select class="form-control" id="banner_level" name="banner_level" required>
                                <option value="">请选择轮播图推荐等级</option>
                                <?php for ($i = 1; $i <= 9; $i++): ?>
                                <option value="<?php echo $i; ?>" 
                                    <?php echo (isset($basic_setting['banner_level']) && $basic_setting['banner_level'] == $i) ? 'selected' : ''; ?>>
                                    等级 <?php echo $i; ?>
                                </option>
                                <?php endfor; ?>
                            </select>
                            <small class="form-text text-muted">选择轮播图显示的视频推荐等级（默认：9）</small>
                        </div>
                        
                        <div class="form-group">
                                        <label for="hot_level" class="form-label">
                                            <i class="fas fa-fire"></i>
                                            热门数据等级
                                        </label>
                            <select class="form-control" id="hot_level" name="hot_level" required>
                                <option value="">请选择热门数据等级</option>
                                <?php for ($i = 1; $i <= 9; $i++): ?>
                                <option value="<?php echo $i; ?>" 
                                    <?php echo (isset($basic_setting['hot_level']) && $basic_setting['hot_level'] == $i) ? 'selected' : ''; ?>>
                                    等级 <?php echo $i; ?>
                                </option>
                                <?php endfor; ?>
                            </select>
                            <small class="form-text text-muted">选择热门数据显示的视频推荐等级（默认：6）</small>
                        </div>
                        
                                    <button type="submit" class="btn btn-primary">
                                        <i class="fas fa-save"></i>
                                        保存设置
                                    </button>
                    </form>
                            </div>
                </div>
            </div>
            
            <!-- 解析设置 -->
            <div id="parser">
                        <!-- 添加解析表单 -->
                <div class="card">
                    <div class="card-header">
                                <h2 class="card-title">
                                    <i class="fas fa-plus-circle"></i>
                                    添加解析器
                                </h2>
                    </div>
                            <div class="card-body">
                    <form method="POST" action="">
                        <input type="hidden" name="action" value="add_parser">
                        
                        <div class="form-group">
                                        <label for="parser_name" class="form-label">
                                            <i class="fas fa-tag"></i>
                                            解析名称
                                        </label>
                                        <input type="text" class="form-control" id="parser_name" name="parser_name" 
                                               placeholder="请输入解析器名称" required>
                        </div>
                        
                        <div class="form-group">
                                        <label for="resolution" class="form-label">
                                            <i class="fas fa-desktop"></i>
                                            解析度
                                        </label>
                                        <input type="text" class="form-control" id="resolution" name="resolution"
                                               placeholder="例：1080P">
                        </div>
                        
                        <div class="form-group">
                                        <label for="player_type" class="form-label">
                                            <i class="fas fa-play"></i>
                                            播放器类型
                                        </label>
                                        <input type="text" class="form-control" id="player_type" name="player_type"
                                               placeholder="例：video">
                        </div>
                        
                        <div class="form-group">
                                        <label for="encoding" class="form-label">
                                            <i class="fas fa-code"></i>
                                            编码方式
                                        </label>
                                        <input type="text" class="form-control" id="encoding" name="encoding"
                                               placeholder="例：UTF-8">
                        </div>
                        
                        <div class="form-group">
                                        <label for="parse_method" class="form-label">
                                            <i class="fas fa-cogs"></i>
                                            解析方法
                                        </label>
                                        <input type="text" class="form-control" id="parse_method" name="parse_method" 
                                               placeholder="请输入解析方法" required>
                        </div>
                        
                        <div class="form-group">
                                        <label for="parse_url" class="form-label">
                                            <i class="fas fa-link"></i>
                                            解析链接
                                        </label>
                                        <textarea class="form-control" id="parse_url" name="parse_url" rows="3" 
                                                  placeholder="请输入解析链接地址" required></textarea>
                        </div>
                        
                        <div class="form-group">
                                        <label for="remark" class="form-label">
                                            <i class="fas fa-comment"></i>
                                            备注信息
                                        </label>
                                        <textarea class="form-control" id="remark" name="remark" rows="2"
                                                  placeholder="可选：添加备注说明"></textarea>
                        </div>
                        
                        <div class="form-group">
                                        <label for="sort" class="form-label">
                                            <i class="fas fa-sort"></i>
                                            排序权重
                                        </label>
                                        <input type="number" class="form-control" id="sort" name="sort" value="0"
                                               placeholder="数字越小排序越靠前">
                        </div>
                        
                                    <button type="submit" class="btn btn-primary">
                                        <i class="fas fa-plus"></i>
                                        添加解析器
                                    </button>
                    </form>
                            </div>
                </div>
                
                        <!-- 解析器列表 -->
                <div class="card">
                    <div class="card-header">
                                <h2 class="card-title">
                                    <i class="fas fa-list"></i>
                                    解析器列表
                                </h2>
                    </div>
                            <div class="card-body">
                                <div class="table-container">
                    <table class="table">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>名称</th>
                                <th>解析度</th>
                                <th>播放器</th>
                                <th>编码</th>
                                <th>方法</th>
                                <th>状态</th>
                                <th>操作</th>
                            </tr>
                        </thead>
                        <tbody>
                                            <?php if (empty($parsers)): ?>
                                            <tr>
                                                <td colspan="8" style="text-align: center; color: var(--gray-600); padding: 2rem;">
                                                    <i class="fas fa-inbox" style="font-size: 2rem; margin-bottom: 1rem; display: block;"></i>
                                                    暂无解析器数据
                                                </td>
                                            </tr>
                                            <?php else: ?>
                            <?php foreach ($parsers as $parser): ?>
                            <tr>
                                <td><?php echo $parser['id']; ?></td>
                                                <td>
                                                    <span style="font-weight: 500;"><?php echo htmlspecialchars($parser['name']); ?></span>
                                                </td>
                                <td><?php echo htmlspecialchars($parser['resolution']); ?></td>
                                <td><?php echo htmlspecialchars($parser['player_type']); ?></td>
                                <td><?php echo htmlspecialchars($parser['encoding']); ?></td>
                                <td><?php echo htmlspecialchars($parser['parse_method']); ?></td>
                                                <td>
                                                    <?php if ($parser['status']): ?>
                                                    <span style="color: #059669; font-weight: 500;">
                                                        <i class="fas fa-check-circle"></i> 启用
                                                    </span>
                                                    <?php else: ?>
                                                    <span style="color: #dc2626; font-weight: 500;">
                                                        <i class="fas fa-times-circle"></i> 禁用
                                                    </span>
                                                    <?php endif; ?>
                                                </td>
                                <td>
                                    <form method="POST" action="" style="display: inline;">
                                        <input type="hidden" name="action" value="delete_parser">
                                        <input type="hidden" name="parser_id" value="<?php echo $parser['id']; ?>">
                                                        <button type="submit" class="btn btn-danger" 
                                                                onclick="return confirm('确定要删除解析器「<?php echo htmlspecialchars($parser['name']); ?>」吗？')">
                                                            <i class="fas fa-trash"></i> 删除
                                                        </button>
                                    </form>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                                            <?php endif; ?>
                        </tbody>
                    </table>
                                </div>
                            </div>
                </div>
            </div>
            
            <!-- 公告管理 -->
            <div id="announcement">
                        <!-- 添加公告表单 -->
                <div class="card">
                    <div class="card-header">
                                <h2 class="card-title">
                                    <i class="fas fa-plus-circle"></i>
                                    发布公告
                                </h2>
                    </div>
                            <div class="card-body">
                    <form method="POST" action="">
                        <input type="hidden" name="action" value="add_announcement">
                        
                        <div class="form-group">
                                        <label for="title" class="form-label">
                                            <i class="fas fa-heading"></i>
                                            公告标题
                                        </label>
                                        <input type="text" class="form-control" id="title" name="title" 
                                               placeholder="请输入公告标题" required>
                        </div>
                        
                        <div class="form-group">
                                        <label for="content" class="form-label">
                                            <i class="fas fa-edit"></i>
                                            公告内容
                                        </label>
                                        <textarea class="form-control" id="content" name="content" rows="4" 
                                                  placeholder="请输入公告内容详情" required></textarea>
                        </div>
                        
                                    <div class="form-check">
                                        <input type="checkbox" class="form-check-input" id="is_force" name="is_force" value="1">
                                        <label for="is_force" class="form-check-label">
                                            <i class="fas fa-exclamation-triangle"></i>
                                            强制提醒 (用户必须查看此公告)
                            </label>
                        </div>
                        
                                    <button type="submit" class="btn btn-primary">
                                        <i class="fas fa-bullhorn"></i>
                                        发布公告
                                    </button>
                    </form>
                            </div>
                </div>
                
                        <!-- 公告列表 -->
                <div class="card">
                    <div class="card-header">
                                <h2 class="card-title">
                                    <i class="fas fa-list"></i>
                                    公告列表
                                </h2>
                    </div>
                            <div class="card-body">
                                <div class="table-container">
                    <table class="table">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>标题</th>
                                <th>强制提醒</th>
                                <th>状态</th>
                                <th>创建时间</th>
                                <th>操作</th>
                            </tr>
                        </thead>
                        <tbody>
                                            <?php if (empty($announcements)): ?>
                                            <tr>
                                                <td colspan="6" style="text-align: center; color: var(--gray-600); padding: 2rem;">
                                                    <i class="fas fa-inbox" style="font-size: 2rem; margin-bottom: 1rem; display: block;"></i>
                                                    暂无公告数据
                                                </td>
                                            </tr>
                                            <?php else: ?>
                            <?php foreach ($announcements as $announcement): ?>
                            <tr>
                                <td><?php echo $announcement['id']; ?></td>
                                                <td>
                                                    <span style="font-weight: 500;"><?php echo htmlspecialchars($announcement['title']); ?></span>
                                                    <?php if ($announcement['is_force']): ?>
                                                    <span style="color: #dc2626; margin-left: 0.5rem;">
                                                        <i class="fas fa-exclamation-triangle"></i>
                                                    </span>
                                                    <?php endif; ?>
                                                </td>
                                                <td>
                                                    <?php if ($announcement['is_force']): ?>
                                                    <span style="color: #dc2626; font-weight: 500;">
                                                        <i class="fas fa-exclamation-triangle"></i> 是
                                                    </span>
                                                    <?php else: ?>
                                                    <span style="color: var(--gray-600);">
                                                        <i class="fas fa-info-circle"></i> 否
                                                    </span>
                                                    <?php endif; ?>
                                                </td>
                                                <td>
                                                    <?php if ($announcement['status']): ?>
                                                    <span style="color: #059669; font-weight: 500;">
                                                        <i class="fas fa-check-circle"></i> 启用
                                                    </span>
                                                    <?php else: ?>
                                                    <span style="color: #dc2626; font-weight: 500;">
                                                        <i class="fas fa-times-circle"></i> 禁用
                                                    </span>
                                                    <?php endif; ?>
                                                </td>
                                                <td style="color: var(--gray-600);">
                                                    <?php echo $announcement['create_time']; ?>
                                                </td>
                                <td>
                                    <form method="POST" action="" style="display: inline;">
                                        <input type="hidden" name="action" value="delete_announcement">
                                        <input type="hidden" name="announcement_id" value="<?php echo $announcement['id']; ?>">
                                                        <button type="submit" class="btn btn-danger" 
                                                                onclick="return confirm('确定要删除公告「<?php echo htmlspecialchars($announcement['title']); ?>」吗？')">
                                                            <i class="fas fa-trash"></i> 删除
                                                        </button>
                                    </form>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
                        </div>
                    </div>
                </div>
            </main>
        </div>
    </div>
    
    <script>
        // 标签页切换功能
        document.addEventListener('DOMContentLoaded', function() {
            // 移动端菜单控制
            const mobileMenuBtn = document.getElementById('mobileMenuBtn');
            const sidebar = document.getElementById('sidebar');
            const mobileOverlay = document.getElementById('mobileOverlay');
            const body = document.body;

            // 切换移动端菜单
            function toggleMobileMenu() {
                const isOpen = sidebar.classList.contains('mobile-open');
                
                if (isOpen) {
                    closeMobileMenu();
                } else {
                    openMobileMenu();
                }
            }

            // 打开移动端菜单
            function openMobileMenu() {
                sidebar.classList.add('mobile-open');
                mobileOverlay.classList.add('active');
                body.style.overflow = 'hidden';
                
                // 更新按钮图标
                const icon = mobileMenuBtn.querySelector('i');
                icon.className = 'fas fa-times';
            }

            // 关闭移动端菜单
            function closeMobileMenu() {
                sidebar.classList.remove('mobile-open');
                mobileOverlay.classList.remove('active');
                body.style.overflow = '';
                
                // 还原按钮图标
                const icon = mobileMenuBtn.querySelector('i');
                icon.className = 'fas fa-bars';
            }

            // 菜单按钮点击事件
            if (mobileMenuBtn) {
                mobileMenuBtn.addEventListener('click', toggleMobileMenu);
            }

            // 遮罩层点击关闭菜单
            if (mobileOverlay) {
                mobileOverlay.addEventListener('click', closeMobileMenu);
            }

            // 窗口大小改变时处理菜单状态
            window.addEventListener('resize', function() {
                if (window.innerWidth > 1024) {
                    closeMobileMenu();
                }
            });

            // 点击侧边栏链接后关闭移动端菜单
            const sidebarLinks = sidebar.querySelectorAll('.nav-item');
            sidebarLinks.forEach(link => {
                link.addEventListener('click', function() {
                    if (window.innerWidth <= 1024) {
                        setTimeout(closeMobileMenu, 150);
                    }
                });
            });

            // ESC键关闭菜单
            document.addEventListener('keydown', function(e) {
                if (e.key === 'Escape' && sidebar.classList.contains('mobile-open')) {
                    closeMobileMenu();
                }
            });

            // 标签页功能
            const tabs = document.querySelectorAll('.nav-tabs a');
            const contents = document.querySelectorAll('.tab-content > div');
            
            // 处理URL hash参数
            function handleHashChange() {
                const hash = window.location.hash || '#basic';
                const targetTab = document.querySelector(`.nav-tabs a[href="${hash}"]`);
                const targetContent = document.querySelector(hash);
                
                if (targetTab && targetContent) {
                    // 移除所有活动状态
                    tabs.forEach(t => t.classList.remove('active'));
                    contents.forEach(c => c.classList.remove('active'));
                    
                    // 添加新的活动状态
                    targetTab.classList.add('active');
                    targetContent.classList.add('active');
                }
            }
            
            // 初始化页面时处理hash
            handleHashChange();
            
            // 监听hash变化
            window.addEventListener('hashchange', handleHashChange);
            
            // 标签页点击事件
            tabs.forEach(tab => {
                tab.addEventListener('click', function(e) {
                    e.preventDefault();
                    
                    const href = this.getAttribute('href');
                    window.location.hash = href;
                    handleHashChange();
                });
            });
            
            // 添加加载动画效果
            const forms = document.querySelectorAll('form');
            forms.forEach(form => {
                form.addEventListener('submit', function() {
                    const submitBtn = this.querySelector('button[type="submit"]');
                    if (submitBtn) {
                        submitBtn.disabled = true;
                        submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> 处理中...';
                    }
                });
            });
        });
    </script>
</body>
</html>
