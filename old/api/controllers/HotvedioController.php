<?php
/**
 * 热播视频控制器
 * 
 * 处理热播视频相关的API请求
 * 
 * @author ovo
 * @version 1.0.0
 * @date 2025-05-23
 */

class HotvedioController {
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
     * 获取热播视频列表
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function getList($params = []) {
        try {
            // 获取分页参数
            $page = isset($params['page']) ? max(1, intval($params['page'])) : 1;
            $limit = isset($params['limit']) ? max(1, min(100, intval($params['limit']))) : 20;
            
            // 获取热门数据等级配置
            $default_level = 6; // 默认等级
            if (!isset($params['level'])) {
                $setting_sql = "SELECT `hot_level` FROM `qwq_setting` LIMIT 1";
                $setting_stmt = $this->pdo->prepare($setting_sql);
                $setting_stmt->execute();
                $setting = $setting_stmt->fetch(PDO::FETCH_ASSOC);
                
                // 如果没有配置或配置为空，使用默认等级6
                $default_level = (isset($setting['hot_level']) && $setting['hot_level'] > 0) 
                    ? intval($setting['hot_level']) : 6;
            }
            
            $level = isset($params['level']) ? intval($params['level']) : $default_level;
            
            // 计算偏移量
            $offset = ($page - 1) * $limit;
            
            // 查询热播视频列表（根据配置的热门等级）
            $sql = "SELECT `vod_id`, `vod_name`, `vod_pic`, `vod_remarks`, `vod_level` 
                   FROM `" . DB_PREFIX . "vod` 
                   WHERE `vod_level` = :level AND `vod_status` = 1 
                   ORDER BY `vod_time` DESC 
                   LIMIT :offset, :limit";
            
            $stmt = $this->pdo->prepare($sql);
            $stmt->bindParam(':level', $level, PDO::PARAM_INT);
            $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
            $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
            $stmt->execute();
            $hotvedios = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // 查询总数
            $sql_count = "SELECT COUNT(*) as total 
                         FROM `" . DB_PREFIX . "vod` 
                         WHERE `vod_level` = :level AND `vod_status` = 1";
            
            $stmt_count = $this->pdo->prepare($sql_count);
            $stmt_count->bindParam(':level', $level, PDO::PARAM_INT);
            $stmt_count->execute();
            $total = $stmt_count->fetch(PDO::FETCH_ASSOC)['total'];
            
            // 处理结果
            $hotvedio_list = [];
            foreach ($hotvedios as $hotvedio) {
                $hotvedio_list[] = [
                    'vod_id' => intval($hotvedio['vod_id']),
                    'vod_name' => $hotvedio['vod_name'],
                    'vod_pic' => $hotvedio['vod_pic'],
                    'vod_remarks' => $hotvedio['vod_remarks'],
                    'vod_level' => intval($hotvedio['vod_level'])
                ];
            }
            
            // 返回热播视频列表
            $response_data = [
                'list' => $hotvedio_list,
                'total' => intval($total),
                'page' => $page,
                'limit' => $limit,
                'pages' => ceil($total / $limit)
            ];
            
            response_success($response_data);
        } catch (Exception $e) {
            response_error(500, '获取热播视频列表失败: ' . $e->getMessage());
        }
    }
}
