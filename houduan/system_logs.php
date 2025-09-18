<?php
// +----------------------------------------------------------------------
// | 星星NB 管理系统
// +----------------------------------------------------------------------
// | 系统日志查看
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

// 日志文件路径（处理 open_basedir 限制）
$log_files = [];

// 安全添加日志文件路径
$potential_log_files = [
    'php_error' => ini_get('error_log') ?: sys_get_temp_dir() . '/php_error.log',
    'access' => $_SERVER['DOCUMENT_ROOT'] . '/access.log',
    'apache_error' => '/var/log/apache2/error.log',
    'nginx_error' => '/var/log/nginx/error.log',
    'system' => '/var/log/syslog'
];

// 只添加可以访问的日志文件路径
foreach ($potential_log_files as $type => $path) {
    try {
        // 检查文件是否在允许的路径内
        if (@file_exists($path) || @is_dir(dirname($path))) {
            $log_files[$type] = $path;
        } elseif ($type === 'php_error') {
            // PHP错误日志必须存在，使用临时目录作为备选
            $log_files[$type] = sys_get_temp_dir() . '/php_error.log';
        }
    } catch (Exception $e) {
        // 忽略因 open_basedir 限制导致的错误
        if ($type === 'php_error') {
            $log_files[$type] = sys_get_temp_dir() . '/php_error.log';
        }
        continue;
    }
}

// 处理操作
$action = isset($_GET['action']) ? $_GET['action'] : '';
$log_type = isset($_GET['type']) ? $_GET['type'] : 'php_error';
$lines = isset($_GET['lines']) ? max(10, min(1000, intval($_GET['lines']))) : 100;

// 读取日志内容
function readLogFile($file_path, $lines = 100) {
    if (!file_exists($file_path) || !is_readable($file_path)) {
        return "日志文件不存在或无法读取: $file_path";
    }
    
    // 使用tail命令读取最后N行（如果在Unix系统上）
    if (function_exists('exec') && stripos(PHP_OS, 'WIN') === false) {
        $output = [];
        exec("tail -n $lines " . escapeshellarg($file_path), $output);
        return implode("\n", $output);
    }
    
    // Windows或无exec权限时的备用方法
    $file = file($file_path);
    if ($file === false) {
        return "无法读取日志文件";
    }
    
    $file = array_slice($file, -$lines);
    return implode('', $file);
}

// 清空日志文件
if ($action === 'clear' && isset($_GET['type'])) {
    $log_file = $log_files[$log_type] ?? '';
    if ($log_file && file_exists($log_file) && is_writable($log_file)) {
        file_put_contents($log_file, '');
        $success_message = "日志文件已清空";
    } else {
        $error_message = "无法清空日志文件，请检查权限";
    }
}

// 获取日志内容
$log_content = '';
if (isset($log_files[$log_type])) {
    $log_content = readLogFile($log_files[$log_type], $lines);
}

