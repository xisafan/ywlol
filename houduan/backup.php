<?php
// +----------------------------------------------------------------------
// | 星星NB 管理系统
// +----------------------------------------------------------------------
// | 数据备份管理
// +----------------------------------------------------------------------

// 启动会话
session_start();

// 检查用户是否已登录
if (!isset($_SESSION['admin_id']) || $_SESSION['admin_id'] <= 0) {
    header('Location: login.php');
    exit;
}

// 获取当前管理员信息
$admin_id = $_SESSION['admin_id'];
$admin_username = $_SESSION['admin_username'];

// 引入数据库配置
$db_config_file = __DIR__ . '/database.php';
if (!file_exists($db_config_file)) {
    die('数据库配置文件不存在');
}
$db_config = include($db_config_file);

// 备份目录
$backup_dir = __DIR__ . '/backups';
if (!file_exists($backup_dir)) {
    mkdir($backup_dir, 0755, true);
}

// 初始化消息变量
$success_message = '';
$error_message = '';

// 处理操作
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = isset($_POST['action']) ? $_POST['action'] : '';
    
    switch ($action) {
        case 'backup_database':
            $result = backupDatabase($db_config, $backup_dir);
            if ($result['success']) {
                $success_message = $result['message'];
            } else {
                $error_message = $result['message'];
            }
            break;
            
        case 'backup_files':
            $result = backupFiles($backup_dir);
            if ($result['success']) {
                $success_message = $result['message'];
            } else {
                $error_message = $result['message'];
            }
            break;
            
        case 'restore_backup':
            $backup_file = isset($_POST['backup_file']) ? $_POST['backup_file'] : '';
            $result = restoreBackup($backup_file, $db_config, $backup_dir);
            if ($result['success']) {
                $success_message = $result['message'];
            } else {
                $error_message = $result['message'];
            }
            break;
            
        case 'delete_backup':
            $backup_file = isset($_POST['backup_file']) ? $_POST['backup_file'] : '';
            $result = deleteBackup($backup_file, $backup_dir);
            if ($result['success']) {
                $success_message = $result['message'];
            } else {
                $error_message = $result['message'];
            }
            break;
    }
}

// 数据库备份函数
function backupDatabase($db_config, $backup_dir) {
    try {
        $filename = 'database_backup_' . date('Y-m-d_H-i-s') . '.sql';
        $backup_file = $backup_dir . '/' . $filename;
        
        // 连接数据库
        $dsn = "mysql:host={$db_config['hostname']};port={$db_config['hostport']};dbname={$db_config['database']};charset={$db_config['charset']}";
        $pdo = new PDO($dsn, $db_config['username'], $db_config['password']);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        
        // 获取所有表
        $tables = [];
        $result = $pdo->query("SHOW TABLES");
        while ($row = $result->fetch(PDO::FETCH_NUM)) {
            $tables[] = $row[0];
        }
        
        // 开始备份
        $backup_content = "-- 星星NB管理系统数据库备份\n";
        $backup_content .= "-- 备份时间: " . date('Y-m-d H:i:s') . "\n";
        $backup_content .= "-- 数据库: {$db_config['database']}\n\n";
        $backup_content .= "SET FOREIGN_KEY_CHECKS=0;\n\n";
        
        foreach ($tables as $table) {
            // 获取表结构
            $result = $pdo->query("SHOW CREATE TABLE `$table`");
            $row = $result->fetch(PDO::FETCH_ASSOC);
            
            $backup_content .= "-- 表结构: $table\n";
            $backup_content .= "DROP TABLE IF EXISTS `$table`;\n";
            $backup_content .= $row['Create Table'] . ";\n\n";
            
            // 获取表数据
            $result = $pdo->query("SELECT * FROM `$table`");
            $rows = $result->fetchAll(PDO::FETCH_ASSOC);
            
            if (!empty($rows)) {
                $backup_content .= "-- 表数据: $table\n";
                $backup_content .= "INSERT INTO `$table` VALUES \n";
                
                $values = [];
                foreach ($rows as $row) {
                    $escaped_values = [];
                    foreach ($row as $value) {
                        if ($value === null) {
                            $escaped_values[] = 'NULL';
                        } else {
                            $escaped_values[] = $pdo->quote($value);
                        }
                    }
                    $values[] = '(' . implode(', ', $escaped_values) . ')';
                }
                
                $backup_content .= implode(",\n", $values) . ";\n\n";
            }
        }
        
        $backup_content .= "SET FOREIGN_KEY_CHECKS=1;\n";
        
        // 写入备份文件
        if (file_put_contents($backup_file, $backup_content) !== false) {
            return ['success' => true, 'message' => "数据库备份成功: $filename"];
        } else {
            return ['success' => false, 'message' => '备份文件写入失败'];
        }
        
    } catch (Exception $e) {
        return ['success' => false, 'message' => '数据库备份失败: ' . $e->getMessage()];
    }
}

