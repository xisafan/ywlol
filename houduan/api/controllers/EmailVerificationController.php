<?php
/**
 * 邮箱验证控制器
 * 
 * 处理邮箱验证相关的API请求，包括发送验证码和验证验证码
 * 
 * @author ovo
 * @version 1.0.0
 * @date 2025-05-24
 */

class EmailVerificationController {
    /**
     * 数据库连接
     * @var PDO
     */
    private $db;
    
    /**
     * 构造函数
     * 
     * @param PDO $db 数据库连接
     */
    public function __construct($db) {
        $this->db = $db;
    }
    
    /**
     * 发送验证码
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function sendVerificationCode($params) {
        // 验证必填参数
        if (empty($params['email'])) {
            response_error(400, '邮箱不能为空');
        }
        
        $email = $params['email'];
        $type = isset($params['type']) ? $params['type'] : 'register'; // register, reset_password
        
        // 验证邮箱格式
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            response_error(400, '邮箱格式不正确');
        }
        
        // 如果是注册验证，检查邮箱是否已存在
        if ($type === 'register') {
            $check_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "ovo_user WHERE email = :email";
            $stmt = $this->db->prepare($check_sql);
            $stmt->bindParam(':email', $email);
            $stmt->execute();
            
            if ($stmt->fetchColumn() > 0) {
                response_error(400, '该邮箱已被注册');
            }
        }
        
        // 如果是重置密码验证，检查邮箱是否存在
        if ($type === 'reset_password') {
            $check_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "ovo_user WHERE email = :email AND status = 1";
            $stmt = $this->db->prepare($check_sql);
            $stmt->bindParam(':email', $email);
            $stmt->execute();
            
            if ($stmt->fetchColumn() == 0) {
                response_error(404, '该邮箱未注册');
            }
        }
        
        // 生成6位数字验证码
        $code = sprintf("%06d", mt_rand(0, 999999));
        $now = date('Y-m-d H:i:s');
        $expire_time = date('Y-m-d H:i:s', time() + 10 * 60); // 10分钟有效期
        
        try {
            // 检查是否已有验证码记录
            $check_code_sql = "SELECT id FROM " . DB_PREFIX . "ovo_verification_code WHERE email = :email AND type = :type";
            $stmt = $this->db->prepare($check_code_sql);
            $stmt->bindParam(':email', $email);
            $stmt->bindParam(':type', $type);
            $stmt->execute();
            
            if ($stmt->fetch(PDO::FETCH_ASSOC)) {
                // 更新验证码
                $update_sql = "UPDATE " . DB_PREFIX . "ovo_verification_code 
                    SET code = :code, expire_time = :expire_time, update_time = :update_time 
                    WHERE email = :email AND type = :type";
                
                $stmt = $this->db->prepare($update_sql);
                $stmt->bindParam(':code', $code);
                $stmt->bindParam(':expire_time', $expire_time);
                $stmt->bindParam(':update_time', $now);
                $stmt->bindParam(':email', $email);
                $stmt->bindParam(':type', $type);
                $stmt->execute();
            } else {
                // 插入验证码
                $insert_sql = "INSERT INTO " . DB_PREFIX . "ovo_verification_code 
                    (email, code, type, expire_time, create_time) 
                    VALUES 
                    (:email, :code, :type, :expire_time, :create_time)";
                
                $stmt = $this->db->prepare($insert_sql);
                $stmt->bindParam(':email', $email);
                $stmt->bindParam(':code', $code);
                $stmt->bindParam(':type', $type);
                $stmt->bindParam(':expire_time', $expire_time);
                $stmt->bindParam(':create_time', $now);
                $stmt->execute();
            }
            
            // 发送邮件
            $subject = 'OVO视频 - ' . ($type === 'register' ? '注册' : '密码重置') . '验证码';
            $message = "您好，\n\n";
            $message .= "您正在进行" . ($type === 'register' ? 'OVO视频账号注册' : '密码重置') . "操作，验证码为：{$code}，有效期10分钟。\n\n";
            $message .= "如果不是您本人操作，请忽略此邮件。\n\n";
            $message .= "OVO视频团队";
            
            $headers = 'From: noreply@ovovideo.com' . "\r\n" .
                'Reply-To: support@ovovideo.com' . "\r\n" .
                'X-Mailer: PHP/' . phpversion();
            
            $mail_sent = mail($email, $subject, $message, $headers);
            
            if (!$mail_sent) {
                // 邮件发送失败，但不影响验证码生成
                error_log("Failed to send verification email to {$email}");
            }
            
            // 返回成功响应
            response_success([
                'email' => $email,
                'expire_time' => $expire_time
            ]);
            
        } catch (Exception $e) {
            response_error(500, '发送验证码失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 验证验证码
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function verifyCode($params) {
        // 验证必填参数
        if (empty($params['email']) || empty($params['code'])) {
            response_error(400, '邮箱和验证码不能为空');
        }
        
        $email = $params['email'];
        $code = $params['code'];
        $type = isset($params['type']) ? $params['type'] : 'register'; // register, reset_password
        
        // 验证邮箱格式
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            response_error(400, '邮箱格式不正确');
        }
        
        // 验证验证码
        $check_code_sql = "SELECT * FROM " . DB_PREFIX . "ovo_verification_code 
            WHERE email = :email AND code = :code AND type = :type AND expire_time > NOW()";
        
        $stmt = $this->db->prepare($check_code_sql);
        $stmt->bindParam(':email', $email);
        $stmt->bindParam(':code', $code);
        $stmt->bindParam(':type', $type);
        $stmt->execute();
        
        $code_info = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$code_info) {
            response_error(400, '验证码无效或已过期');
        }
        
        // 返回成功响应
        response_success([
            'email' => $email,
            'verified' => true
        ]);
    }
}
