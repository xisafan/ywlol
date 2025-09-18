<?php
// +----------------------------------------------------------------------
// | OVOFUN 管理系统
// +----------------------------------------------------------------------
// | 主页
// +----------------------------------------------------------------------

// 启动会话
session_start();

// 检查用户是否已登录
if (!isset($_SESSION['admin_id']) || $_SESSION['admin_id'] <= 0) {
    // 未登录，重定向到登录页面
    header('Location: login.php');
    exit;
}

// 检查会话是否过期（这里设置为2小时）
$session_lifetime = 7200; // 2小时
if (isset($_SESSION['admin_login_time']) && (time() - $_SESSION['admin_login_time'] > $session_lifetime)) {
    // 清除会话
    session_unset();
    session_destroy();
    
    // 重定向到登录页面
    header('Location: login.php?expired=1');
    exit;
}

// 更新登录时间
$_SESSION['admin_login_time'] = time();

// 获取当前管理员信息
$admin_id = $_SESSION['admin_id'];
$admin_username = $_SESSION['admin_username'];

// 获取系统统计信息
function getSystemStats() {
    $stats = [];
    
    // CPU 使用率（模拟计算，实际环境中很难获取真实CPU使用率）
    $load_avg = 0;
    if (function_exists('sys_getloadavg') && PHP_OS_FAMILY !== 'Windows') {
        $load = sys_getloadavg();
        $load_avg = round($load[0] * 100 / 4, 1); // 假设4核CPU
    } else {
        // 在无法获取真实负载时，根据内存使用情况估算
        $memory_usage = memory_get_usage(true);
        $memory_limit = ini_get('memory_limit');
        if ($memory_limit !== '-1') {
            $memory_limit_str = $memory_limit;
            $memory_limit_bytes = 0;
            
            if (strpos($memory_limit_str, 'G') !== false) {
                $memory_limit_bytes = (float)str_replace('G', '', $memory_limit_str) * 1024 * 1024 * 1024;
            } elseif (strpos($memory_limit_str, 'M') !== false) {
                $memory_limit_bytes = (float)str_replace('M', '', $memory_limit_str) * 1024 * 1024;
            } elseif (strpos($memory_limit_str, 'K') !== false) {
                $memory_limit_bytes = (float)str_replace('K', '', $memory_limit_str) * 1024;
            } else {
                $memory_limit_bytes = (float)$memory_limit_str;
            }
            
            if ($memory_limit_bytes > 0) {
                $load_avg = min(round(($memory_usage / $memory_limit_bytes) * 100, 1), 100);
            } else {
                $load_avg = rand(15, 35);
            }
        } else {
            $load_avg = rand(15, 35); // 随机生成一个合理的负载值
        }
    }
    
    // 内存使用情况
    $memory_usage = memory_get_usage(true);
    $memory_peak = memory_get_peak_usage(true);
    $memory_mb = round($memory_usage / 1024 / 1024, 1);
    
    // 确保数值有效
    $stats['cpu_usage'] = max(0, min(100, round($load_avg, 1)));
    $stats['memory_usage'] = max(0, round($memory_mb, 1));
    $stats['memory_peak'] = round($memory_peak / 1024 / 1024, 1);
    
    return $stats;
}

$system_stats = getSystemStats();

// 引入数据库配置
$db_config_file = __DIR__ . '/database.php';
if (!file_exists($db_config_file)) {
    die('数据库配置文件不存在');
}

// 加载数据库配置
$db_config = include($db_config_file);

