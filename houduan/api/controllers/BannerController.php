<?php
/**
 * 轮播图控制器
 * 
 * 处理轮播图相关的API请求
 * 
 * @author Manus AI
 * @version 1.0.0
 * @date 2025-05-20
 */

class BannerController {
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
     * 获取轮播图列表
     * 
     * @return void
     */
    public function getList() {
        try {
            // 获取轮播图推荐等级配置
            $setting_sql = "SELECT `banner_level` FROM `" . DB_PREFIX . "ovo_setting` LIMIT 1";
            $setting_stmt = $this->pdo->prepare($setting_sql);
            $setting_stmt->execute();
            $setting = $setting_stmt->fetch(PDO::FETCH_ASSOC);
            
            // 如果没有配置或配置为空，使用默认等级9
            $banner_level = (isset($setting['banner_level']) && $setting['banner_level'] > 0) 
                ? intval($setting['banner_level']) : 9;
            
            // 查询轮播图列表（根据配置的推荐等级）
            $sql = "SELECT `vod_id`, `vod_name`, `vod_pic_slide` 
                   FROM `" . DB_PREFIX . "vod` 
                   WHERE `vod_level` = :banner_level AND `vod_pic_slide` != '' 
                   ORDER BY `vod_time` DESC";
            
            $stmt = $this->pdo->prepare($sql);
            $stmt->bindParam(':banner_level', $banner_level, PDO::PARAM_INT);
            $stmt->execute();
            $banners = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // 处理结果
            $banner_list = [];
            foreach ($banners as $banner) {
                $banner_list[] = [
                    'vod_id' => intval($banner['vod_id']),
                    'vod_name' => $banner['vod_name'],
                    'image_url' => $banner['vod_pic_slide']
                ];
            }
            
            // 返回轮播图列表
            $response_data = [
                'list' => $banner_list
            ];
            
            response_success($response_data);
        } catch (Exception $e) {
            response_error(500, '获取轮播图列表失败: ' . $e->getMessage());
        }
    }
}