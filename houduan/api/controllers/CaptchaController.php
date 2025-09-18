<?php
/**
 * 验证码控制器
 * 
 * 提供验证码生成和验证功能
 * 
 * @author Assistant
 * @version 1.0.0
 * @date 2025-09-18
 */

class CaptchaController {
    
    /**
     * 生成验证码图片
     * 
     * @return void
     */
    public function generate() {
        global $pdo;
        
        // 🔧 重要修复：基于时间戳生成固定验证码，确保同一时间戳得到相同内容和ID
        $timestamp = isset($_GET['t']) ? $_GET['t'] : time() * 1000;
        
        // 使用时间戳作为随机种子，确保相同时间戳生成相同验证码
        srand(intval($timestamp / 1000)); // 使用秒级时间戳作为种子
        
        $length = 4;
        $characters = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // 移除易混淆字符
        $captcha_code = '';
        
        for ($i = 0; $i < $length; $i++) {
            $captcha_code .= $characters[rand(0, strlen($characters) - 1)];
        }
        
        // 恢复随机种子，避免影响其他代码
        srand();
        
        // 基于时间戳生成固定ID
        $captcha_id = md5('captcha_' . $timestamp);
        $expire_time = time() + 600; // 10分钟有效期
        
        try {
            // 清理过期的验证码
            $cleanup_sql = "DELETE FROM " . DB_PREFIX . "captcha WHERE expire_time < ?";
            $cleanup_stmt = $pdo->prepare($cleanup_sql);
            $cleanup_stmt->execute([time()]);
            
            // 🔧 重要修复：检查是否已存在相同ID的验证码，避免重复插入
            $check_sql = "SELECT captcha_code FROM " . DB_PREFIX . "captcha WHERE captcha_id = ?";
            $check_stmt = $pdo->prepare($check_sql);
            $check_stmt->execute([$captcha_id]);
            
            if ($check_stmt->rowCount() == 0) {
                // 如果不存在，插入新记录
                $sql = "INSERT INTO " . DB_PREFIX . "captcha (captcha_id, captcha_code, create_time, expire_time) VALUES (?, ?, ?, ?)";
                $stmt = $pdo->prepare($sql);
                $stmt->execute([$captcha_id, strtolower($captcha_code), time(), $expire_time]);
            }
            
        } catch (Exception $e) {
            // 如果数据库操作失败，继续生成图片，但验证会失败
        }
        
        // 创建图片
        $width = 120;
        $height = 40;
        $image = imagecreate($width, $height);
        
        // 设置颜色
        $bg_color = imagecolorallocate($image, 245, 245, 245);
        $text_color = imagecolorallocate($image, 0, 0, 0);
        $line_color = imagecolorallocate($image, 64, 64, 64);
        $noise_color = imagecolorallocate($image, 100, 120, 180);
        
        // 填充背景
        imagefill($image, 0, 0, $bg_color);
        
        // 添加干扰线
        for ($i = 0; $i < 6; $i++) {
            imageline($image, rand(0, $width), rand(0, $height), rand(0, $width), rand(0, $height), $line_color);
        }
        
        // 添加噪点
        for ($i = 0; $i < 100; $i++) {
            imagesetpixel($image, rand(0, $width), rand(0, $height), $noise_color);
        }
        
        // 添加验证码文字
        $font_size = 5;
        $x = ($width - strlen($captcha_code) * imagefontwidth($font_size)) / 2;
        $y = ($height - imagefontheight($font_size)) / 2;
        
        imagestring($image, $font_size, $x, $y, $captcha_code, $text_color);
        
        // 设置响应头，包含验证码ID
        header('Content-Type: image/png');
        header('Cache-Control: no-cache, no-store, must-revalidate');
        header('Pragma: no-cache');
        header('Expires: 0');
        header('X-Captcha-ID: ' . $captcha_id); // 通过响应头传递验证码ID
        header('Access-Control-Expose-Headers: X-Captcha-ID'); // 允许前端访问自定义头
        
        // 输出图片
        imagepng($image);
        imagedestroy($image);
        exit;
    }
    
    /**
     * 验证验证码
     * 
     * @param array $params 参数数组
     * @return array 验证结果
     */
    public function verify($params) {
        global $pdo;
        
        // 验证必填参数
        if (empty($params['captcha'])) {
            response_error(400, '验证码不能为空');
        }
        
        if (empty($params['captcha_id'])) {
            response_error(400, '验证码ID不能为空');
        }
        
        $input_captcha = strtolower(trim($params['captcha']));
        $captcha_id = trim($params['captcha_id']);
        
        try {
            // 查找验证码
            $sql = "SELECT * FROM " . DB_PREFIX . "captcha WHERE captcha_id = ?";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([$captcha_id]);
            $captcha_record = $stmt->fetch(PDO::FETCH_ASSOC);
            
            // 检查验证码是否存在
            if (!$captcha_record) {
                response_error(400, '验证码已失效，请刷新后重试');
            }
            
            // 检查验证码是否过期
            if (time() > $captcha_record['expire_time']) {
                // 删除过期的验证码
                $delete_sql = "DELETE FROM " . DB_PREFIX . "captcha WHERE captcha_id = ?";
                $delete_stmt = $pdo->prepare($delete_sql);
                $delete_stmt->execute([$captcha_id]);
                
                response_error(400, '验证码已过期，请刷新后重试');
            }
            
            // 验证验证码
            if ($input_captcha !== $captcha_record['captcha_code']) {
                response_error(400, '验证码错误');
            }
            
            // 验证成功，删除已使用的验证码
            $delete_sql = "DELETE FROM " . DB_PREFIX . "captcha WHERE captcha_id = ?";
            $delete_stmt = $pdo->prepare($delete_sql);
            $delete_stmt->execute([$captcha_id]);
            
            response_success('验证码验证成功');
            
        } catch (Exception $e) {
            response_error(500, '验证码验证失败，请重试');
        }
    }
    
    /**
     * 刷新验证码（获取新的验证码）
     * 
     * @return void
     */
    public function refresh() {
        // 清除旧的验证码
        if (session_status() == PHP_SESSION_NONE) {
            session_start();
        }
        unset($_SESSION['captcha_code'], $_SESSION['captcha_time']);
        
        // 生成新的验证码
        $this->generate();
    }
}
