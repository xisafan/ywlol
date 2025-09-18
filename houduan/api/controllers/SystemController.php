<?php
/**
 * 系统控制器
 * 
 * 处理系统相关的API请求
 * 
 * @author ovo
 * @version 1.0.0
 * @date 2025-05-20
 */

class SystemController {
    /**
     * 数据库连接
     * @var PDO
     */
    private $pdo;
    
    /**
     * 构造函数
     * 
     * @param PDO $pdo 数据库连接
     */
    public function __construct($pdo) {
        $this->pdo = $pdo;
    }
    
    /**
     * 获取公告列表
     * 
     * @return void
     */
    public function getAnnouncements() {
        try {
            // 查询公告列表
            $sql = "SELECT `id`, `title`, `content`, `is_force`, `create_time` 
                   FROM `" . DB_PREFIX . "ovo_announcement` 
                   WHERE `status` = 1 
                   ORDER BY `create_time` DESC";
            
            $stmt = $this->pdo->prepare($sql);
            $stmt->execute();
            $announcements = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // 返回公告列表
            $response_data = [
                'list' => $announcements
            ];
            
            response_success($response_data);
        } catch (Exception $e) {
            response_error(500, '获取公告列表失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 检查更新
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function checkUpdate($params) {
        // 验证参数
        if (!isset($params['platform']) || empty($params['platform'])) {
            response_error(400, '平台参数不能为空');
        }
        
        if (!isset($params['version']) || empty($params['version'])) {
            response_error(400, '版本号不能为空');
        }
        
        $platform = strtolower(trim($params['platform']));
        $current_version = trim($params['version']);
        
        // 验证平台参数
        $valid_platforms = ['android', 'ios', 'windows', 'linux'];
        if (!in_array($platform, $valid_platforms)) {
            response_error(400, '不支持的平台: ' . $platform);
        }
        
        try {
            // 查询最新版本
            $sql = "SELECT * FROM `" . DB_PREFIX . "ovo_setting` LIMIT 1";
            $stmt = $this->pdo->prepare($sql);
            $stmt->execute();
            $setting = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$setting) {
                response_error(500, '系统设置不存在');
            }
            
            // 获取对应平台的版本号
            $version_field = $platform . '_version';
            $latest_version = $setting[$version_field];
            
            // 比较版本号
            $has_update = version_compare($latest_version, $current_version, '>');
            
            // 返回更新信息
            $response_data = [
                'has_update' => $has_update,
                'version' => $latest_version,
                'update_url' => $has_update ? $this->getUpdateUrl($platform) : '',
                'update_content' => $has_update ? $this->getUpdateContent($platform, $latest_version) : ''
            ];
            
            response_success($response_data);
        } catch (Exception $e) {
            response_error(500, '检查更新失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 获取应用配置
     * 
     * @return void
     */
    public function getConfig() {
        try {
            // 查询应用配置
            $sql = "SELECT * FROM `" . DB_PREFIX . "ovo_setting` LIMIT 1";
            $stmt = $this->pdo->prepare($sql);
            $stmt->execute();
            $setting = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$setting) {
                response_error(500, '系统设置不存在');
            }
            
            // 构建配置信息
            $config = [
                'app_name' => $setting['app_name'],
                'logo_url' => $this->getLogoUrl(),
                'share_url' => $this->getShareUrl(),
                'contact_email' => 'support@ovofun.com',
                'android_version' => $setting['android_version'],
                'ios_version' => $setting['ios_version'],
                'windows_version' => $setting['windows_version'],
                'linux_version' => $setting['linux_version']
            ];
            
            response_success($config);
        } catch (Exception $e) {
            response_error(500, '获取应用配置失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 获取更新地址
     * 
     * @param string $platform 平台
     * @return string 更新地址
     */
    private function getUpdateUrl($platform) {
        // 这里应该根据实际情况返回不同平台的更新地址
        $base_url = 'https://download.ovofun.com/';
        
        switch ($platform) {
            case 'android':
                return $base_url . 'android/ovofun.apk';
            case 'ios':
                return 'https://apps.apple.com/app/ovofun';
            case 'windows':
                return $base_url . 'windows/ovofun_setup.exe';
            case 'linux':
                return $base_url . 'linux/ovofun.deb';
            default:
                return $base_url;
        }
    }
    
    /**
     * 获取更新内容
     * 
     * @param string $platform 平台
     * @param string $version 版本号
     * @return string 更新内容
     */
    private function getUpdateContent($platform, $version) {
        // 这里应该根据实际情况返回不同版本的更新内容
        return "版本 {$version} 更新内容：\n1. 优化用户体验\n2. 修复已知问题\n3. 提升性能";
    }
    
    /**
     * 获取Logo地址
     * 
     * @return string Logo地址
     */
    private function getLogoUrl() {
        return 'https://www.ovofun.com/static/images/logo.png';
    }
    
    /**
     * 获取分享地址
     * 
     * @return string 分享地址
     */
    private function getShareUrl() {
        return 'https://www.ovofun.com/share';
    }
    
    /**
     * 数据库连接检测
     * @return void
     */
    public function checkConnent() {
        try {
            $stmt = $this->pdo->query('SELECT 1');
            if ($stmt && $stmt->fetchColumn() == 1) {
                response_success(['msg' => 'ok']);
            } else {
                response_error(500, 'fuck');
            }
        } catch (Exception $e) {
            response_error(500, 'fuck');
        }
    }
    
    /**
     * 用户在看状态上报
     * @param int $user_id 用户ID（通过token获取）
     * @param array $params 请求参数，包含vod_id
     * @return void
     */
    public function watching($user_id, $params) {
        if (empty($params['vod_id'])) {
            response_error(400, '缺少vod_id');
        }
        $vod_id = intval($params['vod_id']);

        // 读取redis配置
        $redis_conf = include(dirname(__DIR__, 2) . '/database.php');
        $redis_conf = $redis_conf['redis'];
        $redis = new \Redis();
        $redis->connect($redis_conf['host'], $redis_conf['port']);
        if (!empty($redis_conf['password'])) {
            $redis->auth($redis_conf['password']);
        }
        if (isset($redis_conf['select'])) {
            $redis->select($redis_conf['select']);
        }

        $current_time = time();
        $member = "{$user_id}:{$vod_id}";

        // 检查用户是否在看其他视频
        $old_members = $redis->zRangeByLex('active_users', "[{$user_id}:", "[{$user_id}:\xff");
        if (!empty($old_members)) {
            $old_data = explode(':', $old_members[0]);
            $old_vod_id = $old_data[1];
            if ($old_vod_id != $vod_id) {
                $redis->sRem("vod_users:$old_vod_id", $user_id);
            }
        }

        // 更新/添加用户到新视频
        $redis->multi();
        $redis->zAdd('active_users', $current_time, $member);
        $redis->sAdd("vod_users:$vod_id", $user_id);
        $redis->expire("vod_users:$vod_id", 360); // 6分钟
        $redis->exec();

        // 获取当前在看人数
        $count = $redis->sCard("vod_users:$vod_id");

        response_success([
            'msg' => 'ok',
            'vod_id' => $vod_id,
            'watching_count' => $count
        ]);
    }
}