// 获取日志文件信息
function getLogFileInfo($file_path) {
    if (!file_exists($file_path)) {
        return ['exists' => false, 'size' => 0, 'modified' => 'N/A'];
    }
    
    return [
        'exists' => true,
        'size' => filesize($file_path),
        'modified' => date('Y-m-d H:i:s', filemtime($file_path)),
        'readable' => is_readable($file_path),
        'writable' => is_writable($file_path)
    ];
}
?>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>系统日志 - 星星NB管理系统</title>
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

        /* 日志控制面板 */
        .log-controls {
            display: flex;
            flex-wrap: wrap;
            gap: 1rem;
            margin-bottom: 1.5rem;
            padding: 1rem;
            background: var(--gray-50);
            border-radius: 0.5rem;
        }

        .log-control-group {
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
        }

        .log-control-label {
            font-size: 0.875rem;
            font-weight: 500;
            color: var(--gray-700);
        }

        .form-select {
            padding: 0.5rem 0.75rem;
            border: 1px solid var(--gray-300);
            border-radius: 0.375rem;
            background: var(--white);
            font-size: 0.875rem;
        }

        /* 日志内容显示 */
        .log-content {
            background: #1e1e1e;
            color: #d4d4d4;
            font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
            font-size: 0.875rem;
            line-height: 1.6;
            padding: 1.5rem;
            border-radius: 0.5rem;
            max-height: 600px;
            overflow-y: auto;
            white-space: pre-wrap;
            word-break: break-all;
        }

        .log-content:empty::before {
            content: "暂无日志内容";
            color: var(--gray-600);
            font-style: italic;
        }

        /* 日志文件信息 */
        .log-info {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin-bottom: 1.5rem;
        }

        .info-item {
            padding: 1rem;
            background: var(--gray-50);
            border-radius: 0.5rem;
            border: 1px solid var(--gray-200);
        }

        .info-label {
            font-size: 0.75rem;
            font-weight: 500;
            color: var(--gray-600);
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-bottom: 0.25rem;
        }

        .info-value {
            font-size: 0.875rem;
            font-weight: 600;
            color: var(--gray-900);
        }

        /* 状态指示器 */
        .status-indicator {
            display: inline-flex;
            align-items: center;
            gap: 0.25rem;
            font-size: 0.875rem;
        }

        .status-indicator.success { color: #059669; }
        .status-indicator.error { color: #dc2626; }
        .status-indicator.warning { color: #d97706; }

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

            .log-controls {
                flex-direction: column;
            }

            .log-info {
                grid-template-columns: 1fr;
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
                    <a href="system_logs.php" class="nav-item active">
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
                    <button class="mobile-menu-btn" id="mobileMenuBtn">
                        <i class="fas fa-bars"></i>
                    </button>
                    <h1 class="header-title">系统日志</h1>
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
                <?php if (isset($success_message)): ?>
                <div class="alert alert-success">
                    <i class="fas fa-check-circle"></i>
                    <?php echo htmlspecialchars($success_message); ?>
                </div>
                <?php endif; ?>
                
                <?php if (isset($error_message)): ?>
                <div class="alert alert-error">
                    <i class="fas fa-exclamation-circle"></i>
                    <?php echo htmlspecialchars($error_message); ?>
                </div>
                <?php endif; ?>

                <!-- 日志文件信息 -->
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fas fa-info-circle"></i>
                            日志文件信息
                        </h2>
                    </div>
                    <div class="card-body">
                        <div class="log-info">
                            <?php 
                            $current_file_info = getLogFileInfo($log_files[$log_type]);
                            ?>
                            <div class="info-item">
                                <div class="info-label">文件路径</div>
                                <div class="info-value"><?php echo htmlspecialchars($log_files[$log_type]); ?></div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">文件状态</div>
                                <div class="info-value">
                                    <?php if ($current_file_info['exists']): ?>
                                    <span class="status-indicator success">
                                        <i class="fas fa-check-circle"></i>
                                        存在
                                    </span>
                                    <?php else: ?>
                                    <span class="status-indicator error">
                                        <i class="fas fa-times-circle"></i>
                                        不存在
                                    </span>
                                    <?php endif; ?>
                                </div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">文件大小</div>
                                <div class="info-value">
                                    <?php 
                                    if ($current_file_info['exists']) {
                                        $size = $current_file_info['size'];
                                        if ($size > 1024 * 1024) {
                                            echo number_format($size / (1024 * 1024), 2) . ' MB';
                                        } elseif ($size > 1024) {
                                            echo number_format($size / 1024, 2) . ' KB';
                                        } else {
                                            echo $size . ' bytes';
                                        }
                                    } else {
                                        echo 'N/A';
                                    }
                                    ?>
                                </div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">最后修改</div>
                                <div class="info-value"><?php echo $current_file_info['modified']; ?></div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">权限</div>
                                <div class="info-value">
                                    <?php if ($current_file_info['exists']): ?>
                                    <span class="status-indicator <?php echo $current_file_info['readable'] ? 'success' : 'error'; ?>">
                                        <i class="fas fa-eye"></i>
                                        <?php echo $current_file_info['readable'] ? '可读' : '不可读'; ?>
                                    </span>
                                    <span class="status-indicator <?php echo $current_file_info['writable'] ? 'success' : 'error'; ?>">
                                        <i class="fas fa-edit"></i>
                                        <?php echo $current_file_info['writable'] ? '可写' : '只读'; ?>
                                    </span>
                                    <?php else: ?>
                                    N/A
                                    <?php endif; ?>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- 日志控制面板 -->
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fas fa-sliders-h"></i>
                            日志控制面板
                        </h2>
                        <div>
                            <?php if ($current_file_info['exists'] && $current_file_info['writable']): ?>
                            <a href="?action=clear&type=<?php echo urlencode($log_type); ?>" 
                               class="btn btn-danger" 
                               onclick="return confirm('确定要清空日志文件吗？此操作不可逆！')">
                                <i class="fas fa-trash"></i>
                                清空日志
                            </a>
                            <?php endif; ?>
                            <button onclick="refreshLog()" class="btn btn-primary">
                                <i class="fas fa-sync-alt"></i>
                                刷新
                            </button>
                        </div>
                    </div>
                    <div class="card-body">
                        <form method="GET" id="logForm">
                            <div class="log-controls">
                                <div class="log-control-group">
                                    <label class="log-control-label">日志类型</label>
                                    <select name="type" class="form-select" onchange="document.getElementById('logForm').submit()">
                                        <option value="php_error" <?php echo $log_type === 'php_error' ? 'selected' : ''; ?>>PHP错误日志</option>
                                        <option value="access" <?php echo $log_type === 'access' ? 'selected' : ''; ?>>访问日志</option>
                                        <option value="apache_error" <?php echo $log_type === 'apache_error' ? 'selected' : ''; ?>>Apache错误日志</option>
                                        <option value="nginx_error" <?php echo $log_type === 'nginx_error' ? 'selected' : ''; ?>>Nginx错误日志</option>
                                        <option value="system" <?php echo $log_type === 'system' ? 'selected' : ''; ?>>系统日志</option>
                                    </select>
                                </div>
                                <div class="log-control-group">
                                    <label class="log-control-label">显示行数</label>
                                    <select name="lines" class="form-select" onchange="document.getElementById('logForm').submit()">
                                        <option value="50" <?php echo $lines === 50 ? 'selected' : ''; ?>>50行</option>
                                        <option value="100" <?php echo $lines === 100 ? 'selected' : ''; ?>>100行</option>
                                        <option value="200" <?php echo $lines === 200 ? 'selected' : ''; ?>>200行</option>
                                        <option value="500" <?php echo $lines === 500 ? 'selected' : ''; ?>>500行</option>
                                        <option value="1000" <?php echo $lines === 1000 ? 'selected' : ''; ?>>1000行</option>
                                    </select>
                                </div>
                            </div>
                        </form>
                    </div>
                </div>

                <!-- 日志内容 -->
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fas fa-file-alt"></i>
                            日志内容 (最近 <?php echo $lines; ?> 行)
                        </h2>
                        <div>
                            <button onclick="downloadLog()" class="btn btn-secondary">
                                <i class="fas fa-download"></i>
                                下载日志
                            </button>
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="log-content" id="logContent"><?php echo htmlspecialchars($log_content); ?></div>
                    </div>
                </div>
            </main>
        </div>
    </div>

    <script>
        // 移动端菜单控制
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

        // 刷新日志
        function refreshLog() {
            window.location.reload();
        }

        // 下载日志
        function downloadLog() {
            const logContent = document.getElementById('logContent').textContent;
            const blob = new Blob([logContent], { type: 'text/plain' });
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = '<?php echo $log_type; ?>_log_' + new Date().toISOString().slice(0, 19).replace(/:/g, '-') + '.txt';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            window.URL.revokeObjectURL(url);
        }

        // 自动滚动到日志底部
        document.addEventListener('DOMContentLoaded', function() {
            const logContent = document.getElementById('logContent');
            if (logContent) {
                logContent.scrollTop = logContent.scrollHeight;
            }
        });

        // 添加样式到head中（用于消息提示）
        const style = document.createElement('style');
        style.textContent = `
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
        `;
        document.head.appendChild(style);
    </script>
</body>
</html>
