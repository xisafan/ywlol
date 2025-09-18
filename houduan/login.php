<?php
// +----------------------------------------------------------------------
// | OVO Fun 管理系统
// +----------------------------------------------------------------------
// | 登录页面
// +----------------------------------------------------------------------

// 启动会话
session_start();

// 处理退出登录请求
if (isset($_GET['logout'])) {
    // 清除会话
    session_unset();
    session_destroy();
    
    // 清除记住我的cookie
    if (isset($_COOKIE['admin_token'])) {
        setcookie('admin_token', '', time() - 3600, '/');
    }
    
    // 重定向到登录页面
    header('Location: login.php');
    exit;
}


// 如果已经登录，直接跳转到首页
if (isset($_SESSION['admin_id']) && $_SESSION['admin_id'] > 0) {
    header('Location: index.php');
    exit;
}

// 检查安装锁定文件
if (!file_exists(__DIR__ . '/lock.log')) {
    header('Location: install.php');
    exit;
}

// 引入数据库配置
$db_config_file = __DIR__ . '/database.php';
if (!file_exists($db_config_file)) {
    die('数据库配置文件不存在，请先完成安装');
}

// 初始化错误信息变量
$error_message = '';
$success_message = '';

// 处理登录请求
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // 获取表单数据
    $username = isset($_POST['username']) ? trim($_POST['username']) : '';
    $password = isset($_POST['password']) ? trim($_POST['password']) : '';
    $remember = isset($_POST['remember']) ? (bool)$_POST['remember'] : false;
    
    // 表单验证
    if (empty($username)) {
        $error_message = '用户名不能为空';
    } elseif (empty($password)) {
        $error_message = '密码不能为空';
    } else {
        try {
            // 加载数据库配置
            $db_config = include($db_config_file);
            
            // 连接数据库
            $dsn = "mysql:host={$db_config['hostname']};port={$db_config['hostport']};dbname={$db_config['database']};charset={$db_config['charset']}";
            $pdo = new PDO($dsn, $db_config['username'], $db_config['password']);
            $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            
            // 设置表前缀
            $table_prefix = $db_config['prefix'];
            // 强制使用 mac_ovo_admin 表
            $admin_table = 'mac_ovo_admin';
            
            // 查询用户
            $sql = "SELECT * FROM `{$admin_table}` WHERE `username` = :username AND `status` = 1 LIMIT 1";
            $stmt = $pdo->prepare($sql);
            $stmt->bindParam(':username', $username);
            $stmt->execute();
            $admin = $stmt->fetch(PDO::FETCH_ASSOC);
            
            // 验证用户名和密码
            if ($admin) {
                // 只用MD5方式校验
                if ($admin['password'] === md5($password)) {
                    // 更新登录信息
                    $update_sql = "UPDATE `{$admin_table}` SET 
                                  `last_login_time` = :login_time, 
                                  `last_login_ip` = :login_ip, 
                                  `update_time` = :update_time 
                                  WHERE `id` = :id";
                    $stmt = $pdo->prepare($update_sql);
                    $now = date('Y-m-d H:i:s');
                    $ip = $_SERVER['REMOTE_ADDR'];
                    $stmt->bindParam(':login_time', $now);
                    $stmt->bindParam(':login_ip', $ip);
                    $stmt->bindParam(':update_time', $now);
                    $stmt->bindParam(':id', $admin['id']);
                    $stmt->execute();
                    
                    // 设置会话
                    $_SESSION['admin_id'] = $admin['id'];
                    $_SESSION['admin_username'] = $admin['username'];
                    $_SESSION['admin_login_time'] = time();
                    
                    // 如果选择了记住我，设置Cookie
                    if ($remember) {
                        $token = md5($admin['id'] . $admin['username'] . time() . mt_rand(1000, 9999));
                        setcookie('admin_token', $token, time() + 86400 * 7, '/');
                        // 可以将token存入数据库，以便后续验证
                        // 这里简化处理，仅演示功能
                    }
                    
                    // 登录成功，跳转到首页
                    header('Location: index.php');
                    exit;
                } else {
                    $error_message = '用户名或密码错误';
                }
            } else {
                $error_message = '用户名或密码错误';
            }
        } catch (PDOException $e) {
            // 记录日志
            error_log('登录错误: ' . $e->getMessage(), 0);
            $error_message = '系统错误，请稍后再试';
        }
    }
}
?>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OVO Fun - 管理员登录</title>
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
            --white: #ffffff;
            --gray-50: #f9fafb;
            --gray-100: #f3f4f6;
            --gray-200: #e5e7eb;
            --gray-300: #d1d5db;
            --gray-600: #4b5563;
            --gray-700: #374151;
            --gray-800: #1f2937;
            --gray-900: #111827;
            --shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1);
            --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1);
            --shadow-xl: 0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1);
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, var(--primary-blue) 0%, var(--dark-blue) 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 1rem;
        }

        .login-container {
            background: var(--white);
            border-radius: 1rem;
            box-shadow: var(--shadow-xl);
            overflow: hidden;
            width: 100%;
            max-width: 400px;
            position: relative;
        }

        .login-header {
            background: linear-gradient(135deg, var(--primary-blue), var(--dark-blue));
            color: var(--white);
            padding: 2rem 1.5rem 1.5rem;
            text-align: center;
            position: relative;
        }

        .login-header::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><circle cx="20" cy="20" r="2" fill="rgba(255,255,255,0.1)"/><circle cx="80" cy="20" r="1" fill="rgba(255,255,255,0.1)"/><circle cx="40" cy="40" r="1" fill="rgba(255,255,255,0.1)"/><circle cx="90" cy="70" r="2" fill="rgba(255,255,255,0.1)"/><circle cx="10" cy="80" r="1" fill="rgba(255,255,255,0.1)"/></svg>');
            animation: float 6s ease-in-out infinite;
        }

        @keyframes float {
            0%, 100% { transform: translateY(0px); }
            50% { transform: translateY(-10px); }
        }

        .logo-icon {
            width: 4rem;
            height: 4rem;
            background: rgba(255, 255, 255, 0.2);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 1rem;
            font-size: 1.5rem;
            position: relative;
            z-index: 1;
        }

        .login-title {
            font-size: 1.75rem;
            font-weight: 700;
            margin-bottom: 0.5rem;
            position: relative;
            z-index: 1;
        }

        .login-subtitle {
            color: rgba(255, 255, 255, 0.8);
            font-size: 0.875rem;
            position: relative;
            z-index: 1;
        }

        .login-body {
            padding: 2rem 1.5rem;
        }

        .alert {
            padding: 1rem;
            border-radius: 0.5rem;
            margin-bottom: 1.5rem;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .alert-error {
            background: #fef2f2;
            border: 1px solid #fecaca;
            color: #dc2626;
        }

        .alert-success {
            background: #f0fdf4;
            border: 1px solid #bbf7d0;
            color: #166534;
        }

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
            transition: all 0.2s ease;
            background: var(--white);
        }

        .form-control:focus {
            outline: none;
            border-color: var(--primary-blue);
            box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
        }

        .form-check {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            margin-bottom: 1.5rem;
        }

        .form-check-input {
            width: 1rem;
            height: 1rem;
            border: 1px solid var(--gray-300);
            border-radius: 0.25rem;
        }

        .form-check-label {
            font-size: 0.875rem;
            color: var(--gray-700);
        }

        .btn {
            width: 100%;
            padding: 0.75rem 1.5rem;
            background: linear-gradient(135deg, var(--primary-blue), var(--dark-blue));
            color: var(--white);
            border: none;
            border-radius: 0.5rem;
            font-size: 0.875rem;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 0.5rem;
        }

        .btn:hover {
            transform: translateY(-1px);
            box-shadow: var(--shadow-lg);
        }

        .btn:active {
            transform: translateY(0);
        }

        .login-footer {
            background: var(--gray-50);
            padding: 1rem 1.5rem;
            text-align: center;
            border-top: 1px solid var(--gray-200);
        }

        .login-footer a {
            color: var(--primary-blue);
            text-decoration: none;
            font-size: 0.875rem;
            transition: color 0.2s ease;
        }

        .login-footer a:hover {
            color: var(--dark-blue);
        }

        /* 动画效果 */
        .login-container {
            animation: slideIn 0.5s ease-out;
        }

        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateY(20px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        /* 响应式设计 */
        @media (max-width: 480px) {
            .login-container {
                margin: 1rem;
                max-width: none;
            }

            .login-body {
                padding: 1.5rem 1rem;
            }
        }
    </style>
</head>
<body>
    <div class="login-container">
        <!-- 登录头部 -->
        <div class="login-header">
            <div class="logo-icon">
                <i class="fas fa-video"></i>
            </div>
            <h1 class="login-title">云雾管理后台</h1>
            <p class="login-subtitle">管理系统后台登录</p>
        </div>
        
        <!-- 登录主体 -->
        <div class="login-body">
            <!-- 错误/成功消息 -->
            <?php if (!empty($error_message)): ?>
            <div class="alert alert-error">
                <i class="fas fa-exclamation-circle"></i>
                <?php echo htmlspecialchars($error_message); ?>
            </div>
            <?php endif; ?>
            
            <?php if (!empty($success_message)): ?>
            <div class="alert alert-success">
                <i class="fas fa-check-circle"></i>
                <?php echo htmlspecialchars($success_message); ?>
            </div>
            <?php endif; ?>
            
            <!-- 登录表单 -->
            <form method="POST" action="" id="loginForm">
                <div class="form-group">
                    <label for="username" class="form-label">
                        <i class="fas fa-user"></i>
                        用户名
                    </label>
                    <input type="text" class="form-control" id="username" name="username" 
                           placeholder="请输入管理员用户名"
                           value="<?php echo isset($_POST['username']) ? htmlspecialchars($_POST['username']) : ''; ?>" 
                           required autocomplete="username">
                </div>
                
                <div class="form-group">
                    <label for="password" class="form-label">
                        <i class="fas fa-lock"></i>
                        密码
                    </label>
                    <input type="password" class="form-control" id="password" name="password" 
                           placeholder="请输入登录密码" required autocomplete="current-password">
                </div>
                
                <div class="form-check">
                    <input type="checkbox" class="form-check-input" id="remember" name="remember" value="1">
                    <label class="form-check-label" for="remember">
                        <i class="fas fa-clock"></i>
                        记住我（7天内自动登录）
                    </label>
                </div>
                
                <button type="submit" class="btn" id="loginBtn">
                    <i class="fas fa-sign-in-alt"></i>
                    立即登录
                </button>
            </form>
        </div>
        
        <!-- 登录页脚 -->
        <div class="login-footer">
            <p>© <?php echo date('Y'); ?> 云雾管理系统 | <a href="index.php">返回首页</a></p>
        </div>
    </div>
    
    <script>
    document.addEventListener('DOMContentLoaded', function() {
        const loginForm = document.getElementById('loginForm');
        const loginBtn = document.getElementById('loginBtn');
        const usernameInput = document.getElementById('username');
        const passwordInput = document.getElementById('password');
        
        // 表单验证和提交处理
        loginForm.addEventListener('submit', function(e) {
            const username = usernameInput.value.trim();
            const password = passwordInput.value.trim();
            
            if (username === '') {
                e.preventDefault();
                showError('请输入用户名');
                usernameInput.focus();
                return;
            }
            
            if (password === '') {
                e.preventDefault();
                showError('请输入密码');
                passwordInput.focus();
                return;
            }
            
            // 显示加载状态
            loginBtn.disabled = true;
            loginBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> 登录中...';
        });
        
        // 输入框焦点处理
        [usernameInput, passwordInput].forEach(input => {
            input.addEventListener('focus', function() {
                this.parentElement.classList.add('focused');
            });
            
            input.addEventListener('blur', function() {
                this.parentElement.classList.remove('focused');
            });
        });
        
        // 显示错误信息
        function showError(message) {
            // 移除现有的错误提示
            const existingAlert = document.querySelector('.alert-error');
            if (existingAlert) {
                existingAlert.remove();
            }
            
            // 创建新的错误提示
            const alert = document.createElement('div');
            alert.className = 'alert alert-error';
            alert.innerHTML = '<i class="fas fa-exclamation-circle"></i> ' + message;
            
            // 插入到表单前面
            const loginBody = document.querySelector('.login-body');
            const form = document.getElementById('loginForm');
            loginBody.insertBefore(alert, form);
            
            // 3秒后自动消失
            setTimeout(() => {
                if (alert.parentNode) {
                    alert.remove();
                }
            }, 3000);
        }
        
        // 自动聚焦到用户名输入框
        usernameInput.focus();
        
        // 添加键盘快捷键支持
        document.addEventListener('keydown', function(e) {
            if (e.ctrlKey && e.key === 'Enter') {
                loginForm.submit();
            }
        });
    });
    </script>
</body>
</html>