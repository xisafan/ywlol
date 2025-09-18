<?php
// +----------------------------------------------------------------------
// | 星星NB 管理系统
// +----------------------------------------------------------------------
// | 缓存清理管理
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

// 初始化消息变量
$success_message = '';
$error_message = '';

// 处理操作
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = isset($_POST['action']) ? $_POST['action'] : '';
    
    switch ($action) {
        case 'clear_opcache':
            $result = clearOPCache();
            if ($result['success']) {
                $success_message = $result['message'];
            } else {
                $error_message = $result['message'];
            }
            break;
            
        case 'clear_sessions':
            $result = clearSessions();
            if ($result['success']) {
                $success_message = $result['message'];
            } else {
                $error_message = $result['message'];
            }
            break;
            
        case 'clear_temp_files':
            $result = clearTempFiles();
            if ($result['success']) {
                $success_message = $result['message'];
            } else {
                $error_message = $result['message'];
            }
            break;
            
        case 'clear_log_files':
            $result = clearOldLogFiles();
            if ($result['success']) {
                $success_message = $result['message'];
            } else {
                $error_message = $result['message'];
            }
            break;
            
        case 'clear_cache_files':
            $result = clearCacheFiles();
            if ($result['success']) {
                $success_message = $result['message'];
            } else {
                $error_message = $result['message'];
            }
            break;
            
        case 'clear_all':
            $results = [];
            $results[] = clearOPCache();
            $results[] = clearSessions();
            $results[] = clearTempFiles();
            $results[] = clearOldLogFiles();
            $results[] = clearCacheFiles();
            
            $success_count = 0;
            $total_size_freed = 0;
            foreach ($results as $result) {
                if ($result['success']) {
                    $success_count++;
                    $total_size_freed += $result['size_freed'] ?? 0;
                }
            }
            
            if ($success_count > 0) {
                $size_text = formatBytes($total_size_freed);
                $success_message = "已成功清理 {$success_count} 项缓存，释放空间：{$size_text}";
            } else {
                $error_message = "缓存清理失败";
            }
            break;
    }
}

// 清理OPCache
function clearOPCache() {
    if (function_exists('opcache_reset')) {
        if (opcache_reset()) {
            return ['success' => true, 'message' => 'OPCache 缓存已清理'];
        } else {
            return ['success' => false, 'message' => 'OPCache 清理失败'];
        }
    } else {
        return ['success' => false, 'message' => 'OPCache 未启用'];
    }
}

// 清理会话文件
function clearSessions() {
    $session_save_path = session_save_path() ?: sys_get_temp_dir();
    $files_deleted = 0;
    $size_freed = 0;
    
    try {
        if (@is_dir($session_save_path) && @is_readable($session_save_path)) {
            $files = @glob($session_save_path . '/sess_*');
            if ($files !== false) {
                foreach ($files as $file) {
                    if (@is_file($file) && @is_writable($file)) {
                        $file_size = @filesize($file);
                        if ($file_size !== false) {
                            $size_freed += $file_size;
                        }
                        if (@unlink($file)) {
                            $files_deleted++;
                        }
                    }
                }
            }
        }
        
        return [
            'success' => true, 
            'message' => "已删除 {$files_deleted} 个会话文件",
            'size_freed' => $size_freed
        ];
        
    } catch (Exception $e) {
        return ['success' => false, 'message' => '会话清理失败: ' . $e->getMessage()];
    }
}