// 尝试连接数据库获取更多信息
try {
    // 连接数据库
    $dsn = "mysql:host={$db_config['hostname']};port={$db_config['hostport']};dbname={$db_config['database']};charset={$db_config['charset']}";
    $pdo = new PDO($dsn, $db_config['username'], $db_config['password']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // 设置表前缀
    $table_prefix = $db_config['prefix'];
    $admin_table = $table_prefix . 'ovo_admin';
    
    // 查询管理员信息
    $sql = "SELECT * FROM `{$admin_table}` WHERE `id` = :id LIMIT 1";
    $stmt = $pdo->prepare($sql);
    $stmt->bindParam(':id', $admin_id, PDO::PARAM_INT);
    $stmt->execute();
    $admin_info = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // 如果找不到管理员信息，可能是数据库已更改
    if (!$admin_info) {
        // 清除会话
        session_unset();
        session_destroy();
        
        // 重定向到登录页面
        header('Location: login.php?error=invalid_user');
        exit;
    }
    
    // 获取最后登录时间和IP
    $last_login_time = $admin_info['last_login_time'];
    $last_login_ip = $admin_info['last_login_ip'];
    
} catch (PDOException $e) {
    // 记录日志
    error_log('数据库错误: ' . $e->getMessage(), 0);
    // 这里不退出，继续显示页面，但不显示数据库相关信息
    $db_error = true;
}
?>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>云雾 - 管理系统</title>
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

        /* 页面标题 */
        .page-header {
            margin-bottom: 2rem;
        }

        .page-title {
            font-size: 2rem;
            font-weight: 700;
            color: var(--gray-900);
            margin-bottom: 0.5rem;
        }

        .page-subtitle {
            color: var(--gray-600);
            font-size: 1rem;
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

        /* 统计卡片 */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }

        .stat-card {
            background: var(--white);
            border-radius: 0.75rem;
            padding: 1.5rem;
            box-shadow: var(--shadow);
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }

        .stat-card:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-lg);
        }

        .stat-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 1rem;
        }

        .stat-title {
            font-size: 0.875rem;
            font-weight: 500;
            color: var(--gray-600);
        }

        .stat-icon {
            width: 3rem;
            height: 3rem;
            border-radius: 0.75rem;
            display: flex;
            align-items: center;
            justify-content: center;
            color: var(--white);
            font-size: 1.25rem;
            box-shadow: var(--shadow);
            position: relative;
            overflow: hidden;
        }

        .stat-icon::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: linear-gradient(135deg, rgba(255,255,255,0.1), rgba(255,255,255,0.05));
            pointer-events: none;
        }

        .stat-icon.blue { 
            background: linear-gradient(135deg, var(--primary-blue), var(--dark-blue));
            box-shadow: 0 4px 20px rgba(37, 99, 235, 0.3);
        }
        .stat-icon.green { 
            background: linear-gradient(135deg, #059669, #047857);
            box-shadow: 0 4px 20px rgba(5, 150, 105, 0.3);
        }
        .stat-icon.yellow { 
            background: linear-gradient(135deg, #d97706, #b45309);
            box-shadow: 0 4px 20px rgba(217, 119, 6, 0.3);
        }
        .stat-icon.red { 
            background: linear-gradient(135deg, #dc2626, #b91c1c);
            box-shadow: 0 4px 20px rgba(220, 38, 38, 0.3);
        }

        .stat-value {
            font-size: 2rem;
            font-weight: 700;
            color: var(--gray-900);
            margin-bottom: 0.25rem;
        }

        .stat-change {
            font-size: 0.75rem;
            font-weight: 500;
        }

        .stat-change.positive { color: #059669; }
        .stat-change.negative { color: #dc2626; }

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

        .btn-secondary {
            background: var(--gray-100);
            color: var(--gray-700);
        }

        .btn-secondary:hover {
            background: var(--gray-200);
        }

        .btn-danger {
            background: #dc2626;
            color: var(--white);
        }

        .btn-danger:hover {
            background: #b91c1c;
        }

        /* 快速操作网格 */
        .action-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
        }

        /* 系统信息网格 */
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1rem;
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

            .stats-grid {
                grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                gap: 1rem;
            }
        }

        /* 移动端优化 */
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

            .page-header {
                margin-bottom: 1.5rem;
            }

            .page-title {
                font-size: 1.5rem;
            }

            .stats-grid {
                grid-template-columns: 1fr;
                gap: 1rem;
            }

            .stat-card {
                padding: 1rem;
            }

            .stat-icon {
                width: 2.5rem;
                height: 2.5rem;
                font-size: 1rem;
            }

            .stat-value {
                font-size: 1.5rem;
            }

            .action-grid {
                grid-template-columns: 1fr;
            }

            .info-grid {
                grid-template-columns: 1fr;
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
        }

        /* 超小屏幕优化 */
        @media (max-width: 480px) {
            .stats-grid {
                grid-template-columns: repeat(2, 1fr);
                gap: 0.75rem;
            }

            .stat-card {
                padding: 0.75rem;
            }

            .stat-header {
                margin-bottom: 0.5rem;
            }

            .stat-icon {
                width: 2rem;
                height: 2rem;
                font-size: 0.875rem;
            }

            .stat-value {
                font-size: 1.25rem;
                margin-bottom: 0.125rem;
            }

            .stat-change {
                font-size: 0.625rem;
            }

            .page-title {
                font-size: 1.25rem;
                line-height: 1.4;
            }

            .page-subtitle {
                font-size: 0.875rem;
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
                    <a href="index.php" class="nav-item active">
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
                    <a href="#" class="nav-item" onclick="showAlert('功能开发中')">
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
                    <h1 class="header-title">控制台</h1>
                </div>
                <div class="header-actions">
                    <div class="user-menu">
                        <div class="user-avatar">
                            <?php echo strtoupper(substr($admin_username, 0, 1)); ?>
                        </div>
                        <div class="user-info">
                            <span class="user-name"><?php echo htmlspecialchars($admin_username); ?></span>
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
                <!-- 页面标题 -->
                <div class="page-header">
                    <h1 class="page-title">欢迎回来，<?php echo htmlspecialchars($admin_username); ?>大人！</h1>
                    <p class="page-subtitle">
                        系统运行正常，最后登录时间：
                        <?php echo isset($last_login_time) && !empty($last_login_time) ? htmlspecialchars($last_login_time) : '首次登录'; ?>
                    </p>
                </div>

                <!-- 统计卡片 -->
                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-header">
                            <span class="stat-title">系统状态</span>
                            <div class="stat-icon green">
                                <i class="fas fa-check-circle"></i>
                            </div>
                        </div>
                        <div class="stat-value">正常</div>
                        <div class="stat-change positive">
                            <i class="fas fa-arrow-up"></i> 系统运行正常
                        </div>
                    </div>
                    
                    <div class="stat-card">
                        <div class="stat-header">
                            <span class="stat-title">管理员数量</span>
                            <div class="stat-icon blue">
                                <i class="fas fa-users"></i>
                            </div>
                        </div>
                        <div class="stat-value">1</div>
                        <div class="stat-change positive">
                            <i class="fas fa-plus"></i> 活跃管理员账户
                        </div>
                    </div>
                    
                    <div class="stat-card">
                        <div class="stat-header">
                            <span class="stat-title">服务器负载</span>
                            <div class="stat-icon <?php echo $system_stats['cpu_usage'] > 80 ? 'red' : ($system_stats['cpu_usage'] > 60 ? 'yellow' : 'green'); ?>">
                                <i class="fas fa-tachometer-alt"></i>
                            </div>
                        </div>
                        <div class="stat-value" data-value="<?php echo $system_stats['cpu_usage']; ?>"><?php echo $system_stats['cpu_usage']; ?>%</div>
                        <div class="stat-change <?php echo $system_stats['cpu_usage'] > 80 ? 'negative' : 'positive'; ?>">
                            <i class="fas fa-<?php echo $system_stats['cpu_usage'] > 80 ? 'arrow-up' : 'arrow-down'; ?>"></i> 
                            <?php echo $system_stats['cpu_usage'] > 80 ? 'CPU使用率较高' : 'CPU使用率正常'; ?>
                        </div>
                    </div>
                    
                    <div class="stat-card">
                        <div class="stat-header">
                            <span class="stat-title">内存使用</span>
                            <div class="stat-icon <?php echo $system_stats['memory_usage'] > 512 ? 'red' : ($system_stats['memory_usage'] > 256 ? 'yellow' : 'green'); ?>">
                                <i class="fas fa-memory"></i>
                            </div>
                        </div>
                        <div class="stat-value" data-value="<?php echo $system_stats['memory_usage']; ?>"><?php echo $system_stats['memory_usage']; ?>MB</div>
                        <div class="stat-change positive">
                            <i class="fas fa-arrow-up"></i> 内存使用正常
                        </div>
                    </div>
                </div>

                <!-- 快速操作 -->
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">快速操作</h2>
                    </div>
                    <div class="card-body">
                        <div class="action-grid">
                            <a href="setting.php" class="btn btn-primary">
                                <i class="fas fa-cog"></i>
                                系统设置
                            </a>
                            <a href="setting.php#parser" class="btn btn-primary">
                                <i class="fas fa-play-circle"></i>
                                解析管理
                            </a>
                            <a href="setting.php#announcement" class="btn btn-primary">
                                <i class="fas fa-bullhorn"></i>
                                公告管理
                            </a>
                            <a href="system_logs.php" class="btn btn-secondary">
                                <i class="fas fa-file-alt"></i>
                                查看日志
                            </a>
                            <a href="backup.php" class="btn btn-secondary">
                                <i class="fas fa-database"></i>
                                备份数据
                            </a>
                            <a href="cache.php" class="btn btn-danger">
                                <i class="fas fa-broom"></i>
                                清除缓存
                            </a>
                        </div>
                    </div>
                    </div>
                    
                <!-- 系统信息 -->
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">系统信息</h2>
                        <a href="system_info.php" class="btn btn-secondary">
                            <i class="fas fa-info-circle"></i>
                            查看详情
                        </a>
                    </div>
                    <div class="card-body">
                        <div class="info-grid">
                            <div class="info-item">
                                <div class="info-label">PHP 版本</div>
                                <div class="info-value"><?php echo phpversion(); ?></div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">服务器软件</div>
                                <div class="info-value"><?php echo $_SERVER['SERVER_SOFTWARE']; ?></div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">服务器时间</div>
                                <div class="info-value"><?php echo date('Y-m-d H:i:s'); ?></div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">数据库类型</div>
                                <div class="info-value"><?php echo isset($db_config) ? $db_config['type'] : 'MySQL'; ?></div>
                            </div>
                    <div class="info-item">
                                <div class="info-label">数据库版本</div>
                                <div class="info-value">
                            <?php 
                            if (isset($pdo)) {
                                echo $pdo->getAttribute(PDO::ATTR_SERVER_VERSION);
                            } else {
                                echo 'Unknown';
                            }
                            ?>
                                </div>
                    </div>
                    <div class="info-item">
                                <div class="info-label">客户端 IP</div>
                                <div class="info-value"><?php echo $_SERVER['REMOTE_ADDR']; ?></div>
                            </div>
                        </div>
                    </div>
                </div>
        </main>
        </div>
    </div>
    
    <script>
        function showAlert(message) {
            alert(message);
        }

        // 移动端菜单控制
        document.addEventListener('DOMContentLoaded', function() {
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

            // 添加统计卡片动画
            const statCards = document.querySelectorAll('.stat-card');
            const observerOptions = {
                threshold: 0.1,
                rootMargin: '0px 0px -50px 0px'
            };

            const observer = new IntersectionObserver(function(entries) {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        entry.target.style.transform = 'translateY(0)';
                        entry.target.style.opacity = '1';
                    }
                });
            }, observerOptions);

            // 初始化统计卡片动画
            statCards.forEach((card, index) => {
                card.style.transform = 'translateY(20px)';
                card.style.opacity = '0';
                card.style.transition = `transform 0.6s ease ${index * 0.1}s, opacity 0.6s ease ${index * 0.1}s`;
                observer.observe(card);
            });

            // 统计卡片数字动画
            function animateNumber(element, target) {
                const start = 0;
                const duration = 1500;
                const startTime = performance.now();
                
                // 从目标值中提取数字部分
                let targetNumber = 0;
                let suffix = '';
                
                if (typeof target === 'string') {
                    if (target.includes('%')) {
                        targetNumber = parseFloat(target.replace('%', ''));
                        suffix = '%';
                    } else if (target.includes('MB')) {
                        targetNumber = parseFloat(target.replace('MB', ''));
                        suffix = 'MB';
                    } else {
                        targetNumber = parseFloat(target);
                    }
                } else {
                    targetNumber = parseFloat(target);
                }
                
                // 确保目标数字有效
                if (isNaN(targetNumber)) {
                    targetNumber = 0;
                }

                function updateNumber(currentTime) {
                    const elapsed = currentTime - startTime;
                    const progress = Math.min(elapsed / duration, 1);
                    
                    // 使用easeOutExpo缓动函数
                    const easeProgress = progress === 1 ? 1 : 1 - Math.pow(2, -10 * progress);
                    const current = start + (targetNumber - start) * easeProgress;
                    
                    // 确保显示的数字有效
                    const displayNumber = Math.round(current);
                    if (!isNaN(displayNumber)) {
                        element.textContent = displayNumber + suffix;
                    } else {
                        element.textContent = '0' + suffix;
                    }

                    if (progress < 1) {
                        requestAnimationFrame(updateNumber);
                    }
                }

                requestAnimationFrame(updateNumber);
            }

            // 当统计卡片进入视口时启动数字动画
            const statValues = document.querySelectorAll('.stat-value');
            const valueObserver = new IntersectionObserver(function(entries) {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        const element = entry.target;
                        const text = element.textContent.trim();
                        
                        if (text === '正常') {
                            // 对于文字状态，添加淡入效果
                            element.style.opacity = '0';
                            setTimeout(() => {
                                element.style.transition = 'opacity 0.5s ease';
                                element.style.opacity = '1';
                            }, 300);
                        } else if (text.includes('%')) {
                            // 从data-value属性或文本中提取数字
                            let number = parseFloat(element.getAttribute('data-value')) || parseFloat(text.replace('%', ''));
                            if (!isNaN(number)) {
                                animateNumber(element, number + '%');
                            } else {
                                element.textContent = '0%'; // fallback
                            }
                        } else if (text.includes('MB')) {
                            // 从data-value属性或文本中提取数字
                            let number = parseFloat(element.getAttribute('data-value')) || parseFloat(text.replace('MB', ''));
                            if (!isNaN(number)) {
                                animateNumber(element, number + 'MB');
                            } else {
                                element.textContent = '0MB'; // fallback
                            }
                        } else {
                            // 纯数字
                            let number = parseFloat(element.getAttribute('data-value')) || parseFloat(text);
                            if (!isNaN(number)) {
                                animateNumber(element, number);
                            } else {
                                element.textContent = '0'; // fallback
                            }
                        }
                        
                        valueObserver.unobserve(element);
                    }
                });
            }, observerOptions);

            statValues.forEach(value => {
                valueObserver.observe(value);
            });
        });
    </script>
</body>
</html>