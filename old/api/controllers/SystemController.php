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
                   FROM `qwq_announcement` 
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
        
        // 验证平台参数 - qwq_version表只支持android和ios
        $valid_platforms = ['android', 'ios'];
        if (!in_array($platform, $valid_platforms)) {
            response_error(400, '不支持的平台，当前只支持: ' . implode(', ', $valid_platforms));
        }
        
        try {
            // 从qwq_version表查询最新版本信息
            $sql = "SELECT `id`, `platform`, `title`, `version`, `download_url`, `description`, 
                          `package_size`, `force_update`, `browser_url`, `create_time`
                   FROM `qwq_version` 
                   WHERE `platform` = :platform AND `status` = 1 
                   ORDER BY `create_time` DESC 
                   LIMIT 1";
            
            $stmt = $this->pdo->prepare($sql);
            $stmt->bindParam(':platform', $platform);
            $stmt->execute();
            $version_info = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$version_info) {
                response_error(404, '未找到该平台的版本信息');
            }
            
            $latest_version = $version_info['version'];
            
            // 比较版本号
            $has_update = version_compare($latest_version, $current_version, '>');
            
            // 返回更新信息
            $response_data = [
                'has_update' => $has_update,
                'platform' => $version_info['platform'],
                'version' => $latest_version,
                'current_version' => $current_version,
                'title' => $version_info['title'],
                'download_url' => $has_update ? $version_info['download_url'] : '',
                'browser_url' => $has_update ? ($version_info['browser_url'] ?: '') : '',
                'description' => $has_update ? $version_info['description'] : '',
                'package_size' => $has_update ? $version_info['package_size'] : '',
                'force_update' => $has_update ? (bool)$version_info['force_update'] : false,
                'update_time' => $version_info['create_time']
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
            // 查询基础应用配置
            $sql = "SELECT * FROM `qwq_setting` LIMIT 1";
            $stmt = $this->pdo->prepare($sql);
            $stmt->execute();
            $setting = $stmt->fetch(PDO::FETCH_ASSOC);
            
            // 查询版本信息
            $version_sql = "SELECT `platform`, `version`, `title`, `download_url`, `package_size`, `create_time`
                           FROM `qwq_version` 
                           WHERE `status` = 1 
                           ORDER BY `platform` ASC, `create_time` DESC";
            $version_stmt = $this->pdo->prepare($version_sql);
            $version_stmt->execute();
            $versions = $version_stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // 处理版本信息
            $version_info = [];
            $platforms_found = [];
            
            foreach ($versions as $version) {
                $platform = $version['platform'];
                // 只取每个平台最新的版本（因为已按create_time DESC排序）
                if (!in_array($platform, $platforms_found)) {
                    $version_info[$platform] = [
                        'version' => $version['version'],
                        'title' => $version['title'],
                        'download_url' => $version['download_url'],
                        'package_size' => $version['package_size'],
                        'update_time' => $version['create_time']
                    ];
                    $platforms_found[] = $platform;
                }
            }
            
            // 构建配置信息
            $config = [
                'app_name' => $setting ? $setting['app_name'] : 'QwqFun',
                'logo_url' => $this->getLogoUrl(),
                'share_url' => $this->getShareUrl(),
                'contact_email' => 'support@qwqfun.com',
                'versions' => $version_info,
                // 兼容旧版本API，保留原有字段
                'android_version' => isset($version_info['android']) ? $version_info['android']['version'] : '',
                'ios_version' => isset($version_info['ios']) ? $version_info['ios']['version'] : ''
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
        return 'https://www.qwqfun.com/static/images/logo.png';
    }
    
    /**
     * 获取分享地址
     * 
     * @return string 分享地址
     */
    private function getShareUrl() {
        return 'https://www.qwqfun.com/share';
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
    
    /**
     * 获取版本列表
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function getVersionList($params = []) {
        try {
            $platform = isset($params['platform']) ? strtolower(trim($params['platform'])) : '';
            $page = isset($params['page']) ? max(1, intval($params['page'])) : 1;
            $limit = isset($params['limit']) ? max(1, min(50, intval($params['limit']))) : 10;
            $offset = ($page - 1) * $limit;
            
            // 构建查询条件
            $where_conditions = ['1=1'];
            $bind_params = [];
            
            if (!empty($platform)) {
                if (!in_array($platform, ['android', 'ios'])) {
                    response_error(400, '不支持的平台参数');
                }
                $where_conditions[] = '`platform` = :platform';
                $bind_params[':platform'] = $platform;
            }
            
            // 查询总数
            $count_sql = "SELECT COUNT(*) FROM `qwq_version` WHERE " . implode(' AND ', $where_conditions);
            $count_stmt = $this->pdo->prepare($count_sql);
            foreach ($bind_params as $key => $value) {
                $count_stmt->bindValue($key, $value);
            }
            $count_stmt->execute();
            $total = $count_stmt->fetchColumn();
            
            // 查询版本列表
            $sql = "SELECT `id`, `platform`, `title`, `version`, `download_url`, `description`,
                          `package_size`, `force_update`, `browser_url`, `status`, `create_time`
                   FROM `qwq_version` 
                   WHERE " . implode(' AND ', $where_conditions) . "
                   ORDER BY `create_time` DESC 
                   LIMIT :offset, :limit";
            
            $stmt = $this->pdo->prepare($sql);
            foreach ($bind_params as $key => $value) {
                $stmt->bindValue($key, $value);
            }
            $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->execute();
            
            $versions = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // 格式化数据
            foreach ($versions as &$version) {
                $version['force_update'] = (bool)$version['force_update'];
                $version['status'] = (int)$version['status'];
            }
            
            response_success([
                'total' => $total,
                'page' => $page,
                'limit' => $limit,
                'list' => $versions
            ]);
        } catch (Exception $e) {
            response_error(500, '获取版本列表失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 获取版本详情
     * 
     * @param int $version_id 版本ID
     * @return void
     */
    public function getVersionDetails($version_id) {
        try {
            if (empty($version_id) || !is_numeric($version_id)) {
                response_error(400, '无效的版本ID');
            }
            
            $sql = "SELECT `id`, `platform`, `title`, `version`, `download_url`, `description`,
                          `package_size`, `force_update`, `browser_url`, `status`, 
                          `create_time`, `update_time`
                   FROM `qwq_version` 
                   WHERE `id` = :id";
            
            $stmt = $this->pdo->prepare($sql);
            $stmt->bindParam(':id', $version_id, PDO::PARAM_INT);
            $stmt->execute();
            
            $version = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$version) {
                response_error(404, '版本不存在');
            }
            
            // 格式化数据
            $version['force_update'] = (bool)$version['force_update'];
            $version['status'] = (int)$version['status'];
            
            response_success($version);
        } catch (Exception $e) {
            response_error(500, '获取版本详情失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 获取各平台当前最新版本
     * 
     * @return void
     */
    public function getCurrentVersions() {
        try {
            $sql = "SELECT `platform`, `version`, `title`, `download_url`, `package_size`, 
                          `force_update`, `create_time`
                   FROM `qwq_version` 
                   WHERE `status` = 1
                   ORDER BY `platform` ASC, `create_time` DESC";
            
            $stmt = $this->pdo->prepare($sql);
            $stmt->execute();
            $versions = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // 每个平台只保留最新版本
            $current_versions = [];
            $platforms_found = [];
            
            foreach ($versions as $version) {
                $platform = $version['platform'];
                if (!in_array($platform, $platforms_found)) {
                    $version['force_update'] = (bool)$version['force_update'];
                    $current_versions[] = $version;
                    $platforms_found[] = $platform;
                }
            }
            
            response_success([
                'platforms' => $current_versions,
                'update_time' => date('Y-m-d H:i:s')
            ]);
        } catch (Exception $e) {
            response_error(500, '获取当前版本失败: ' . $e->getMessage());
        }
    }
}
