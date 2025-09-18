<?php
/**
 * 用户控制器
 * 
 * 处理用户相关的API请求，包括注册、登录、收藏、历史等
 * 
 * @author ovo
 * @version 1.0.3
 * @date 2025-05-20
 */

class UserController {
    /**
     * 数据库连接
     * @var PDO
     */
    private $db;
    
    /**
     * JWT工具类
     * @var JWT
     */
    private $jwt;
    
    /**
     * 构造函数
     * 
     * @param PDO $db 数据库连接
     */
    public function __construct($db) {
        $this->db = $db;
        $this->jwt = new JWT();
    }
    
    /**
     * 用户注册
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function register($params) {
        global $pdo;
        
        // 验证必填参数
        if (empty($params['username']) || empty($params['password'])) {
            response_error(400, '用户名和密码不能为空');
        }
        
        // 🔧 添加验证码验证
        if (empty($params['captcha']) || empty($params['captcha_id'])) {
            response_error(400, '验证码不能为空');
        }
        
        // 验证验证码
        $captcha = strtolower(trim($params['captcha']));
        $captcha_id = trim($params['captcha_id']);
        
        try {
            // 从数据库查询验证码
            $captcha_sql = "SELECT captcha_code, expire_time FROM " . DB_PREFIX . "captcha WHERE captcha_id = ? AND expire_time > ?";
            $captcha_stmt = $pdo->prepare($captcha_sql);
            $captcha_stmt->execute([$captcha_id, time()]);
            
            if ($captcha_stmt->rowCount() == 0) {
                response_error(400, '验证码已失效，请刷新后重试');
            }
            
            $captcha_data = $captcha_stmt->fetch(PDO::FETCH_ASSOC);
            $stored_captcha = strtolower(trim($captcha_data['captcha_code']));
            
            if ($captcha !== $stored_captcha) {
                response_error(400, '验证码错误');
            }
            
            // 删除已使用的验证码
            $delete_sql = "DELETE FROM " . DB_PREFIX . "captcha WHERE captcha_id = ?";
            $delete_stmt = $pdo->prepare($delete_sql);
            $delete_stmt->execute([$captcha_id]);
        } catch (Exception $e) {
            response_error(500, '验证码验证失败');
        }
        
        // 验证用户名格式（只允许字母、数字和下划线，长度3-20）
        if (!preg_match('/^\w{3,20}$/', $params['username'])) {
            response_error(400, '用户名格式不正确，只允许字母、数字和下划线，长度3-20');
        }
        
        // 验证密码长度（至少6位）
        if (strlen($params['password']) < 6) {
            response_error(400, '密码长度不能少于6位');
        }
        
        // 检查用户名是否已存在
        $check_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "user WHERE user_name = :username";
        $stmt = $this->db->prepare($check_sql);
        $stmt->bindParam(':username', $params['username']);
        $stmt->execute();
        
        if ($stmt->fetchColumn() > 0) {
            response_error(400, '用户名已存在');
        }
        
        // 检查MacCMS会员表中是否已存在同名用户
        $check_mac_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "user WHERE user_name = :username";
        $stmt = $this->db->prepare($check_mac_sql);
        $stmt->bindParam(':username', $params['username']);
        $stmt->execute();
        
        if ($stmt->fetchColumn() > 0) {
            response_error(400, '用户名已存在于MacCMS会员系统');
        }
        
        // 准备用户数据
        $now = date('Y-m-d H:i:s');
        $password_md5 = md5($params['password']);
        $nickname = isset($params['nickname']) ? $params['nickname'] : $params['username'];
        $email = isset($params['email']) ? $params['email'] : '';
        $phone = isset($params['phone']) ? $params['phone'] : '';
        $avatar = isset($params['avatar']) ? $params['avatar'] : '';
        $user_qq = isset($params['user_qq']) ? $params['user_qq'] : '';
        $group_id = 2;
        $user_status = 1;
        $user_reg_time = time();
        $user_reg_ip = ip2long($_SERVER['REMOTE_ADDR']);
        
        try {
            $insert_sql = "INSERT INTO " . DB_PREFIX . "user 
                (group_id, user_name, user_pwd, user_nick_name, user_qq, user_email, user_phone, user_status, user_portrait, user_reg_time, user_reg_ip) 
                VALUES 
                (:group_id, :user_name, :user_pwd, :user_nick_name, :user_qq, :user_email, :user_phone, :user_status, :user_portrait, :user_reg_time, :user_reg_ip)";
            $stmt = $this->db->prepare($insert_sql);
            $stmt->bindParam(':group_id', $group_id, PDO::PARAM_INT);
            $stmt->bindParam(':user_name', $params['username']);
            $stmt->bindParam(':user_pwd', $password_md5);
            $stmt->bindParam(':user_nick_name', $nickname);
            $stmt->bindParam(':user_qq', $user_qq);
            $stmt->bindParam(':user_email', $email);
            $stmt->bindParam(':user_phone', $phone);
            $stmt->bindParam(':user_status', $user_status, PDO::PARAM_INT);
            $stmt->bindParam(':user_portrait', $avatar);
            $stmt->bindParam(':user_reg_time', $user_reg_time, PDO::PARAM_INT);
            $stmt->bindParam(':user_reg_ip', $user_reg_ip, PDO::PARAM_INT);
            $stmt->execute();
            $user_id = $this->db->lastInsertId();
            response_success([
                'user_id' => $user_id,
                'username' => $params['username'],
                'nickname' => $nickname,
                'avatar' => $avatar,
                'user_qq' => $user_qq
            ]);
        } catch (Exception $e) {
            response_error(500, '注册失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 用户登录
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function login($params) {
        // 验证必填参数
        if (empty($params['username']) || empty($params['password'])) {
            response_error(400, '用户名和密码不能为空');
        }
        
        // 验证验证码
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
            $stmt = $this->db->prepare($sql);
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
                $delete_stmt = $this->db->prepare($delete_sql);
                $delete_stmt->execute([$captcha_id]);
                
                response_error(400, '验证码已过期，请刷新后重试');
            }
            
            // 验证验证码
            if ($input_captcha !== $captcha_record['captcha_code']) {
                response_error(400, '验证码错误');
            }
            
            // 验证成功，删除已使用的验证码
            $delete_sql = "DELETE FROM " . DB_PREFIX . "captcha WHERE captcha_id = ?";
            $delete_stmt = $this->db->prepare($delete_sql);
            $delete_stmt->execute([$captcha_id]);
            
        } catch (Exception $e) {
            response_error(400, '验证码验证失败，请重试');
        }
        
        // 查询用户信息
        $sql = "SELECT * FROM " . DB_PREFIX . "user WHERE user_name = :username AND user_status = 1";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':username', $params['username']);
        $stmt->execute();
        
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        // 验证用户是否存在
        if (!$user) {
            response_error(401, '用户名或密码错误');
        }
        
        // 验证密码
        if (md5($params['password']) !== $user['user_pwd']) {
            response_error(401, '用户名或密码错误');
        }
        
        // 生成token
        $payload = [
            'user_id' => $user['user_id'],
            'username' => $user['user_name'],
            'exp' => time() + 604800 // 7天过期
        ];
        
        $token = $this->jwt->encode($payload);
        
        // 生成refresh_token
        $refresh_token = md5(uniqid() . $user['user_id'] . time());
        $device_id = isset($params['device_id']) ? $params['device_id'] : '';
        $expire_time = date('Y-m-d H:i:s', time() + 30 * 24 * 3600); // 30天过期
        $now = date('Y-m-d H:i:s');
        
        // 更新或插入refresh_token
        $check_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "ovo_user_token WHERE user_id = :user_id AND device_id = :device_id";
        $stmt = $this->db->prepare($check_sql);
        $stmt->bindParam(':user_id', $user['user_id']);
        $stmt->bindParam(':device_id', $device_id);
        $stmt->execute();
        
        try {
            // 开始事务
            $this->db->beginTransaction();
            
            if ($stmt->fetchColumn() > 0) {
                // 更新refresh_token
                $update_sql = "UPDATE " . DB_PREFIX . "ovo_user_token 
                    SET refresh_token = :refresh_token, expire_time = :expire_time, update_time = :update_time 
                    WHERE user_id = :user_id AND device_id = :device_id";
                
                $stmt = $this->db->prepare($update_sql);
                $stmt->bindParam(':refresh_token', $refresh_token);
                $stmt->bindParam(':expire_time', $expire_time);
                $stmt->bindParam(':update_time', $now);
                $stmt->bindParam(':user_id', $user['user_id']);
                $stmt->bindParam(':device_id', $device_id);
                $stmt->execute();
            } else {
                // 插入refresh_token
                $insert_sql = "INSERT INTO " . DB_PREFIX . "ovo_user_token 
                    (user_id, refresh_token, device_id, expire_time, create_time) 
                    VALUES 
                    (:user_id, :refresh_token, :device_id, :expire_time, :create_time)";
                
                $stmt = $this->db->prepare($insert_sql);
                $stmt->bindParam(':user_id', $user['user_id']);
                $stmt->bindParam(':refresh_token', $refresh_token);
                $stmt->bindParam(':device_id', $device_id);
                $stmt->bindParam(':expire_time', $expire_time);
                $stmt->bindParam(':create_time', $now);
                $stmt->execute();
            }
            
            // 更新用户最后登录时间和IP
            $user_login_time = time();
            $user_login_ip = ip2long($_SERVER['REMOTE_ADDR']);
            
            $update_user_sql = "UPDATE " . DB_PREFIX . "user 
                SET user_login_time = :user_login_time, user_login_ip = :user_login_ip 
                WHERE user_id = :user_id";
            
            $stmt = $this->db->prepare($update_user_sql);
            $stmt->bindParam(':user_login_time', $user_login_time, PDO::PARAM_INT);
            $stmt->bindParam(':user_login_ip', $user_login_ip, PDO::PARAM_INT);
            $stmt->bindParam(':user_id', $user['user_id']);
            $stmt->execute();
            
            // 同步更新MacCMS会员表的登录信息
            $current_time = time();
            $ip = ip2long($_SERVER['REMOTE_ADDR']);
            
            // 先检查MacCMS会员表中是否存在该用户
            $check_mac_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "user WHERE user_id = :user_id";
            $stmt = $this->db->prepare($check_mac_sql);
            $stmt->bindParam(':user_id', $user['user_id']);
            $stmt->execute();
            
            if ($stmt->fetchColumn() > 0) {
                // 更新MacCMS会员表的登录信息
                $update_mac_sql = "UPDATE " . DB_PREFIX . "user 
                    SET user_login_time = :user_login_time,
                        user_login_ip = :user_login_ip,
                        user_login_num = user_login_num + 1
                    WHERE user_id = :user_id";
                
                $stmt = $this->db->prepare($update_mac_sql);
                $stmt->bindParam(':user_login_time', $current_time);
                $stmt->bindParam(':user_login_ip', $ip);
                $stmt->bindParam(':user_id', $user['user_id']);
                $stmt->execute();
            } else {
                // 如果MacCMS会员表中不存在该用户，则创建一个
                $insert_mac_sql = "INSERT INTO " . DB_PREFIX . "user 
                    (user_id, group_id, user_name, user_pwd, user_nick_name, user_email, user_phone, 
                    user_status, user_points, user_reg_time, user_reg_ip, user_login_time, user_login_ip) 
                    VALUES 
                    (:user_id, 2, :user_name, :user_pwd, :user_nick_name, :user_email, :user_phone, 
                    :user_status, 0, :user_reg_time, :user_reg_ip, :user_login_time, :user_login_ip)";
                
                $stmt = $this->db->prepare($insert_mac_sql);
                $stmt->bindParam(':user_id', $user['user_id']);
                $stmt->bindParam(':user_name', $user['user_name']);
                $stmt->bindParam(':user_pwd', $user['user_pwd']);
                $stmt->bindParam(':user_nick_name', $user['user_nick_name']);
                $stmt->bindParam(':user_email', $user['user_email']);
                $stmt->bindParam(':user_phone', $user['user_phone']);
                $stmt->bindParam(':user_status', $user['user_status']);
                $stmt->bindParam(':user_reg_time', $current_time);
                $stmt->bindParam(':user_reg_ip', $ip);
                $stmt->bindParam(':user_login_time', $current_time);
                $stmt->bindParam(':user_login_ip', $ip);
                $stmt->execute();
            }
            
            // 提交事务
            $this->db->commit();
            
            // 返回成功响应
            $isvip = (isset($user['group_id']) && $user['group_id'] == 3) ? true : false;
            $xp = isset($user['xp']) ? intval($user['xp']) : 0;
            response_success([
                'user_id' => $user['user_id'],
                'username' => $user['user_name'],
                'nickname' => $user['user_nick_name'],
                'avatar' => isset($user['user_portrait']) ? $user['user_portrait'] : '',
                'user_qq' => isset($user['user_qq']) ? $user['user_qq'] : '',
                'token' => $token,
                'refresh_token' => $refresh_token,
                'expire_time' => time() + 604800,
                'isvip' => $isvip,
                'xp' => $xp
            ]);
            
        } catch (Exception $e) {
            // 回滚事务
            $this->db->rollBack();
            response_error(500, '登录失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 刷新令牌
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function refreshToken($params) {
        // 验证必填参数
        if (empty($params['refresh_token'])) {
            response_error(400, 'refresh_token不能为空');
        }
        
        // 查询refresh_token
        $sql = "SELECT t.*, u.user_name, u.user_nick_name, u.user_portrait, u.user_qq, u.group_id, u.xp, u.user_end_time 
            FROM " . DB_PREFIX . "ovo_user_token t 
            LEFT JOIN " . DB_PREFIX . "user u ON t.user_id = u.user_id 
            WHERE t.refresh_token = :refresh_token AND u.user_status = 1";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':refresh_token', $params['refresh_token']);
        $stmt->execute();
        $token_info = $stmt->fetch(PDO::FETCH_ASSOC);
        // 验证refresh_token是否存在
        if (!$token_info) {
            response_error(401, 'refresh_token无效');
        }
        // 验证refresh_token是否过期
        if (strtotime($token_info['expire_time']) < time()) {
            response_error(401, 'refresh_token已过期，请重新登录');
        }
        // 生成新的token
        $payload = [
            'user_id' => $token_info['user_id'],
            'username' => $token_info['user_name'],
            'exp' => time() + 604800 // 7天过期
        ];
        $token = $this->jwt->encode($payload);
        // 生成新的refresh_token
        $refresh_token = md5(uniqid() . $token_info['user_id'] . time());
        $expire_time = date('Y-m-d H:i:s', time() + 30 * 24 * 3600); // 30天过期
        $now = date('Y-m-d H:i:s');
        // 更新refresh_token
        $update_sql = "UPDATE " . DB_PREFIX . "ovo_user_token 
            SET refresh_token = :refresh_token, expire_time = :expire_time, update_time = :update_time 
            WHERE id = :id";
        $stmt = $this->db->prepare($update_sql);
        $stmt->bindParam(':refresh_token', $refresh_token);
        $stmt->bindParam(':expire_time', $expire_time);
        $stmt->bindParam(':update_time', $now);
        $stmt->bindParam(':id', $token_info['id']);
        $stmt->execute();
        // 判断VIP（假设group_id=3为VIP，可根据实际调整）
        $isvip = (isset($token_info['group_id']) && $token_info['group_id'] == 3) ? true : false;
        $xp = isset($token_info['xp']) ? intval($token_info['xp']) : 0;
        $user_end_time = isset($token_info['user_end_time']) ? $token_info['user_end_time'] : null;
        // 返回成功响应
        response_success([
            'user_id' => $token_info['user_id'],
            'username' => $token_info['user_name'],
            'nickname' => $token_info['user_nick_name'],
            'avatar' => isset($token_info['user_portrait']) ? $token_info['user_portrait'] : '',
            'user_qq' => isset($token_info['user_qq']) ? $token_info['user_qq'] : '',
            'token' => $token,
            'refresh_token' => $refresh_token,
            'expire_time' => time() + 604800,
            'isvip' => $isvip,
            'xp' => $xp,
            'user_end_time' => $user_end_time
        ]);
    }
    
    /**
     * 获取用户信息
     * 
     * @param int $user_id 用户ID
     * @return void
     */
    public function getProfile($user_id) {
        // 查询用户信息
        $sql = "SELECT u.user_id, u.user_name, u.user_nick_name, u.user_portrait, u.user_email, u.user_reg_time, 
                m.user_points, m.group_id, m.xp, m.user_end_time
            FROM " . DB_PREFIX . "user u
            LEFT JOIN " . DB_PREFIX . "user m ON u.user_id = m.user_id
            WHERE u.user_id = :user_id AND u.user_status = 1";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->execute();
        
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        // 验证用户是否存在
        if (!$user) {
            response_error(404, '用户不存在');
        }
        
        // 判断VIP（假设group_id=3为VIP，可根据实际调整）
        $isvip = ($user['group_id'] == 3) ? true : false;
        $xp = isset($user['xp']) ? intval($user['xp']) : 0;
        $user_end_time = isset($user['user_end_time']) ? $user['user_end_time'] : null;
        
        // 返回成功响应
        response_success([
            'user_id' => $user['user_id'],
            'username' => $user['user_name'],
            'nickname' => $user['user_nick_name'],
            'avatar' => isset($user['user_portrait']) ? $user['user_portrait'] : '',
            'email' => $user['user_email'],
            'create_time' => $user['user_reg_time'],
            'user_points' => $user['user_points'],
            'group_id' => $user['group_id'],
            'isvip' => $isvip,
            'xp' => $xp,
            'user_end_time' => $user_end_time
        ]);
    }
    