// 文件备份函数
function backupFiles($backup_dir) {
    try {
        $filename = 'files_backup_' . date('Y-m-d_H-i-s') . '.zip';
        $backup_file = $backup_dir . '/' . $filename;
        
        $zip = new ZipArchive();
        if ($zip->open($backup_file, ZipArchive::CREATE) !== TRUE) {
            return ['success' => false, 'message' => '无法创建ZIP文件'];
        }
        
        // 要备份的目录
        $dirs_to_backup = [
            __DIR__ . '/../assets',
            __DIR__ . '/../fonts',
            __DIR__ . '/img',
            __DIR__ // 当前目录的PHP文件
        ];
        
        foreach ($dirs_to_backup as $dir) {
            if (is_dir($dir)) {
                addDirectoryToZip($zip, $dir, basename($dir));
            }
        }
        
        // 添加单个重要文件
        $important_files = [
            __DIR__ . '/database.php',
            __DIR__ . '/../pubspec.yaml',
            __DIR__ . '/../README.md'
        ];
        
        foreach ($important_files as $file) {
            if (file_exists($file)) {
                $zip->addFile($file, basename($file));
            }
        }
        
        $zip->close();
        
        return ['success' => true, 'message' => "文件备份成功: $filename"];
        
    } catch (Exception $e) {
        return ['success' => false, 'message' => '文件备份失败: ' . $e->getMessage()];
    }
}

// 递归添加目录到ZIP
function addDirectoryToZip($zip, $dir, $zip_dir = '') {
    if (is_dir($dir)) {
        if ($dh = opendir($dir)) {
            while (($file = readdir($dh)) !== false) {
                if ($file !== '.' && $file !== '..' && $file !== 'backups') {
                    $full_path = $dir . '/' . $file;
                    $zip_path = $zip_dir ? $zip_dir . '/' . $file : $file;
                    
                    if (is_dir($full_path)) {
                        $zip->addEmptyDir($zip_path);
                        addDirectoryToZip($zip, $full_path, $zip_path);
                    } else {
                        $zip->addFile($full_path, $zip_path);
                    }
                }
            }
            closedir($dh);
        }
    }
}

// 恢复备份函数
function restoreBackup($backup_file, $db_config, $backup_dir) {
    try {
        $backup_path = $backup_dir . '/' . $backup_file;
        
        if (!file_exists($backup_path)) {
            return ['success' => false, 'message' => '备份文件不存在'];
        }
        
        // 只处理SQL备份文件的恢复
        if (pathinfo($backup_file, PATHINFO_EXTENSION) === 'sql') {
            $sql_content = file_get_contents($backup_path);
            
            if ($sql_content === false) {
                return ['success' => false, 'message' => '无法读取备份文件'];
            }
            
            // 连接数据库
            $dsn = "mysql:host={$db_config['hostname']};port={$db_config['hostport']};dbname={$db_config['database']};charset={$db_config['charset']}";
            $pdo = new PDO($dsn, $db_config['username'], $db_config['password']);
            $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            
            // 执行SQL
            $pdo->exec($sql_content);
            
            return ['success' => true, 'message' => '数据库恢复成功'];
        } else {
            return ['success' => false, 'message' => '文件恢复功能需要手动操作'];
        }
        
    } catch (Exception $e) {
        return ['success' => false, 'message' => '恢复失败: ' . $e->getMessage()];
    }
}

// 删除备份函数
function deleteBackup($backup_file, $backup_dir) {
    try {
        $backup_path = $backup_dir . '/' . $backup_file;
        
        if (!file_exists($backup_path)) {
            return ['success' => false, 'message' => '备份文件不存在'];
        }
        
        if (unlink($backup_path)) {
            return ['success' => true, 'message' => '备份文件删除成功'];
        } else {
            return ['success' => false, 'message' => '备份文件删除失败'];
        }
        
    } catch (Exception $e) {
        return ['success' => false, 'message' => '删除失败: ' . $e->getMessage()];
    }
}

