<?php
/**
 * 密码重置控制器
 * 
 * 处理用户忘记密码相关的API请求，包括发送验证码和重置密码
 * 
 * @author ovo
 * @version 1.0.0
 * @date 2025-05-24
 */

class ResetPasswordController {
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
        if (empty($params['email']) || empty($params['captcha']) || empty($params['captcha_id'])) {
            response_error(400, '邮箱、验证码和验证码ID不能为空');
        }
        
        $email = $params['email'];
        $captcha = $params['captcha'];
        $captcha_id = $params['captcha_id'];
        
        // 验证图片验证码
        $captcha_sql = "SELECT * FROM " . DB_PREFIX . "captcha WHERE captcha_id = :captcha_id AND expire_time > :current_time";
        $stmt = $this->db->prepare($captcha_sql);
        $stmt->bindParam(':captcha_id', $captcha_id);
        $current_time = time();
        $stmt->bindParam(':current_time', $current_time);
        $stmt->execute();
        $captcha_info = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$captcha_info || strtolower($captcha_info['captcha_code']) != strtolower($captcha)) {
            response_error(400, '验证码错误');
        }
        
        // 删除已使用的验证码
        $delete_captcha_sql = "DELETE FROM " . DB_PREFIX . "captcha WHERE captcha_id = :captcha_id";
        $stmt = $this->db->prepare($delete_captcha_sql);
        $stmt->bindParam(':captcha_id', $captcha_id);
        $stmt->execute();
        
        // 验证邮箱格式
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            response_error(400, '邮箱格式不正确');
        }
        
        // 检查邮箱是否存在
        $check_sql = "SELECT user_id, username FROM " . "qwq_user WHERE email = :email AND status = 1";
        $stmt = $this->db->prepare($check_sql);
        $stmt->bindParam(':email', $email);
        $stmt->execute();
        
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$user) {
            response_error(404, '该邮箱未注册');
        }
        
        // 生成6位数字验证码
        $code = sprintf("%06d", mt_rand(0, 999999));
        $now = date('Y-m-d H:i:s');
        $expire_time = date('Y-m-d H:i:s', time() + 10 * 60); // 10分钟有效期
        
        try {
            // 检查是否已有验证码记录
            $check_code_sql = "SELECT id FROM " . "qwq_verification_code WHERE email = :email AND type = 'reset_password'";
            $stmt = $this->db->prepare($check_code_sql);
            $stmt->bindParam(':email', $email);
            $stmt->execute();
            
            if ($stmt->fetch(PDO::FETCH_ASSOC)) {
                // 更新验证码
                $update_sql = "UPDATE " . "qwq_verification_code 
                    SET code = :code, expire_time = :expire_time, update_time = :update_time 
                    WHERE email = :email AND type = 'reset_password'";
                
                $stmt = $this->db->prepare($update_sql);
                $stmt->bindParam(':code', $code);
                $stmt->bindParam(':expire_time', $expire_time);
                $stmt->bindParam(':update_time', $now);
                $stmt->bindParam(':email', $email);
                $stmt->execute();
            } else {
                // 插入验证码
                $insert_sql = "INSERT INTO " . "qwq_verification_code 
                    (email, code, type, expire_time, create_time) 
                    VALUES 
                    (:email, :code, 'reset_password', :expire_time, :create_time)";
                
                $stmt = $this->db->prepare($insert_sql);
                $stmt->bindParam(':email', $email);
                $stmt->bindParam(':code', $code);
                $stmt->bindParam(':expire_time', $expire_time);
                $stmt->bindParam(':create_time', $now);
                $stmt->execute();
            }
            
            // 发送邮件
            $subject = 'OVO视频 - 密码重置验证码';
            $message = "亲爱的 {$user['username']}，\n\n";
            $message .= "您正在进行密码重置操作，验证码为：{$code}，有效期10分钟。\n\n";
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
     * 重置密码
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function resetPassword($params) {
        // 验证必填参数
        if (empty($params['email']) || empty($params['verification_code']) || empty($params['password']) || 
            empty($params['captcha']) || empty($params['captcha_id'])) {
            response_error(400, '邮箱、邮箱验证码、新密码、图片验证码和验证码ID不能为空');
        }
        
        $email = $params['email'];
        $verification_code = $params['verification_code'];
        $password = $params['password'];
        $captcha = $params['captcha'];
        $captcha_id = $params['captcha_id'];
        
        // 验证图片验证码
        $captcha_sql = "SELECT * FROM " . DB_PREFIX . "captcha WHERE captcha_id = :captcha_id AND expire_time > :current_time";
        $stmt = $this->db->prepare($captcha_sql);
        $stmt->bindParam(':captcha_id', $captcha_id);
        $current_time = time();
        $stmt->bindParam(':current_time', $current_time);
        $stmt->execute();
        $captcha_info = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$captcha_info || strtolower($captcha_info['captcha_code']) != strtolower($captcha)) {
            response_error(400, '验证码错误');
        }
        
        // 删除已使用的验证码
        $delete_captcha_sql = "DELETE FROM " . DB_PREFIX . "captcha WHERE captcha_id = :captcha_id";
        $stmt = $this->db->prepare($delete_captcha_sql);
        $stmt->bindParam(':captcha_id', $captcha_id);
        $stmt->execute();
        
        // 验证邮箱格式
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            response_error(400, '邮箱格式不正确');
        }
        
        // 验证密码长度（至少6位）
        if (strlen($password) < 6) {
            response_error(400, '密码长度不能少于6位');
        }
        
        // 检查邮箱是否存在
        $check_sql = "SELECT user_id, username FROM " . "qwq_user WHERE email = :email AND status = 1";
        $stmt = $this->db->prepare($check_sql);
        $stmt->bindParam(':email', $email);
        $stmt->execute();
        
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$user) {
            response_error(404, '该邮箱未注册');
        }
        
        // 验证邮箱验证码
        $check_code_sql = "SELECT * FROM " . "qwq_verification_code 
            WHERE email = :email AND code = :code AND type = 'reset_password' AND expire_time > NOW()";
        
        $stmt = $this->db->prepare($check_code_sql);
        $stmt->bindParam(':email', $email);
        $stmt->bindParam(':code', $verification_code);
        $stmt->execute();
        
        $code_info = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$code_info) {
            response_error(400, '验证码无效或已过期');
        }
        
        try {
            // 开始事务
            $this->db->beginTransaction();
            
            // 更新密码
            $password_md5 = md5($password);
            $now = date('Y-m-d H:i:s');
            
            // 更新OVO用户表密码
            $update_sql = "UPDATE " . "qwq_user 
                SET password = :password, update_time = :update_time 
                WHERE user_id = :user_id";
            
            $stmt = $this->db->prepare($update_sql);
            $stmt->bindParam(':password', $password_md5);
            $stmt->bindParam(':update_time', $now);
            $stmt->bindParam(':user_id', $user['user_id']);
            $stmt->execute();
            
            // 同步更新MacCMS会员表密码
            $update_mac_sql = "UPDATE " . DB_PREFIX . "user 
                SET user_pwd = :user_pwd 
                WHERE user_id = :user_id";
            
            $stmt = $this->db->prepare($update_mac_sql);
            $stmt->bindParam(':user_pwd', $password_md5);
            $stmt->bindParam(':user_id', $user['user_id']);
            $stmt->execute();
            
            // 删除验证码记录
            $delete_sql = "DELETE FROM " . "qwq_verification_code 
                WHERE id = :id";
            
            $stmt = $this->db->prepare($delete_sql);
            $stmt->bindParam(':id', $code_info['id']);
            $stmt->execute();
            
            // 提交事务
            $this->db->commit();
            
            // 返回成功响应
            response_success([
                'user_id' => $user['user_id'],
                'username' => $user['username'],
                'email' => $email
            ]);
            
        } catch (Exception $e) {
            // 回滚事务
            $this->db->rollBack();
            response_error(500, '重置密码失败: ' . $e->getMessage());
        }
    }
}
