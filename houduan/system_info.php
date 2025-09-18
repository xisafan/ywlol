<?php
// +----------------------------------------------------------------------
// | 星星NB 管理系统
// +----------------------------------------------------------------------
// | 系统信息查看
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

// 获取系统信息
function getSystemInfo() {
    $info = [];
    
    // PHP信息
    $info['php'] = [
        'version' => PHP_VERSION,
        'sapi' => php_sapi_name(),
        'memory_limit' => ini_get('memory_limit'),
        'max_execution_time' => ini_get('max_execution_time'),
        'upload_max_filesize' => ini_get('upload_max_filesize'),
        'post_max_size' => ini_get('post_max_size'),
        'error_reporting' => error_reporting(),
        'date_timezone' => ini_get('date.timezone') ?: date_default_timezone_get(),
        'extensions_count' => count(get_loaded_extensions())
    ];
    
    // 服务器信息
    $info['server'] = [
        'software' => $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown',
        'os' => PHP_OS,
        'hostname' => gethostname(),
        'document_root' => $_SERVER['DOCUMENT_ROOT'] ?? '',
        'server_admin' => $_SERVER['SERVER_ADMIN'] ?? 'N/A',
        'server_port' => $_SERVER['SERVER_PORT'] ?? '80',
        'https' => isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on'
    ];
    
    // 系统负载（仅限Unix系统）
    if (function_exists('sys_getloadavg') && PHP_OS_FAMILY !== 'Windows') {
        $load = sys_getloadavg();
        $info['system'] = [
            'load_1min' => $load[0],
            'load_5min' => $load[1],
            'load_15min' => $load[2]
        ];
    } else {
        $info['system'] = [
            'load_1min' => 'N/A',
            'load_5min' => 'N/A',
            'load_15min' => 'N/A'
        ];
    }
    
    // 内存信息
    $info['memory'] = [
        'current_usage' => memory_get_usage(true),
        'peak_usage' => memory_get_peak_usage(true),
        'limit' => ini_get('memory_limit')
    ];
    
    // 磁盘空间（完全避免 open_basedir 限制）
    $info['disk'] = [];
    
    // 获取 open_basedir 设置
    $open_basedir = ini_get('open_basedir');
    $allowed_paths = [];
    
    if (!empty($open_basedir)) {
        // 解析允许的路径
        $allowed_paths = array_filter(explode(PATH_SEPARATOR, $open_basedir));
    }
    
    // 定义候选路径
    $candidate_paths = [
        'temp' => sys_get_temp_dir(),
        'document_root' => $_SERVER['DOCUMENT_ROOT'] ?? __DIR__,
        'current_dir' => __DIR__
    ];
    
    // 检查每个候选路径是否在允许范围内
    foreach ($candidate_paths as $name => $path) {
        // 标准化路径
        $path = realpath($path) ?: $path;
        $is_allowed = false;
        
        // 如果没有设置 open_basedir，或者路径在允许范围内
        if (empty($open_basedir)) {
            $is_allowed = true;
        } else {
            foreach ($allowed_paths as $allowed_path) {
                if (strpos($path, rtrim($allowed_path, '/') . '/') === 0 || $path === rtrim($allowed_path, '/')) {
                    $is_allowed = true;
                    break;
                }
            }
        }
        
        if ($is_allowed) {
            try {
                // 只对允许的路径进行操作
                if (is_dir($path) && is_readable($path)) {
                    $total_space = disk_total_space($path);
                    $free_space = disk_free_space($path);
                    
                    if ($total_space !== false && $free_space !== false) {
                        $info['disk'][$name] = [
                            'path' => $path,
                            'total' => $total_space,
                            'free' => $free_space
                        ];
                        
                        $info['disk'][$name]['used'] = $total_space - $free_space;
                        $info['disk'][$name]['usage_percent'] = round(($info['disk'][$name]['used'] / $total_space) * 100, 2);
                    }
                }
            } catch (Exception $e) {
                // 忽略错误，继续处理下一个路径
                continue;
            }
        }
    }
    
    return $info;
}

