<?php
/**
 * JWT 工具类
 * 
 * 提供JWT令牌的生成、验证等功能
 * 
 * @author Manus AI
 * @version 1.0.0
 * @date 2025-05-20
 */

class JWT {
    /**
     * 密钥
     * @var string
     */
    private $secret;
    
    /**
     * 构造函数
     */
    public function __construct() {
        // 从数据库获取密钥
        global $pdo;
        
        try {
            $stmt = $pdo->query("SELECT `encrypt_key` FROM `" . DB_PREFIX . "ovo_setting` LIMIT 1");
            $setting = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($setting && !empty($setting['encrypt_key'])) {
                $this->secret = $setting['encrypt_key'];
            } else {
                // 使用默认密钥
                $this->secret = 'ovo_default_secret_key';
            }
        } catch (Exception $e) {
            // 使用默认密钥
            $this->secret = 'ovo_default_secret_key';
        }
    }
    
    /**
     * 生成JWT令牌
     *
     * @param array $payload 载荷数据
     * @param int $expire 过期时间（秒）
     * @return string JWT令牌
     */
    public function encode($payload, $expire = 604800) {
        $header = [
            'alg' => 'HS256',
            'typ' => 'JWT'
        ];
        
        // 添加过期时间
        $payload['iat'] = time();
        $payload['exp'] = time() + $expire;
        
        // Base64编码头部
        $header_encoded = $this->base64UrlEncode(json_encode($header));
        
        // Base64编码载荷
        $payload_encoded = $this->base64UrlEncode(json_encode($payload));
        
        // 生成签名
        $signature = hash_hmac('sha256', $header_encoded . '.' . $payload_encoded, $this->secret, true);
        $signature_encoded = $this->base64UrlEncode($signature);
        
        // 组合JWT令牌
        return $header_encoded . '.' . $payload_encoded . '.' . $signature_encoded;
    }
    
    /**
     * 验证JWT令牌
     *
     * @param string $token JWT令牌
     * @return array 载荷数据
     * @throws Exception 验证失败时抛出异常
     */
    public function decode($token) {
        // 分割令牌
        $parts = explode('.', $token);
        
        if (count($parts) != 3) {
            throw new Exception('无效的令牌格式');
        }
        
        list($header_encoded, $payload_encoded, $signature_encoded) = $parts;
        
        // 验证签名
        $signature = $this->base64UrlDecode($signature_encoded);
        $expected_signature = hash_hmac('sha256', $header_encoded . '.' . $payload_encoded, $this->secret, true);
        
        if (!hash_equals($signature, $expected_signature)) {
            throw new Exception('签名验证失败');
        }
        
        // 解码载荷
        $payload = json_decode($this->base64UrlDecode($payload_encoded), true);
        
        // 验证过期时间
        if (isset($payload['exp']) && $payload['exp'] < time()) {
            throw new Exception('登录已过期');
        }
        
        return $payload;
    }
    
    /**
     * Base64 URL 编码
     *
     * @param string $data 待编码数据
     * @return string 编码后的字符串
     */
    private function base64UrlEncode($data) {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
    
    /**
     * Base64 URL 解码
     *
     * @param string $data 待解码数据
     * @return string 解码后的字符串
     */
    private function base64UrlDecode($data) {
        return base64_decode(strtr($data, '-_', '+/'));
    }
}