    /**
     * 获取收藏列表
     * 
     * @param int $user_id 用户ID
     * @param array $params 请求参数
     * @return void
     */
    public function getFavorites($user_id, $params) {
        // 分页参数
        $page = isset($params['page']) ? intval($params['page']) : 1;
        $limit = isset($params['limit']) ? intval($params['limit']) : 20;
        $offset = ($page - 1) * $limit;
        
        // 查询收藏总数
        $count_sql = "SELECT COUNT(*) 
            FROM " . DB_PREFIX . "ovo_favorite f 
            WHERE f.user_id = :user_id";
        
        $stmt = $this->db->prepare($count_sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->execute();
        
        $total = $stmt->fetchColumn();
        
        // 查询收藏列表
        $sql = "SELECT f.favorite_id, f.user_id, f.vod_id, f.create_time, 
                v.vod_name, v.vod_pic, v.vod_remarks, v.vod_score, v.type_id 
            FROM " . DB_PREFIX . "ovo_favorite f 
            LEFT JOIN " . DB_PREFIX . "vod v ON f.vod_id = v.vod_id 
            WHERE f.user_id = :user_id 
            ORDER BY f.create_time DESC 
            LIMIT :offset, :limit";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
        $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        
        $favorites = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // 返回成功响应
        response_success([
            'total' => $total,
            'page' => $page,
            'limit' => $limit,
            'list' => $favorites
        ]);
    }
    
    /**
     * 添加收藏
     * 
     * @param int $user_id 用户ID
     * @param array $params 请求参数
     * @return void
     */
    public function addFavorite($user_id, $params) {
        // 验证必填参数
        if (empty($params['vod_id'])) {
            response_error(400, '视频ID不能为空');
        }
        
        $vod_id = intval($params['vod_id']);
        
        // 检查视频是否存在
        $check_vod_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "vod WHERE vod_id = :vod_id";
        $stmt = $this->db->prepare($check_vod_sql);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->execute();
        
        if ($stmt->fetchColumn() == 0) {
            response_error(404, '视频不存在');
        }
        
        // 检查是否已收藏
        $check_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "ovo_favorite WHERE user_id = :user_id AND vod_id = :vod_id";
        $stmt = $this->db->prepare($check_sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->execute();
        
        if ($stmt->fetchColumn() > 0) {
            response_error(400, '已经收藏过该视频');
        }
        
        // 添加收藏
        $now = date('Y-m-d H:i:s');
        
        $insert_sql = "INSERT INTO " . DB_PREFIX . "ovo_favorite 
            (user_id, vod_id, create_time) 
            VALUES 
            (:user_id, :vod_id, :create_time)";
        
        $stmt = $this->db->prepare($insert_sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->bindParam(':create_time', $now);
        $stmt->execute();
        
        // 返回成功响应
        response_success([
            'favorite_id' => $this->db->lastInsertId(),
            'user_id' => $user_id,
            'vod_id' => $vod_id,
            'create_time' => $now
        ]);
    }
    
    /**
     * 删除收藏
     * 
     * @param int $user_id 用户ID
     * @param int $vod_id 视频ID
     * @return void
     */
    public function deleteFavorite($user_id, $vod_id) {
        // 检查收藏是否存在
        $check_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "ovo_favorite WHERE user_id = :user_id AND vod_id = :vod_id";
        $stmt = $this->db->prepare($check_sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->execute();
        
        if ($stmt->fetchColumn() == 0) {
            response_error(404, '收藏不存在');
        }
        
        // 删除收藏
        $delete_sql = "DELETE FROM " . DB_PREFIX . "ovo_favorite WHERE user_id = :user_id AND vod_id = :vod_id";
        $stmt = $this->db->prepare($delete_sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->execute();
        
        // 返回成功响应
        response_success(null);
    }
    
    /**
     * 获取播放历史
     * 
     * @param int $user_id 用户ID
     * @param array $params 请求参数
     * @return void
     */
    public function getHistory($user_id, $params) {
        // 分页参数
        $page = isset($params['page']) ? intval($params['page']) : 1;
        $limit = isset($params['limit']) ? intval($params['limit']) : 20;
        $offset = ($page - 1) * $limit;
        
        // 查询历史总数
        $count_sql = "SELECT COUNT(*) 
            FROM " . DB_PREFIX . "ovo_history h 
            WHERE h.user_id = :user_id";
        
        $stmt = $this->db->prepare($count_sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->execute();
        
        $total = $stmt->fetchColumn();
        
        // 查询历史列表
        $sql = "SELECT h.history_id, h.user_id, h.vod_id, h.episode_index, h.play_source, h.play_url, h.play_progress, h.create_time, h.update_time, 
                v.vod_name, v.vod_pic, v.vod_remarks, v.vod_score, v.type_id, v.vod_time 
            FROM " . DB_PREFIX . "ovo_history h 
            LEFT JOIN " . DB_PREFIX . "vod v ON h.vod_id = v.vod_id 
            WHERE h.user_id = :user_id 
            ORDER BY h.update_time DESC 
            LIMIT :offset, :limit";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
        $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        
        $history = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // 返回成功响应
        response_success([
            'total' => $total,
            'page' => $page,
            'limit' => $limit,
            'list' => $history
        ]);
    }
    
    /**
     * 添加播放历史
     * 
     * @param int $user_id 用户ID
     * @param array $params 请求参数
     * @return void
     */
    public function addHistory($user_id, $params) {
        // 验证必填参数
        if (empty($params['vod_id'])) {
            response_error(400, '视频ID不能为空');
        }
        
        $vod_id = intval($params['vod_id']);
        $play_source = isset($params['play_source']) ? $params['play_source'] : '';
        $play_url = isset($params['play_url']) ? $params['play_url'] : '';
        $play_progress = isset($params['play_progress']) ? intval($params['play_progress']) : 0;
        $episode_index = isset($params['episode_index']) ? intval($params['episode_index']) : 0;
        
        // 检查视频是否存在
        $check_vod_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "vod WHERE vod_id = :vod_id";
        $stmt = $this->db->prepare($check_vod_sql);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->execute();
        
        if ($stmt->fetchColumn() == 0) {
            response_error(404, '视频不存在');
        }
        
        // 检查是否已有历史记录
        $check_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "ovo_history WHERE user_id = :user_id AND vod_id = :vod_id";
        $stmt = $this->db->prepare($check_sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->execute();
        
        $now = date('Y-m-d H:i:s');
        
        if ($stmt->fetchColumn() > 0) {
            // 更新历史记录
            $update_sql = "UPDATE " . DB_PREFIX . "ovo_history 
                SET play_source = :play_source, play_url = :play_url, play_progress = :play_progress, episode_index = :episode_index, update_time = :update_time 
                WHERE user_id = :user_id AND vod_id = :vod_id";
            
            $stmt = $this->db->prepare($update_sql);
            $stmt->bindParam(':play_source', $play_source);
            $stmt->bindParam(':play_url', $play_url);
            $stmt->bindParam(':play_progress', $play_progress);
            $stmt->bindParam(':episode_index', $episode_index, PDO::PARAM_INT);
            $stmt->bindParam(':update_time', $now);
            $stmt->bindParam(':user_id', $user_id);
            $stmt->bindParam(':vod_id', $vod_id);
            $stmt->execute();
            
            // 查询历史记录ID
            $query_sql = "SELECT history_id FROM " . DB_PREFIX . "ovo_history WHERE user_id = :user_id AND vod_id = :vod_id";
            $stmt = $this->db->prepare($query_sql);
            $stmt->bindParam(':user_id', $user_id);
            $stmt->bindParam(':vod_id', $vod_id);
            $stmt->execute();
            
            $history_id = $stmt->fetchColumn();
        } else {
            // 添加历史记录
            $insert_sql = "INSERT INTO " . DB_PREFIX . "ovo_history 
                (user_id, vod_id, episode_index, play_source, play_url, play_progress, create_time, update_time) 
                VALUES 
                (:user_id, :vod_id, :episode_index, :play_source, :play_url, :play_progress, :create_time, :update_time)";
            
            $stmt = $this->db->prepare($insert_sql);
            $stmt->bindParam(':user_id', $user_id);
            $stmt->bindParam(':vod_id', $vod_id);
            $stmt->bindParam(':episode_index', $episode_index, PDO::PARAM_INT);
            $stmt->bindParam(':play_source', $play_source);
            $stmt->bindParam(':play_url', $play_url);
            $stmt->bindParam(':play_progress', $play_progress);
            $stmt->bindParam(':create_time', $now);
            $stmt->bindParam(':update_time', $now);
            $stmt->execute();
            
            $history_id = $this->db->lastInsertId();
        }
        
        // 返回成功响应
        response_success([
            'history_id' => $history_id,
            'user_id' => $user_id,
            'vod_id' => $vod_id,
            'episode_index' => $episode_index,
            'play_source' => $play_source,
            'play_url' => $play_url,
            'play_progress' => $play_progress,
            'update_time' => $now
        ]);
    }
    
    /**
     * 删除播放历史
     * 
     * @param int $user_id 用户ID
     * @param int $vod_id 视频ID
     * @return void
     */
    public function deleteHistory($user_id, $vod_id) {
        // 检查历史记录是否存在
        $check_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "ovo_history WHERE user_id = :user_id AND vod_id = :vod_id";
        $stmt = $this->db->prepare($check_sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->execute();
        
        if ($stmt->fetchColumn() == 0) {
            response_error(404, '历史记录不存在');
        }
        
        // 删除历史记录
        $delete_sql = "DELETE FROM " . DB_PREFIX . "ovo_history WHERE user_id = :user_id AND vod_id = :vod_id";
        $stmt = $this->db->prepare($delete_sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->execute();
        
        // 返回成功响应
        response_success(null);
    }
    
    /**
     * 删除全部播放历史
     * 
     * @param int $user_id 用户ID
     * @return void
     */
    public function deleteAllHistory($user_id) {
        // 检查是否有历史记录
        $check_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "ovo_history WHERE user_id = :user_id";
        $stmt = $this->db->prepare($check_sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->execute();
        if ($stmt->fetchColumn() == 0) {
            response_error(404, '没有历史记录');
        }
        // 删除全部历史记录
        $delete_sql = "DELETE FROM " . DB_PREFIX . "ovo_history WHERE user_id = :user_id";
        $stmt = $this->db->prepare($delete_sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->execute();
        response_success(null);
    }

    /**
     * 用户点赞或取消点赞视频
     * @param int $user_id 用户ID（通过token获取）
     * @param array $params 请求参数，包含vod_id和dianzan（true/false）
     * @return void
     */
    public function likeVod($user_id, $params) {
        if (empty($params['vod_id']) || !isset($params['dianzan'])) {
            response_error(400, '缺少必要参数');
        }
        $vod_id = intval($params['vod_id']);
        $dianzan = filter_var($params['dianzan'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($dianzan === null) {
            response_error(400, 'dianzan参数必须为true或false');
        }
        // 检查视频是否存在
        $check_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "vod WHERE vod_id = :vod_id";
        $stmt = $this->db->prepare($check_sql);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->execute();
        if ($stmt->fetchColumn() == 0) {
            response_error(404, '视频不存在');
        }
        // 查询是否已有点赞记录
        $check_like_sql = "SELECT zan FROM mac_ovo_like WHERE vod_id = :vod_id AND user_id = :user_id";
        $stmt = $this->db->prepare($check_like_sql);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->execute();
        $like = $stmt->fetch(PDO::FETCH_ASSOC);
        try {
            $this->db->beginTransaction();
            if ($like) {
                // 已有记录，更新zan
                $update_like_sql = "UPDATE mac_ovo_like SET zan = :zan WHERE vod_id = :vod_id AND user_id = :user_id";
                $stmt = $this->db->prepare($update_like_sql);
                $stmt->bindParam(':zan', $dianzan, PDO::PARAM_BOOL);
                $stmt->bindParam(':vod_id', $vod_id);
                $stmt->bindParam(':user_id', $user_id);
                $stmt->execute();
                // 只在状态变化时更新vod_up
                if ($like['zan'] != $dianzan) {
                    $vod_up_sql = $dianzan ?
                        "UPDATE " . DB_PREFIX . "vod SET vod_up = vod_up + 1 WHERE vod_id = :vod_id" :
                        "UPDATE " . DB_PREFIX . "vod SET vod_up = IF(vod_up>0, vod_up-1, 0) WHERE vod_id = :vod_id";
                    $stmt = $this->db->prepare($vod_up_sql);
                    $stmt->bindParam(':vod_id', $vod_id);
                    $stmt->execute();
                }
            } else {
                // 新增点赞记录
                $insert_like_sql = "INSERT INTO mac_ovo_like (vod_id, user_id, zan) VALUES (:vod_id, :user_id, :zan)";
                $stmt = $this->db->prepare($insert_like_sql);
                $stmt->bindParam(':vod_id', $vod_id);
                $stmt->bindParam(':user_id', $user_id);
                $stmt->bindParam(':zan', $dianzan, PDO::PARAM_BOOL);
                $stmt->execute();
                // 点赞才+1
                if ($dianzan) {
                    $vod_up_sql = "UPDATE " . DB_PREFIX . "vod SET vod_up = vod_up + 1 WHERE vod_id = :vod_id";
                    $stmt = $this->db->prepare($vod_up_sql);
                    $stmt->bindParam(':vod_id', $vod_id);
                    $stmt->execute();
                }
            }
            $this->db->commit();
            // 再查一次数据库当前zan状态
            $stmt = $this->db->prepare("SELECT zan FROM mac_ovo_like WHERE vod_id = :vod_id AND user_id = :user_id");
            $stmt->bindParam(':vod_id', $vod_id);
            $stmt->bindParam(':user_id', $user_id);
            $stmt->execute();
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            $zan = ($row && $row['zan']) ? true : false;
            // 查询当前视频的赞数量
            $stmt = $this->db->prepare("SELECT vod_up FROM " . DB_PREFIX . "vod WHERE vod_id = :vod_id");
            $stmt->bindParam(':vod_id', $vod_id);
            $stmt->execute();
            $vod_up = (int)$stmt->fetchColumn();
            echo json_encode(['code' => 200, 'zan' => $zan, 'vod_up' => $vod_up], JSON_UNESCAPED_UNICODE);exit;
        } catch (Exception $e) {
            $this->db->rollBack();
            response_error(500, '操作失败: ' . $e->getMessage());
        }
    }

    /**
     * 查询用户是否已点赞某视频
     * @param int $user_id 用户ID（通过token获取）
     * @param array $params 请求参数，包含vod_id
     * @return void
     */
    public function isLiked($user_id, $params) {
        if (empty($params['vod_id'])) {
            response_error(400, '缺少vod_id参数');
        }
        $vod_id = intval($params['vod_id']);
        $sql = "SELECT zan FROM mac_ovo_like WHERE vod_id = :vod_id AND user_id = :user_id";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->execute();
        $like = $stmt->fetch(PDO::FETCH_ASSOC);
        $liked = ($like && $like['zan']) ? true : false;
        response_success(['vod_id' => $vod_id, 'liked' => $liked]);
    }

    /**
     * 查询用户是否收藏某视频
     * @param int $user_id 用户ID（通过token获取）
     * @param array $params 请求参数，包含vod_id
     * @return void
     */
    public function isFavorite($user_id, $params) {
        if (empty($params['vod_id'])) {
            response_error(400, '缺少vod_id参数');
        }
        $vod_id = intval($params['vod_id']);
        $sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "ovo_favorite WHERE user_id = :user_id AND vod_id = :vod_id";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->execute();
        $favorites = $stmt->fetchColumn() > 0 ? true : false;
        echo json_encode(['code' => 200, 'favorites' => $favorites], JSON_UNESCAPED_UNICODE);exit;
    }

    /**
     * 发送弹幕
     * @param int $user_id 用户ID（token获取）
     * @param array $params 请求参数
     * @return void
     */
    public function sendDanmaku($user_id, $params) {
        if (empty($params['vod_id']) || !isset($params['time']) || empty($params['content']) || empty($params['color']) || empty($params['position'])) {
            response_error(400, '缺少必要参数');
        }
        $vod_id = intval($params['vod_id']);
        $episode_index = isset($params['episode_index']) ? intval($params['episode_index']) : 0;
        $time = floatval($params['time']);
        $content = trim($params['content']);
        $color = $params['color'];
        $position = $params['position'];
        if (!in_array($position, ['right', 'top', 'bottom'])) {
            response_error(400, '位置参数错误');
        }
        // 检查视频是否存在
        $check_sql = "SELECT COUNT(*) FROM " . DB_PREFIX . "vod WHERE vod_id = :vod_id";
        $stmt = $this->db->prepare($check_sql);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->execute();
        if ($stmt->fetchColumn() == 0) {
            response_error(404, '视频不存在');
        }
        // 插入弹幕
        $insert_sql = "INSERT INTO mac_ovo_danmaku (vod_id, episode_index, user_id, content, color, position, time, create_time) VALUES (:vod_id, :episode_index, :user_id, :content, :color, :position, :time, NOW())";
        $stmt = $this->db->prepare($insert_sql);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->bindParam(':episode_index', $episode_index);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->bindParam(':content', $content);
        $stmt->bindParam(':color', $color);
        $stmt->bindParam(':position', $position);
        $stmt->bindParam(':time', $time);
        $stmt->execute();
        response_success('ok');
    }

    /**
     * 查询弹幕
     * @param array $params 请求参数
     * @return void
     */
    public function getDanmaku($params) {
        if (empty($params['vod_id'])) {
            response_error(400, '缺少vod_id参数');
        }
        $vod_id = intval($params['vod_id']);
        $episode_index = isset($params['episode_index']) ? intval($params['episode_index']) : 0;
        $sql = "SELECT time, position, color, content FROM mac_ovo_danmaku WHERE vod_id = :vod_id AND episode_index = :episode_index ORDER BY time ASC";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->bindParam(':episode_index', $episode_index);
        $stmt->execute();
        $danmaku = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $danmaku[] = [
                floatval($row['time']),
                $row['position'],
                $row['color'],
                "0",
                $row['content']
            ];
        }
        // 查询弹幕数量
        $count_sql = "SELECT COUNT(*) FROM mac_ovo_danmaku WHERE vod_id = :vod_id AND episode_index = :episode_index";
        $stmt = $this->db->prepare($count_sql);
        $stmt->bindParam(':vod_id', $vod_id);
        $stmt->bindParam(':episode_index', $episode_index);
        $stmt->execute();
        $danum = intval($stmt->fetchColumn());
        // 返回格式
        $result = [
            "code" => 23,
            "name" => strval($vod_id),
            "danum" => $danum,
            "danmuku" => $danmaku
        ];
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($result, JSON_UNESCAPED_UNICODE);exit;
    }

    /**
     * 获取经验等级表
     * 建议xp_lv表结构：id int(11)主键，lv int(11)等级，xp int(11)所需经验
     * @return void
     */
    public function getXpLevelTable() {
        $sql = "SELECT lv, xp FROM xp_lv ORDER BY lv ASC";
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        $levels = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $result = [];
        foreach ($levels as $row) {
            $result[(string)$row['lv']] = intval($row['xp']);
        }
        response_success($result);
    }

    /**
     * 通过token获取用户xp
     * @param int $user_id 用户ID（通过token获取）
     * @return void
     */
    public function getUserXp($user_id) {
        $sql = "SELECT xp FROM " . DB_PREFIX . "user WHERE user_id = :user_id";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->execute();
        $xp = $stmt->fetchColumn();
        response_success(['xp' => intval($xp)]);
    }

    /**
     * 修改用户昵称和QQ
     * @param int $user_id 用户ID（通过token获取）
     * @param array $params 请求参数
     * @return void
     */
    public function updateProfile($user_id, $params) {
        $nickname = isset($params['nickname']) ? trim($params['nickname']) : '';
        $user_qq = isset($params['user_qq']) ? trim($params['user_qq']) : '';
        $email = isset($params['email']) ? trim($params['email']) : '';
        
        if ($nickname === '' && $user_qq === '' && $email === '') {
            response_error(400, '没有需要修改的内容');
        }
        
        // 验证邮箱格式
        if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            response_error(400, '邮箱格式不正确');
        }
        
        $fields = [];
        $binds = [];
        
        if ($nickname !== '') {
            $fields[] = "user_nick_name = :nickname";
            $binds[':nickname'] = $nickname;
        }
        if ($user_qq !== '') {
            $fields[] = "user_qq = :user_qq";
            $binds[':user_qq'] = $user_qq;
            
            // 如果用户还没有自定义头像，自动缓存QQ头像
            $check_avatar_sql = "SELECT user_portrait FROM " . DB_PREFIX . "user WHERE user_id = :user_id";
            $stmt = $this->db->prepare($check_avatar_sql);
            $stmt->bindParam(':user_id', $user_id);
            $stmt->execute();
            $avatar_result = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($avatar_result && empty($avatar_result['user_portrait'])) {
                // 异步缓存QQ头像（不阻塞主流程）
                $this->cacheQQAvatar($user_id, $user_qq);
            }
        }
        if ($email !== '') {
            // 检查邮箱是否已被其他用户使用
            $check_email_sql = "SELECT user_id FROM " . DB_PREFIX . "user WHERE user_email = :email AND user_id != :user_id";
            $stmt = $this->db->prepare($check_email_sql);
            $stmt->bindParam(':email', $email);
            $stmt->bindParam(':user_id', $user_id);
            $stmt->execute();
            
            if ($stmt->fetch(PDO::FETCH_ASSOC)) {
                response_error(400, '该邮箱已被其他用户使用');
            }
            
            $fields[] = "user_email = :email";
            $binds[':email'] = $email;
        }
        
        $sql = "UPDATE " . DB_PREFIX . "user SET " . implode(', ', $fields) . " WHERE user_id = :user_id";
        $stmt = $this->db->prepare($sql);
        foreach ($binds as $k => $v) {
            $stmt->bindValue($k, $v);
        }
        $stmt->bindValue(':user_id', $user_id);
        $stmt->execute();
        
        // 查询最新信息
        $sql = "SELECT user_id, user_name, user_nick_name, user_qq, user_email, user_portrait FROM " . DB_PREFIX . "user WHERE user_id = :user_id";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->execute();
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        response_success($user);
    }

    /**
     * 上传头像
     * @param int $user_id 用户ID（通过token获取）
     * @return void
     */
    public function uploadAvatar($user_id) {
        if (!isset($_FILES['avatar']) || $_FILES['avatar']['error'] !== UPLOAD_ERR_OK) {
            response_error(400, '头像上传失败');
        }
        $file = $_FILES['avatar'];
        $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        if (!in_array($ext, ['jpg', 'jpeg', 'png', 'gif', 'webp'])) {
            response_error(400, '只允许jpg、jpeg、png、gif、webp格式');
        }
        
        // 检查文件大小（限制5MB）
        if ($file['size'] > 5 * 1024 * 1024) {
            response_error(400, '头像文件大小不能超过5MB');
        }
        
        $save_dir = __DIR__ . '/../../uploads/avatar/';
        if (!is_dir($save_dir)) {
            mkdir($save_dir, 0755, true);
        }
        
        // 删除用户之前的头像文件（清理旧文件）
        $this->deleteOldAvatar($user_id);
        
        $filename = 'avatar_' . $user_id . '_' . time() . '.' . $ext;
        $save_path = $save_dir . $filename;
        
        if (!move_uploaded_file($file['tmp_name'], $save_path)) {
            response_error(500, '头像保存失败');
        }
        
        $avatar_url = '/uploads/avatar/' . $filename;
        
        // 更新数据库
        $sql = "UPDATE " . DB_PREFIX . "user SET user_portrait = :avatar WHERE user_id = :user_id";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':avatar', $avatar_url);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->execute();
        
        // 查询最新信息
        $sql = "SELECT user_id, user_name, user_nick_name, user_qq, user_email, user_portrait FROM " . DB_PREFIX . "user WHERE user_id = :user_id";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->execute();
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        response_success($user);
    }

    /**
     * 缓存QQ头像到服务器
     * @param int $user_id 用户ID
     * @param string $qq QQ号
     * @return string|false 返回缓存的头像URL或false
     */
    private function cacheQQAvatar($user_id, $qq) {
        try {
            $qq_avatar_url = "https://q1.qlogo.cn/g?b=qq&nk={$qq}&s=100";
            $save_dir = __DIR__ . '/../../uploads/avatar/';
            
            if (!is_dir($save_dir)) {
                mkdir($save_dir, 0755, true);
            }
            
            // 检查是否已有缓存的QQ头像
            $cached_filename = 'qq_avatar_' . $user_id . '_' . $qq . '.jpg';
            $cached_path = $save_dir . $cached_filename;
            
            // 如果缓存文件存在且不超过7天，直接返回
            if (file_exists($cached_path) && (time() - filemtime($cached_path)) < 7 * 24 * 3600) {
                return '/uploads/avatar/' . $cached_filename;
            }
            
            // 下载QQ头像
            $context = stream_context_create([
                'http' => [
                    'timeout' => 10,
                    'user_agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                ]
            ]);
            
            $avatar_data = file_get_contents($qq_avatar_url, false, $context);
            
            if ($avatar_data === false) {
                return false;
            }
            
            // 保存到本地
            if (file_put_contents($cached_path, $avatar_data) === false) {
                return false;
            }
            
            $cached_url = '/uploads/avatar/' . $cached_filename;
            
            // 更新数据库中的头像路径
            $sql = "UPDATE " . DB_PREFIX . "user SET user_portrait = :avatar WHERE user_id = :user_id";
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':avatar', $cached_url);
            $stmt->bindParam(':user_id', $user_id);
            $stmt->execute();
            
            return $cached_url;
            
        } catch (Exception $e) {
            error_log("缓存QQ头像失败: " . $e->getMessage());
            return false;
        }
    }

    /**
     * 删除用户旧头像文件
     * @param int $user_id 用户ID
     */
    private function deleteOldAvatar($user_id) {
        try {
            // 查询当前头像路径
            $sql = "SELECT user_portrait FROM " . DB_PREFIX . "user WHERE user_id = :user_id";
            $stmt = $this->db->prepare($sql);
            $stmt->bindParam(':user_id', $user_id);
            $stmt->execute();
            $result = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($result && !empty($result['user_portrait'])) {
                $old_avatar = $result['user_portrait'];
                // 只删除uploads/avatar目录下的文件
                if (strpos($old_avatar, '/uploads/avatar/') === 0) {
                    $old_path = __DIR__ . '/../../' . $old_avatar;
                    if (file_exists($old_path)) {
                        unlink($old_path);
                    }
                }
            }
        } catch (Exception $e) {
            error_log("删除旧头像失败: " . $e->getMessage());
        }
    }

    /**
     * 手动缓存QQ头像（API接口）
     * @param int $user_id 用户ID
     * @param array $params 请求参数
     */
    public function cacheQQAvatarApi($user_id, $params) {
        // 获取用户信息
        $sql = "SELECT user_qq FROM " . DB_PREFIX . "user WHERE user_id = :user_id";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->execute();
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$user || empty($user['user_qq'])) {
            response_error(400, '用户未设置QQ号');
        }
        
        $cached_url = $this->cacheQQAvatar($user_id, $user['user_qq']);
        
        if ($cached_url === false) {
            response_error(500, 'QQ头像缓存失败');
        }
        
        // 查询最新用户信息
        $sql = "SELECT user_id, user_name, user_nick_name, user_qq, user_email, user_portrait FROM " . DB_PREFIX . "user WHERE user_id = :user_id";
        $stmt = $this->db->prepare($sql);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->execute();
        $updated_user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        response_success([
            'user' => $updated_user,
            'cached_avatar' => $cached_url,
            'message' => 'QQ头像缓存成功'
        ]);
    }
}