// 获取备份文件列表
function getBackupFiles($backup_dir) {
    $backups = [];
    
    if (is_dir($backup_dir)) {
        $files = scandir($backup_dir);
        foreach ($files as $file) {
            if ($file !== '.' && $file !== '..' && is_file($backup_dir . '/' . $file)) {
                $file_path = $backup_dir . '/' . $file;
                $backups[] = [
                    'name' => $file,
                    'size' => filesize($file_path),
                    'created' => date('Y-m-d H:i:s', filemtime($file_path)),
                    'type' => pathinfo($file, PATHINFO_EXTENSION) === 'sql' ? 'database' : 'files'
                ];
            }
        }
    }
    
    // 按创建时间排序
    usort($backups, function($a, $b) {
        return strtotime($b['created']) - strtotime($a['created']);
    });
    
    return $backups;
}

$backup_files = getBackupFiles($backup_dir);
?>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>数据备份 - 星星NB管理系统</title>
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

        /* 复用之前的基础样式 */
        .admin-layout {
            display: flex;
            min-height: 100vh;
        }

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

        .main-content {
            margin-left: var(--sidebar-width);
            flex: 1;
            display: flex;
            flex-direction: column;
        }

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

        .header-actions {
            display: flex;
            align-items: center;
            gap: 1rem;
        }

        .back-btn {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.5rem 1rem;
            background: var(--gray-100);
            color: var(--gray-700);
            text-decoration: none;
            border-radius: 0.5rem;
            transition: all 0.2s ease;
        }

        .back-btn:hover {
            background: var(--gray-200);
        }

        .content-area {
            flex: 1;
            padding: 2rem;
        }

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
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .card-title {
            font-size: 1.25rem;
            font-weight: 600;
            color: var(--gray-900);
        }

        .card-body {
            padding: 1.5rem;
        }

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

        .btn-success {
            background: #059669;
            color: var(--white);
        }

        .btn-success:hover {
            background: #047857;
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

        /* 备份操作卡片 */
        .backup-actions {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }

        .backup-action-card {
            background: var(--white);
            border-radius: 0.75rem;
            box-shadow: var(--shadow);
            padding: 1.5rem;
            text-align: center;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }

        .backup-action-card:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-lg);
        }

        .backup-icon {
            width: 4rem;
            height: 4rem;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 1rem;
            font-size: 1.5rem;
            color: var(--white);
        }

        .backup-icon.database {
            background: linear-gradient(135deg, var(--primary-blue), var(--dark-blue));
        }

        .backup-icon.files {
            background: linear-gradient(135deg, #059669, #047857);
        }

        .backup-action-title {
            font-size: 1.25rem;
            font-weight: 600;
            color: var(--gray-900);
            margin-bottom: 0.5rem;
        }

        .backup-action-desc {
            color: var(--gray-600);
            margin-bottom: 1.5rem;
            line-height: 1.5;
        }

        /* 备份文件列表 */
        .backup-list {
            background: var(--white);
            border-radius: 0.75rem;
            box-shadow: var(--shadow);
            overflow: hidden;
        }

        .backup-item {
            padding: 1rem 1.5rem;
            border-bottom: 1px solid var(--gray-200);
            display: flex;
            align-items: center;
            justify-content: space-between;
            transition: background-color 0.2s ease;
        }

        .backup-item:hover {
            background: var(--gray-50);
        }

        .backup-item:last-child {
            border-bottom: none;
        }

        .backup-info {
            flex: 1;
        }

        .backup-name {
            font-weight: 600;
            color: var(--gray-900);
            margin-bottom: 0.25rem;
        }

        .backup-meta {
            font-size: 0.875rem;
            color: var(--gray-600);
            display: flex;
            gap: 1rem;
            flex-wrap: wrap;
        }

        .backup-actions-btn {
            display: flex;
            gap: 0.5rem;
        }

        .backup-type-badge {
            display: inline-flex;
            align-items: center;
            gap: 0.25rem;
            padding: 0.25rem 0.75rem;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 500;
        }

        .backup-type-badge.database {
            background: var(--light-blue);
            color: var(--primary-blue);
        }

        .backup-type-badge.files {
            background: #dcfce7;
            color: #059669;
        }

        /* 消息提示 */
        .alert {
            padding: 1rem 1.5rem;
            border-radius: 0.5rem;
            margin-bottom: 1.5rem;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .alert-success {
            background: #f0fdf4;
            border: 1px solid #bbf7d0;
            color: #166534;
        }

        .alert-error {
            background: #fef2f2;
            border: 1px solid #fecaca;
            color: #dc2626;
        }

        /* 响应式设计 */
        @media (max-width: 1024px) {
            .sidebar {
                transform: translateX(-100%);
                transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
                box-shadow: var(--shadow-lg);
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

            .backup-actions {
                grid-template-columns: 1fr;
            }

            .backup-item {
                flex-direction: column;
                align-items: flex-start;
                gap: 1rem;
            }

            .backup-actions-btn {
                width: 100%;
                justify-content: flex-end;
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
                    <a href="setting.php" class="nav-item">
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
                    <a href="backup.php" class="nav-item active">
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
                    <button class="mobile-menu-btn" id="mobileMenuBtn">
                        <i class="fas fa-bars"></i>
                    </button>
                    <h1 class="header-title">数据备份</h1>
                </div>
                <div class="header-actions">
                    <a href="index.php" class="back-btn">
                        <i class="fas fa-arrow-left"></i>
                        返回控制台
                    </a>
                </div>
            </header>

            <!-- 内容区域 -->
            <main class="content-area">
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

                <!-- 备份操作 -->
                <div class="backup-actions">
                    <!-- 数据库备份 -->
                    <div class="backup-action-card">
                        <div class="backup-icon database">
                            <i class="fas fa-database"></i>
                        </div>
                        <h3 class="backup-action-title">数据库备份</h3>
                        <p class="backup-action-desc">备份所有数据库表和数据，生成SQL文件</p>
                        <form method="POST" style="display: inline;">
                            <input type="hidden" name="action" value="backup_database">
                            <button type="submit" class="btn btn-primary" onclick="return confirm('确定要备份数据库吗？')">
                                <i class="fas fa-download"></i>
                                创建数据库备份
                            </button>
                        </form>
                    </div>

                    <!-- 文件备份 -->
                    <div class="backup-action-card">
                        <div class="backup-icon files">
                            <i class="fas fa-folder"></i>
                        </div>
                        <h3 class="backup-action-title">文件备份</h3>
                        <p class="backup-action-desc">备份系统文件、配置文件和资源文件</p>
                        <form method="POST" style="display: inline;">
                            <input type="hidden" name="action" value="backup_files">
                            <button type="submit" class="btn btn-success" onclick="return confirm('确定要备份文件吗？这可能需要一些时间。')">
                                <i class="fas fa-archive"></i>
                                创建文件备份
                            </button>
                        </form>
                    </div>
                </div>

                <!-- 备份文件列表 -->
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fas fa-list"></i>
                            备份文件列表
                        </h2>
                        <div>
                            <button onclick="location.reload()" class="btn btn-secondary">
                                <i class="fas fa-sync-alt"></i>
                                刷新
                            </button>
                        </div>
                    </div>
                    <div class="card-body" style="padding: 0;">
                        <?php if (empty($backup_files)): ?>
                        <div style="padding: 2rem; text-align: center; color: var(--gray-600);">
                            <i class="fas fa-inbox" style="font-size: 3rem; margin-bottom: 1rem; display: block; opacity: 0.5;"></i>
                            <p>暂无备份文件</p>
                            <p style="font-size: 0.875rem; margin-top: 0.5rem;">点击上方按钮创建第一个备份</p>
                        </div>
                        <?php else: ?>
                        <div class="backup-list">
                            <?php foreach ($backup_files as $backup): ?>
                            <div class="backup-item">
                                <div class="backup-info">
                                    <div class="backup-name">
                                        <i class="fas fa-<?php echo $backup['type'] === 'database' ? 'database' : 'archive'; ?>"></i>
                                        <?php echo htmlspecialchars($backup['name']); ?>
                                    </div>
                                    <div class="backup-meta">
                                        <span class="backup-type-badge <?php echo $backup['type']; ?>">
                                            <i class="fas fa-<?php echo $backup['type'] === 'database' ? 'database' : 'folder'; ?>"></i>
                                            <?php echo $backup['type'] === 'database' ? '数据库' : '文件'; ?>
                                        </span>
                                        <span>
                                            <i class="fas fa-calendar"></i>
                                            <?php echo $backup['created']; ?>
                                        </span>
                                        <span>
                                            <i class="fas fa-weight-hanging"></i>
                                            <?php 
                                            $size = $backup['size'];
                                            if ($size > 1024 * 1024) {
                                                echo number_format($size / (1024 * 1024), 2) . ' MB';
                                            } elseif ($size > 1024) {
                                                echo number_format($size / 1024, 2) . ' KB';
                                            } else {
                                                echo $size . ' bytes';
                                            }
                                            ?>
                                        </span>
                                    </div>
                                </div>
                                <div class="backup-actions-btn">
                                    <a href="backups/<?php echo urlencode($backup['name']); ?>" 
                                       class="btn btn-secondary" download>
                                        <i class="fas fa-download"></i>
                                        下载
                                    </a>
                                    <?php if ($backup['type'] === 'database'): ?>
                                    <form method="POST" style="display: inline;">
                                        <input type="hidden" name="action" value="restore_backup">
                                        <input type="hidden" name="backup_file" value="<?php echo htmlspecialchars($backup['name']); ?>">
                                        <button type="submit" class="btn btn-primary" 
                                                onclick="return confirm('确定要恢复此备份吗？这将覆盖当前数据库！')">
                                            <i class="fas fa-undo"></i>
                                            恢复
                                        </button>
                                    </form>
                                    <?php endif; ?>
                                    <form method="POST" style="display: inline;">
                                        <input type="hidden" name="action" value="delete_backup">
                                        <input type="hidden" name="backup_file" value="<?php echo htmlspecialchars($backup['name']); ?>">
                                        <button type="submit" class="btn btn-danger" 
                                                onclick="return confirm('确定要删除此备份文件吗？')">
                                            <i class="fas fa-trash"></i>
                                            删除
                                        </button>
                                    </form>
                                </div>
                            </div>
                            <?php endforeach; ?>
                        </div>
                        <?php endif; ?>
                    </div>
                </div>
            </main>
        </div>
    </div>

    <script>
        // 移动端菜单控制（复用之前的代码）
        document.addEventListener('DOMContentLoaded', function() {
            const mobileMenuBtn = document.getElementById('mobileMenuBtn');
            const sidebar = document.getElementById('sidebar');
            const mobileOverlay = document.getElementById('mobileOverlay');
            const body = document.body;

            function toggleMobileMenu() {
                const isOpen = sidebar.classList.contains('mobile-open');
                if (isOpen) {
                    closeMobileMenu();
                } else {
                    openMobileMenu();
                }
            }

            function openMobileMenu() {
                sidebar.classList.add('mobile-open');
                mobileOverlay.classList.add('active');
                body.style.overflow = 'hidden';
                const icon = mobileMenuBtn.querySelector('i');
                icon.className = 'fas fa-times';
            }

            function closeMobileMenu() {
                sidebar.classList.remove('mobile-open');
                mobileOverlay.classList.remove('active');
                body.style.overflow = '';
                const icon = mobileMenuBtn.querySelector('i');
                icon.className = 'fas fa-bars';
            }

            if (mobileMenuBtn) {
                mobileMenuBtn.addEventListener('click', toggleMobileMenu);
            }

            if (mobileOverlay) {
                mobileOverlay.addEventListener('click', closeMobileMenu);
            }

            window.addEventListener('resize', function() {
                if (window.innerWidth > 1024) {
                    closeMobileMenu();
                }
            });

            const sidebarLinks = sidebar.querySelectorAll('.nav-item');
            sidebarLinks.forEach(link => {
                link.addEventListener('click', function() {
                    if (window.innerWidth <= 1024) {
                        setTimeout(closeMobileMenu, 150);
                    }
                });
            });

            document.addEventListener('keydown', function(e) {
                if (e.key === 'Escape' && sidebar.classList.contains('mobile-open')) {
                    closeMobileMenu();
                }
            });
        });

        // 添加表单提交加载状态
        document.addEventListener('DOMContentLoaded', function() {
            const forms = document.querySelectorAll('form');
            forms.forEach(form => {
                form.addEventListener('submit', function() {
                    const submitBtn = this.querySelector('button[type="submit"]');
                    if (submitBtn) {
                        submitBtn.disabled = true;
                        const originalText = submitBtn.innerHTML;
                        submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> 处理中...';
                        
                        // 如果5秒后还没有响应，恢复按钮
                        setTimeout(() => {
                            submitBtn.disabled = false;
                            submitBtn.innerHTML = originalText;
                        }, 5000);
                    }
                });
            });
        });
    </script>
</body>
</html>