// 获取数据库信息
function getDatabaseInfo() {
    $db_config_file = __DIR__ . '/database.php';
    if (!file_exists($db_config_file)) {
        return ['error' => '数据库配置文件不存在'];
    }
    
    $db_config = include($db_config_file);
    
    try {
        $dsn = "mysql:host={$db_config['hostname']};port={$db_config['hostport']};charset={$db_config['charset']}";
        $pdo = new PDO($dsn, $db_config['username'], $db_config['password']);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        
        // 获取MySQL版本
        $version = $pdo->query("SELECT VERSION()")->fetchColumn();
        
        // 获取数据库大小
        $db_size = 0;
        try {
            $stmt = $pdo->prepare("SELECT SUM(data_length + index_length) as size FROM information_schema.TABLES WHERE table_schema = ?");
            $stmt->execute([$db_config['database']]);
            $result = $stmt->fetch(PDO::FETCH_ASSOC);
            $db_size = $result['size'] ?? 0;
        } catch (Exception $e) {
            // 忽略权限错误
        }
        
        // 获取表数量
        $table_count = 0;
        try {
            $pdo->exec("USE `{$db_config['database']}`");
            $stmt = $pdo->query("SHOW TABLES");
            $table_count = $stmt->rowCount();
        } catch (Exception $e) {
            // 忽略错误
        }
        
        return [
            'connected' => true,
            'version' => $version,
            'host' => $db_config['hostname'],
            'port' => $db_config['hostport'],
            'database' => $db_config['database'],
            'charset' => $db_config['charset'],
            'size' => $db_size,
            'table_count' => $table_count
        ];
        
    } catch (Exception $e) {
        return [
            'connected' => false,
            'error' => $e->getMessage(),
            'host' => $db_config['hostname'],
            'port' => $db_config['hostport'],
            'database' => $db_config['database']
        ];
    }
}

// 获取PHP扩展信息
function getPhpExtensions() {
    $extensions = get_loaded_extensions();
    sort($extensions);
    
    $categorized = [
        'core' => [],
        'database' => [],
        'network' => [],
        'image' => [],
        'security' => [],
        'other' => []
    ];
    
    $categories = [
        'core' => ['Core', 'standard', 'SPL', 'Reflection', 'pcre', 'date', 'json', 'hash'],
        'database' => ['mysql', 'mysqli', 'pdo', 'pdo_mysql', 'sqlite3', 'pdo_sqlite'],
        'network' => ['curl', 'ftp', 'http', 'sockets', 'openssl'],
        'image' => ['gd', 'imagick', 'exif'],
        'security' => ['openssl', 'mcrypt', 'sodium', 'password']
    ];
    
    foreach ($extensions as $ext) {
        $placed = false;
        foreach ($categories as $cat => $cat_extensions) {
            if (in_array($ext, $cat_extensions)) {
                $categorized[$cat][] = $ext;
                $placed = true;
                break;
            }
        }
        if (!$placed) {
            $categorized['other'][] = $ext;
        }
    }
    
    return $categorized;
}

// 格式化字节大小
function formatBytes($size, $precision = 2) {
    if ($size <= 0) return '0 B';
    $base = log($size, 1024);
    $suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    return round(pow(1024, $base - floor($base)), $precision) . ' ' . $suffixes[floor($base)];
}

// 格式化内存限制
function formatMemoryLimit($limit) {
    if ($limit === '-1') {
        return '无限制';
    }
    return $limit;
}