// 清理临时文件
function clearTempFiles() {
    $temp_dirs = [
        sys_get_temp_dir(),
        __DIR__ . '/temp',
        __DIR__ . '/tmp',
        __DIR__ . '/../temp',
        __DIR__ . '/../tmp'
    ];
    
    $files_deleted = 0;
    $size_freed = 0;
    
    try {
        foreach ($temp_dirs as $dir) {
            if (@is_dir($dir) && @is_readable($dir)) {
                $files = @glob($dir . '/*');
                if ($files !== false) {
                    foreach ($files as $file) {
                        if (@is_file($file) && @is_writable($file)) {
                            $file_time = @filemtime($file);
                            // 只删除超过1小时的临时文件
                            if ($file_time !== false && time() - $file_time > 3600) {
                                $file_size = @filesize($file);
                                if ($file_size !== false) {
                                    $size_freed += $file_size;
                                }
                                if (@unlink($file)) {
                                    $files_deleted++;
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return [
            'success' => true, 
            'message' => "已删除 {$files_deleted} 个临时文件",
            'size_freed' => $size_freed
        ];
        
    } catch (Exception $e) {
        return ['success' => false, 'message' => '临时文件清理失败: ' . $e->getMessage()];
    }
}

// 清理旧日志文件
function clearOldLogFiles() {
    $log_dirs = [
        __DIR__ . '/logs',
        __DIR__ . '/../logs'
    ];
    
    $files_deleted = 0;
    $size_freed = 0;
    
    try {
        foreach ($log_dirs as $dir) {
            if (is_dir($dir)) {
                $files = glob($dir . '/*.log.*');
                foreach ($files as $file) {
                    if (is_file($file)) {
                        // 删除超过7天的日志文件
                        if (time() - filemtime($file) > 7 * 24 * 3600) {
                            $size_freed += filesize($file);
                            if (unlink($file)) {
                                $files_deleted++;
                            }
                        }
                    }
                }
            }
        }
        
        return [
            'success' => true, 
            'message' => "已删除 {$files_deleted} 个旧日志文件",
            'size_freed' => $size_freed
        ];
        
    } catch (Exception $e) {
        return ['success' => false, 'message' => '日志文件清理失败: ' . $e->getMessage()];
    }
}

// 清理缓存文件
function clearCacheFiles() {
    $cache_dirs = [
        __DIR__ . '/cache',
        __DIR__ . '/../cache',
        __DIR__ . '/../storage/cache'
    ];
    
    $files_deleted = 0;
    $size_freed = 0;
    
    try {
        foreach ($cache_dirs as $dir) {
            if (is_dir($dir)) {
                $size_freed += deleteDirContents($dir, $files_deleted);
            }
        }
        
        return [
            'success' => true, 
            'message' => "已删除 {$files_deleted} 个缓存文件",
            'size_freed' => $size_freed
        ];
        
    } catch (Exception $e) {
        return ['success' => false, 'message' => '缓存文件清理失败: ' . $e->getMessage()];
    }
}

// 递归删除目录内容
function deleteDirContents($dir, &$files_deleted) {
    $size_freed = 0;
    
    if (is_dir($dir)) {
        $files = array_diff(scandir($dir), ['.', '..']);
        foreach ($files as $file) {
            $path = $dir . '/' . $file;
            if (is_dir($path)) {
                $size_freed += deleteDirContents($path, $files_deleted);
                rmdir($path);
            } else {
                $size_freed += filesize($path);
                unlink($path);
                $files_deleted++;
            }
        }
    }
    
    return $size_freed;
}

// 格式化字节大小
function formatBytes($size, $precision = 2) {
    $base = log($size, 1024);
    $suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    return round(pow(1024, $base - floor($base)), $precision) . ' ' . $suffixes[floor($base)];
}

// 获取缓存信息
function getCacheInfo() {
    $info = [];
    
    // OPCache信息
    if (function_exists('opcache_get_status')) {
        $opcache_status = opcache_get_status(false);
        $info['opcache'] = [
            'enabled' => $opcache_status !== false,
            'memory_usage' => $opcache_status ? $opcache_status['memory_usage']['used_memory'] : 0,
            'hit_rate' => $opcache_status ? round($opcache_status['opcache_statistics']['opcache_hit_rate'], 2) : 0
        ];
    } else {
        $info['opcache'] = ['enabled' => false, 'memory_usage' => 0, 'hit_rate' => 0];
    }
    
    // 会话文件信息
    $session_save_path = session_save_path() ?: sys_get_temp_dir();
    $session_files = @glob($session_save_path . '/sess_*');
    $session_size = 0;
    $session_count = 0;
    
    if ($session_files !== false) {
        foreach ($session_files as $file) {
            if (@is_file($file)) {
                $file_size = @filesize($file);
                if ($file_size !== false) {
                    $session_size += $file_size;
                }
                $session_count++;
            }
        }
    }
    
    $info['sessions'] = [
        'count' => $session_count,
        'size' => $session_size
    ];
    
    // 临时文件信息
    $temp_dirs = [sys_get_temp_dir(), __DIR__ . '/temp', __DIR__ . '/tmp'];
    $temp_size = 0;
    $temp_count = 0;
    
    foreach ($temp_dirs as $dir) {
        if (@is_dir($dir) && @is_readable($dir)) {
            $files = @glob($dir . '/*');
            if ($files !== false) {
                foreach ($files as $file) {
                    if (@is_file($file)) {
                        $file_size = @filesize($file);
                        if ($file_size !== false) {
                            $temp_size += $file_size;
                        }
                        $temp_count++;
                    }
                }
            }
        }
    }
    
    $info['temp_files'] = [
        'count' => $temp_count,
        'size' => $temp_size
    ];
    
    // 缓存文件信息
    $cache_dirs = [__DIR__ . '/cache', __DIR__ . '/../cache'];
    $cache_size = 0;
    $cache_count = 0;
    foreach ($cache_dirs as $dir) {
        if (is_dir($dir)) {
            $size_count = getDirSizeAndCount($dir);
            $cache_size += $size_count['size'];
            $cache_count += $size_count['count'];
        }
    }
    $info['cache_files'] = [
        'count' => $cache_count,
        'size' => $cache_size
    ];
    
    return $info;
}

// 获取目录大小和文件数量
function getDirSizeAndCount($dir) {
    $size = 0;
    $count = 0;
    
    if (is_dir($dir)) {
        $files = array_diff(scandir($dir), ['.', '..']);
        foreach ($files as $file) {
            $path = $dir . '/' . $file;
            if (is_dir($path)) {
                $subResult = getDirSizeAndCount($path);
                $size += $subResult['size'];
                $count += $subResult['count'];
            } else {
                $size += filesize($path);
                $count++;
            }
        }
    }
    
    return ['size' => $size, 'count' => $count];
}

$cache_info = getCacheInfo();
?>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>缓存清理 - 星星NB管理系统</title>
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

        .btn-success {
            background: #059669;
            color: var(--white);
        }

        .btn-success:hover {
            background: #047857;
        }

        /* 缓存信息卡片 */
        .cache-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }

        .cache-card {
            background: var(--white);
            border-radius: 0.75rem;
            box-shadow: var(--shadow);
            padding: 1.5rem;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }

        .cache-card:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-lg);
        }

        .cache-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 1rem;
        }

        .cache-icon {
            width: 3rem;
            height: 3rem;
            border-radius: 0.75rem;
            display: flex;
            align-items: center;
            justify-content: center;
            color: var(--white);
            font-size: 1.25rem;
        }

        .cache-icon.opcache {
            background: linear-gradient(135deg, #8b5cf6, #7c3aed);
        }

        .cache-icon.sessions {
            background: linear-gradient(135deg, #06b6d4, #0891b2);
        }

        .cache-icon.temp {
            background: linear-gradient(135deg, #f59e0b, #d97706);
        }

        .cache-icon.files {
            background: linear-gradient(135deg, #10b981, #059669);
        }

        .cache-info {
            flex: 1;
            margin-left: 1rem;
        }

        .cache-title {
            font-size: 1.1rem;
            font-weight: 600;
            color: var(--gray-900);
            margin-bottom: 0.25rem;
        }

        .cache-stats {
            font-size: 0.875rem;
            color: var(--gray-600);
            display: flex;
            flex-direction: column;
            gap: 0.25rem;
        }

        .cache-size {
            font-size: 1.5rem;
            font-weight: 700;
            color: var(--gray-900);
            margin: 0.5rem 0;
        }

        .cache-actions {
            margin-top: 1rem;
            display: flex;
            gap: 0.5rem;
        }

        /* 全局清理按钮 */
        .clear-all-section {
            text-align: center;
            padding: 2rem;
            background: var(--white);
            border-radius: 0.75rem;
            box-shadow: var(--shadow);
            margin-bottom: 2rem;
        }

        .clear-all-icon {
            width: 4rem;
            height: 4rem;
            background: linear-gradient(135deg, #dc2626, #b91c1c);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 1rem;
            color: var(--white);
            font-size: 1.5rem;
        }

        .clear-all-title {
            font-size: 1.5rem;
            font-weight: 700;
            color: var(--gray-900);
            margin-bottom: 0.5rem;
        }

        .clear-all-desc {
            color: var(--gray-600);
            margin-bottom: 1.5rem;
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

        /* 状态指示器 */
        .status-badge {
            display: inline-flex;
            align-items: center;
            gap: 0.25rem;
            padding: 0.25rem 0.75rem;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 500;
        }

        .status-badge.enabled {
            background: #dcfce7;
            color: #059669;
        }

        .status-badge.disabled {
            background: #fef2f2;
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

            .cache-grid {
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

            .cache-header {
                flex-direction: column;
                align-items: flex-start;
            }

            .cache-info {
                margin-left: 0;
                margin-top: 1rem;
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
                    <a href="cache.php" class="nav-item active">
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
                    <h1 class="header-title">缓存清理</h1>
                </div>
                <div class="header-actions">
                    <button onclick="location.reload()" class="btn btn-secondary">
                        <i class="fas fa-sync-alt"></i>
                        刷新状态
                    </button>
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

                <!-- 一键清理所有缓存 -->
                <div class="clear-all-section">
                    <div class="clear-all-icon">
                        <i class="fas fa-magic"></i>
                    </div>
                    <h2 class="clear-all-title">一键清理所有缓存</h2>
                    <p class="clear-all-desc">清理所有类型的缓存文件，释放服务器存储空间并提升性能</p>
                    <form method="POST" style="display: inline;">
                        <input type="hidden" name="action" value="clear_all">
                        <button type="submit" class="btn btn-danger" onclick="return confirm('确定要清理所有缓存吗？这将清除所有缓存数据。')">
                            <i class="fas fa-broom"></i>
                            立即清理所有缓存
                        </button>
                    </form>
                </div>

                <!-- 缓存信息卡片 -->
                <div class="cache-grid">
                    <!-- OPCache -->
                    <div class="cache-card">
                        <div class="cache-header">
                            <div class="cache-icon opcache">
                                <i class="fas fa-microchip"></i>
                            </div>
                            <div class="cache-info">
                                <h3 class="cache-title">OPCache 操作码缓存</h3>
                                <div class="cache-stats">
                                    <div>
                                        状态: 
                                        <span class="status-badge <?php echo $cache_info['opcache']['enabled'] ? 'enabled' : 'disabled'; ?>">
                                            <i class="fas fa-<?php echo $cache_info['opcache']['enabled'] ? 'check' : 'times'; ?>"></i>
                                            <?php echo $cache_info['opcache']['enabled'] ? '已启用' : '未启用'; ?>
                                        </span>
                                    </div>
                                    <?php if ($cache_info['opcache']['enabled']): ?>
                                    <div>命中率: <?php echo $cache_info['opcache']['hit_rate']; ?>%</div>
                                    <?php endif; ?>
                                </div>
                            </div>
                        </div>
                        <div class="cache-size">
                            <?php echo $cache_info['opcache']['enabled'] ? formatBytes($cache_info['opcache']['memory_usage']) : '0 B'; ?>
                        </div>
                        <div class="cache-actions">
                            <form method="POST" style="display: inline;">
                                <input type="hidden" name="action" value="clear_opcache">
                                <button type="submit" class="btn btn-primary" <?php echo !$cache_info['opcache']['enabled'] ? 'disabled' : ''; ?>>
                                    <i class="fas fa-trash"></i>
                                    清理 OPCache
                                </button>
                            </form>
                        </div>
                    </div>

                    <!-- 会话文件 -->
                    <div class="cache-card">
                        <div class="cache-header">
                            <div class="cache-icon sessions">
                                <i class="fas fa-users"></i>
                            </div>
                            <div class="cache-info">
                                <h3 class="cache-title">会话文件</h3>
                                <div class="cache-stats">
                                    <div>文件数量: <?php echo $cache_info['sessions']['count']; ?> 个</div>
                                    <div>存储路径: <?php echo session_save_path() ?: sys_get_temp_dir(); ?></div>
                                </div>
                            </div>
                        </div>
                        <div class="cache-size">
                            <?php echo formatBytes($cache_info['sessions']['size']); ?>
                        </div>
                        <div class="cache-actions">
                            <form method="POST" style="display: inline;">
                                <input type="hidden" name="action" value="clear_sessions">
                                <button type="submit" class="btn btn-primary" onclick="return confirm('清理会话文件会让其他用户重新登录，确定继续吗？')">
                                    <i class="fas fa-trash"></i>
                                    清理会话文件
                                </button>
                            </form>
                        </div>
                    </div>

                    <!-- 临时文件 -->
                    <div class="cache-card">
                        <div class="cache-header">
                            <div class="cache-icon temp">
                                <i class="fas fa-clock"></i>
                            </div>
                            <div class="cache-info">
                                <h3 class="cache-title">临时文件</h3>
                                <div class="cache-stats">
                                    <div>文件数量: <?php echo $cache_info['temp_files']['count']; ?> 个</div>
                                    <div>清理条件: 超过1小时的文件</div>
                                </div>
                            </div>
                        </div>
                        <div class="cache-size">
                            <?php echo formatBytes($cache_info['temp_files']['size']); ?>
                        </div>
                        <div class="cache-actions">
                            <form method="POST" style="display: inline;">
                                <input type="hidden" name="action" value="clear_temp_files">
                                <button type="submit" class="btn btn-primary">
                                    <i class="fas fa-trash"></i>
                                    清理临时文件
                                </button>
                            </form>
                        </div>
                    </div>

                    <!-- 缓存文件 -->
                    <div class="cache-card">
                        <div class="cache-header">
                            <div class="cache-icon files">
                                <i class="fas fa-archive"></i>
                            </div>
                            <div class="cache-info">
                                <h3 class="cache-title">应用缓存文件</h3>
                                <div class="cache-stats">
                                    <div>文件数量: <?php echo $cache_info['cache_files']['count']; ?> 个</div>
                                    <div>包含: 模板缓存、数据缓存等</div>
                                </div>
                            </div>
                        </div>
                        <div class="cache-size">
                            <?php echo formatBytes($cache_info['cache_files']['size']); ?>
                        </div>
                        <div class="cache-actions">
                            <form method="POST" style="display: inline;">
                                <input type="hidden" name="action" value="clear_cache_files">
                                <button type="submit" class="btn btn-primary">
                                    <i class="fas fa-trash"></i>
                                    清理缓存文件
                                </button>
                            </form>
                        </div>
                    </div>
                </div>

                <!-- 清理说明 -->
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fas fa-info-circle"></i>
                            清理说明
                        </h2>
                    </div>
                    <div class="card-body">
                        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1.5rem;">
                            <div>
                                <h4 style="color: var(--gray-900); margin-bottom: 0.5rem;">
                                    <i class="fas fa-microchip" style="color: #8b5cf6;"></i>
                                    OPCache 操作码缓存
                                </h4>
                                <p style="color: var(--gray-600); font-size: 0.875rem; line-height: 1.6;">
                                    PHP的OPCache缓存编译后的操作码，提高执行效率。清理后PHP脚本首次运行会稍慢，但会重新缓存。
                                </p>
                            </div>
                            <div>
                                <h4 style="color: var(--gray-900); margin-bottom: 0.5rem;">
                                    <i class="fas fa-users" style="color: #06b6d4;"></i>
                                    会话文件
                                </h4>
                                <p style="color: var(--gray-600); font-size: 0.875rem; line-height: 1.6;">
                                    存储用户会话信息的文件。清理后其他已登录用户需要重新登录，但可以释放无用的会话存储空间。
                                </p>
                            </div>
                            <div>
                                <h4 style="color: var(--gray-900); margin-bottom: 0.5rem;">
                                    <i class="fas fa-clock" style="color: #f59e0b;"></i>
                                    临时文件
                                </h4>
                                <p style="color: var(--gray-600); font-size: 0.875rem; line-height: 1.6;">
                                    系统和应用创建的临时文件。只会删除超过1小时的文件，确保正在使用的临时文件不会被误删。
                                </p>
                            </div>
                            <div>
                                <h4 style="color: var(--gray-900); margin-bottom: 0.5rem;">
                                    <i class="fas fa-archive" style="color: #10b981;"></i>
                                    应用缓存文件
                                </h4>
                                <p style="color: var(--gray-600); font-size: 0.875rem; line-height: 1.6;">
                                    应用程序生成的各种缓存文件，包括模板缓存、数据缓存等。清理后应用会重新生成必要的缓存。
                                </p>
                            </div>
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

        // 添加表单提交加载状态
        document.addEventListener('DOMContentLoaded', function() {
            const forms = document.querySelectorAll('form');
            forms.forEach(form => {
                form.addEventListener('submit', function() {
                    const submitBtn = this.querySelector('button[type="submit"]');
                    if (submitBtn && !submitBtn.disabled) {
                        submitBtn.disabled = true;
                        const originalText = submitBtn.innerHTML;
                        submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> 处理中...';
                        
                        // 10秒后恢复按钮状态
                        setTimeout(() => {
                            submitBtn.disabled = false;
                            submitBtn.innerHTML = originalText;
                        }, 10000);
                    }
                });
            });
        });

        // 添加卡片动画效果
        document.addEventListener('DOMContentLoaded', function() {
            const cacheCards = document.querySelectorAll('.cache-card');
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

            cacheCards.forEach((card, index) => {
                card.style.transform = 'translateY(20px)';
                card.style.opacity = '0';
                card.style.transition = `transform 0.6s ease ${index * 0.1}s, opacity 0.6s ease ${index * 0.1}s`;
                observer.observe(card);
            });
        });
    </script>
</body>
</html>