$system_info = getSystemInfo();
$database_info = getDatabaseInfo();
$php_extensions = getPhpExtensions();
?>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>系统信息 - 星星NB管理系统</title>
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

        /* 复用基础布局样式 */
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

        .btn-secondary {
            background: var(--gray-100);
            color: var(--gray-700);
        }

        .btn-secondary:hover {
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

        /* 信息网格 */
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 1.5rem;
        }

        .info-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 0.75rem 0;
            border-bottom: 1px solid var(--gray-200);
        }

        .info-item:last-child {
            border-bottom: none;
        }

        .info-label {
            font-weight: 500;
            color: var(--gray-700);
        }

        .info-value {
            color: var(--gray-900);
            font-family: 'Consolas', 'Monaco', monospace;
            background: var(--gray-100);
            padding: 0.25rem 0.5rem;
            border-radius: 0.25rem;
            font-size: 0.875rem;
        }

        /* 进度条 */
        .progress-bar {
            width: 100%;
            height: 1rem;
            background: var(--gray-200);
            border-radius: 0.5rem;
            overflow: hidden;
            margin-top: 0.5rem;
        }

        .progress-fill {
            height: 100%;
            background: linear-gradient(135deg, var(--primary-blue), var(--dark-blue));
            border-radius: 0.5rem;
            transition: width 0.3s ease;
        }

        .progress-fill.warning {
            background: linear-gradient(135deg, #f59e0b, #d97706);
        }

        .progress-fill.danger {
            background: linear-gradient(135deg, #dc2626, #b91c1c);
        }

        /* 状态指示器 */
        .status-indicator {
            display: inline-flex;
            align-items: center;
            gap: 0.25rem;
            padding: 0.25rem 0.75rem;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 500;
        }

        .status-indicator.success {
            background: #dcfce7;
            color: #059669;
        }

        .status-indicator.error {
            background: #fef2f2;
            color: #dc2626;
        }

        .status-indicator.warning {
            background: #fef3c7;
            color: #d97706;
        }

        /* 扩展网格 */
        .extensions-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
        }

        .extension-category {
            background: var(--gray-50);
            border-radius: 0.5rem;
            padding: 1rem;
        }

        .extension-category-title {
            font-weight: 600;
            color: var(--gray-900);
            margin-bottom: 0.5rem;
            text-transform: uppercase;
            font-size: 0.875rem;
            letter-spacing: 0.05em;
        }

        .extension-list {
            display: flex;
            flex-wrap: wrap;
            gap: 0.25rem;
        }

        .extension-item {
            background: var(--white);
            color: var(--gray-700);
            padding: 0.25rem 0.5rem;
            border-radius: 0.25rem;
            font-size: 0.75rem;
            border: 1px solid var(--gray-200);
        }

        /* 磁盘使用图表 */
        .disk-usage {
            margin-bottom: 1rem;
        }

        .disk-path {
            font-size: 0.875rem;
            color: var(--gray-600);
            margin-bottom: 0.25rem;
        }

        .disk-stats {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-top: 0.5rem;
            font-size: 0.875rem;
            color: var(--gray-600);
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

            .info-grid {
                grid-template-columns: 1fr;
            }

            .extensions-grid {
                grid-template-columns: 1fr;
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

            .info-item {
                flex-direction: column;
                align-items: flex-start;
                gap: 0.5rem;
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
                    <a href="backup.php" class="nav-item">
                        <i class="fas fa-database"></i>
                        数据备份
                    </a>
                    <a href="cache.php" class="nav-item">
                        <i class="fas fa-broom"></i>
                        清理缓存
                    </a>
                    <a href="system_info.php" class="nav-item active">
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
                    <h1 class="header-title">系统信息</h1>
                </div>
                <div class="header-actions">
                    <button onclick="location.reload()" class="btn btn-secondary">
                        <i class="fas fa-sync-alt"></i>
                        刷新信息
                    </button>
                    <a href="index.php" class="back-btn">
                        <i class="fas fa-arrow-left"></i>
                        返回控制台
                    </a>
                </div>
            </header>

            <!-- 内容区域 -->
            <main class="content-area">
                <!-- PHP信息 -->
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fab fa-php"></i>
                            PHP 环境信息
                        </h2>
                        <span class="status-indicator success">
                            <i class="fas fa-check"></i>
                            PHP <?php echo $system_info['php']['version']; ?>
                        </span>
                    </div>
                    <div class="card-body">
                        <div class="info-grid">
                            <div>
                                <div class="info-item">
                                    <span class="info-label">PHP版本</span>
                                    <span class="info-value"><?php echo $system_info['php']['version']; ?></span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">运行方式</span>
                                    <span class="info-value"><?php echo $system_info['php']['sapi']; ?></span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">内存限制</span>
                                    <span class="info-value"><?php echo formatMemoryLimit($system_info['php']['memory_limit']); ?></span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">执行时间限制</span>
                                    <span class="info-value"><?php echo $system_info['php']['max_execution_time']; ?>秒</span>
                                </div>
                            </div>
                            <div>
                                <div class="info-item">
                                    <span class="info-label">上传文件大小限制</span>
                                    <span class="info-value"><?php echo $system_info['php']['upload_max_filesize']; ?></span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">POST大小限制</span>
                                    <span class="info-value"><?php echo $system_info['php']['post_max_size']; ?></span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">时区设置</span>
                                    <span class="info-value"><?php echo $system_info['php']['date_timezone']; ?></span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">已加载扩展数</span>
                                    <span class="info-value"><?php echo $system_info['php']['extensions_count']; ?> 个</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- 服务器信息 -->
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fas fa-server"></i>
                            服务器环境信息
                        </h2>
                        <span class="status-indicator <?php echo $system_info['server']['https'] ? 'success' : 'warning'; ?>">
                            <i class="fas fa-<?php echo $system_info['server']['https'] ? 'lock' : 'unlock'; ?>"></i>
                            <?php echo $system_info['server']['https'] ? 'HTTPS' : 'HTTP'; ?>
                        </span>
                    </div>
                    <div class="card-body">
                        <div class="info-grid">
                            <div>
                                <div class="info-item">
                                    <span class="info-label">服务器软件</span>
                                    <span class="info-value"><?php echo $system_info['server']['software']; ?></span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">操作系统</span>
                                    <span class="info-value"><?php echo $system_info['server']['os']; ?></span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">主机名</span>
                                    <span class="info-value"><?php echo $system_info['server']['hostname']; ?></span>
                                </div>
                            </div>
                            <div>
                                <div class="info-item">
                                    <span class="info-label">服务器端口</span>
                                    <span class="info-value"><?php echo $system_info['server']['server_port']; ?></span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">文档根目录</span>
                                    <span class="info-value"><?php echo $system_info['server']['document_root']; ?></span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">服务器管理员</span>
                                    <span class="info-value"><?php echo $system_info['server']['server_admin']; ?></span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- 数据库信息 -->
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fas fa-database"></i>
                            数据库信息
                        </h2>
                        <span class="status-indicator <?php echo $database_info['connected'] ? 'success' : 'error'; ?>">
                            <i class="fas fa-<?php echo $database_info['connected'] ? 'check' : 'times'; ?>"></i>
                            <?php echo $database_info['connected'] ? '已连接' : '连接失败'; ?>
                        </span>
                    </div>
                    <div class="card-body">
                        <?php if ($database_info['connected']): ?>
                        <div class="info-grid">
                            <div>
                                <div class="info-item">
                                    <span class="info-label">数据库版本</span>
                                    <span class="info-value"><?php echo $database_info['version']; ?></span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">主机地址</span>
                                    <span class="info-value"><?php echo $database_info['host']; ?>:<?php echo $database_info['port']; ?></span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">数据库名</span>
                                    <span class="info-value"><?php echo $database_info['database']; ?></span>
                                </div>
                            </div>
                            <div>
                                <div class="info-item">
                                    <span class="info-label">字符集</span>
                                    <span class="info-value"><?php echo $database_info['charset']; ?></span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">数据库大小</span>
                                    <span class="info-value"><?php echo formatBytes($database_info['size']); ?></span>
                                </div>
                                <div class="info-item">
                                    <span class="info-label">表数量</span>
                                    <span class="info-value"><?php echo $database_info['table_count']; ?> 个</span>
                                </div>
                            </div>
                        </div>
                        <?php else: ?>
                        <div style="color: #dc2626; text-align: center; padding: 2rem;">
                            <i class="fas fa-exclamation-triangle" style="font-size: 2rem; margin-bottom: 1rem;"></i>
                            <p>数据库连接失败</p>
                            <p style="font-size: 0.875rem; margin-top: 0.5rem;"><?php echo $database_info['error'] ?? '未知错误'; ?></p>
                        </div>
                        <?php endif; ?>
                    </div>
                </div>

                <!-- 内存使用情况 -->
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fas fa-memory"></i>
                            内存使用情况
                        </h2>
                    </div>
                    <div class="card-body">
                        <div class="info-item">
                            <span class="info-label">当前使用</span>
                            <span class="info-value"><?php echo formatBytes($system_info['memory']['current_usage']); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">峰值使用</span>
                            <span class="info-value"><?php echo formatBytes($system_info['memory']['peak_usage']); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">内存限制</span>
                            <span class="info-value"><?php echo formatMemoryLimit($system_info['memory']['limit']); ?></span>
                        </div>
                    </div>
                </div>

                <!-- 磁盘空间 -->
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fas fa-hdd"></i>
                            磁盘空间使用情况
                        </h2>
                    </div>
                    <div class="card-body">
                        <?php foreach ($system_info['disk'] as $name => $disk): ?>
                        <div class="disk-usage">
                            <div style="display: flex; justify-content: space-between; align-items: center;">
                                <strong><?php echo ucfirst($name); ?></strong>
                                <span><?php echo isset($disk['usage_percent']) ? $disk['usage_percent'] . '%' : 'N/A'; ?></span>
                            </div>
                            <div class="disk-path"><?php echo $disk['path']; ?></div>
                            <?php if (isset($disk['usage_percent'])): ?>
                            <div class="progress-bar">
                                <div class="progress-fill <?php 
                                    if ($disk['usage_percent'] > 90) echo 'danger';
                                    elseif ($disk['usage_percent'] > 75) echo 'warning';
                                ?>" style="width: <?php echo $disk['usage_percent']; ?>%"></div>
                            </div>
                            <div class="disk-stats">
                                <span>已用: <?php echo formatBytes($disk['used']); ?></span>
                                <span>可用: <?php echo formatBytes($disk['free']); ?></span>
                                <span>总计: <?php echo formatBytes($disk['total']); ?></span>
                            </div>
                            <?php endif; ?>
                        </div>
                        <?php endforeach; ?>
                    </div>
                </div>

                <!-- 系统负载 -->
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fas fa-tachometer-alt"></i>
                            系统负载
                        </h2>
                    </div>
                    <div class="card-body">
                        <div class="info-grid">
                            <div class="info-item">
                                <span class="info-label">1分钟负载</span>
                                <span class="info-value"><?php echo $system_info['system']['load_1min']; ?></span>
                            </div>
                            <div class="info-item">
                                <span class="info-label">5分钟负载</span>
                                <span class="info-value"><?php echo $system_info['system']['load_5min']; ?></span>
                            </div>
                            <div class="info-item">
                                <span class="info-label">15分钟负载</span>
                                <span class="info-value"><?php echo $system_info['system']['load_15min']; ?></span>
                            </div>
                        </div>
                        <?php if ($system_info['system']['load_1min'] === 'N/A'): ?>
                        <div style="text-align: center; color: var(--gray-600); margin-top: 1rem; font-style: italic;">
                            系统负载信息在Windows系统上不可用
                        </div>
                        <?php endif; ?>
                    </div>
                </div>

                <!-- PHP扩展 -->
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fas fa-puzzle-piece"></i>
                            PHP 扩展 (<?php echo array_sum(array_map('count', $php_extensions)); ?> 个)
                        </h2>
                    </div>
                    <div class="card-body">
                        <div class="extensions-grid">
                            <?php foreach ($php_extensions as $category => $extensions): ?>
                            <?php if (!empty($extensions)): ?>
                            <div class="extension-category">
                                <div class="extension-category-title">
                                    <?php echo ucfirst(str_replace('_', ' ', $category)); ?> (<?php echo count($extensions); ?>)
                                </div>
                                <div class="extension-list">
                                    <?php foreach ($extensions as $extension): ?>
                                    <span class="extension-item"><?php echo $extension; ?></span>
                                    <?php endforeach; ?>
                                </div>
                            </div>
                            <?php endif; ?>
                            <?php endforeach; ?>
                        </div>
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

        // 进度条动画
        document.addEventListener('DOMContentLoaded', function() {
            const progressFills = document.querySelectorAll('.progress-fill');
            const observer = new IntersectionObserver(function(entries) {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        const target = entry.target;
                        const width = target.style.width;
                        target.style.width = '0%';
                        setTimeout(() => {
                            target.style.width = width;
                        }, 100);
                        observer.unobserve(target);
                    }
                });
            });

            progressFills.forEach(fill => {
                observer.observe(fill);
            });
        });

        // 卡片动画
        document.addEventListener('DOMContentLoaded', function() {
            const cards = document.querySelectorAll('.card');
            const observer = new IntersectionObserver(function(entries) {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        entry.target.style.transform = 'translateY(0)';
                        entry.target.style.opacity = '1';
                    }
                });
            }, {
                threshold: 0.1,
                rootMargin: '0px 0px -50px 0px'
            });

            cards.forEach((card, index) => {
                card.style.transform = 'translateY(20px)';
                card.style.opacity = '0';
                card.style.transition = `transform 0.6s ease ${index * 0.1}s, opacity 0.6s ease ${index * 0.1}s`;
                observer.observe(card);
            });
        });
    </script>
</body>
</html>
