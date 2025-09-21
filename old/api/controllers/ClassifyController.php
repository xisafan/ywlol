<?php
/**
 * 分类控制器
 * 
 * 处理分类相关的API请求，获取分类数据和分类下的视频
 * 
 * @author Manus AI
 * @version 1.0.0
 * @date 2025-05-23
 */

class ClassifyController {
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
     * 获取所有分类列表
     * 
     * @return void
     */
    public function getAllTypes() {
        try {
            // 查询所有分类
            $sql = "SELECT `type_id`, `type_name`, `type_en`, `type_sort` 
                   FROM `" . DB_PREFIX . "type` 
                   WHERE `type_status` = 1 
                   ORDER BY `type_sort` ASC";
            
            $stmt = $this->pdo->prepare($sql);
            $stmt->execute();
            $types = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // 处理结果
            $type_list = [];
            foreach ($types as $type) {
                $type_list[] = [
                    'type_id' => intval($type['type_id']),
                    'type_name' => $type['type_name'],
                    'type_en' => $type['type_en'],
                    'type_sort' => intval($type['type_sort'])
                ];
            }
            
            // 返回分类列表
            $response_data = [
                'list' => $type_list
            ];
            
            response_success($response_data);
        } catch (Exception $e) {
            response_error(500, '获取分类列表失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 获取分类下的视频列表
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function getListByType($params = []) {
        try {
            // 获取请求参数
            $type_id = isset($params['type_id']) ? intval($params['type_id']) : 0;
            $page = isset($params['page']) ? intval($params['page']) : 1;
            $limit = isset($params['limit']) ? intval($params['limit']) : 20;
            
            // 参数验证
            if ($type_id <= 0) {
                response_error(400, '分类ID不能为空');
            }
            
            if ($page <= 0) {
                $page = 1;
            }
            
            if ($limit <= 0 || $limit > 100) {
                $limit = 20;
            }
            
            // 计算偏移量
            $offset = ($page - 1) * $limit;
            
            // 查询分类下的视频总数
            $count_sql = "SELECT COUNT(*) as total 
                         FROM `" . DB_PREFIX . "vod` 
                         WHERE `type_id` = :type_id AND `vod_status` = 1";
            
            $count_stmt = $this->pdo->prepare($count_sql);
            $count_stmt->bindParam(':type_id', $type_id, PDO::PARAM_INT);
            $count_stmt->execute();
            $count_result = $count_stmt->fetch(PDO::FETCH_ASSOC);
            $total = intval($count_result['total']);
            
            // 计算总页数
            $pages = ceil($total / $limit);
            
            // 查询分类下的视频列表，包含前端需要的所有字段
            $sql = "SELECT v.`vod_id`, v.`vod_name`, v.`vod_pic`, v.`vod_remarks`, v.`vod_score`, 
                           v.`vod_hits`, v.`vod_time`, v.`vod_blurb`, v.`vod_lang`, v.`vod_year`, 
                           v.`vod_class`, v.`type_id`, t.`type_name`
                   FROM `" . DB_PREFIX . "vod` v
                   LEFT JOIN `" . DB_PREFIX . "type` t ON v.`type_id` = t.`type_id`
                   WHERE v.`type_id` = :type_id AND v.`vod_status` = 1 
                   ORDER BY v.`vod_time` DESC 
                   LIMIT :offset, :limit";
            
            $stmt = $this->pdo->prepare($sql);
            $stmt->bindParam(':type_id', $type_id, PDO::PARAM_INT);
            $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
            $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
            $stmt->execute();
            $videos = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // 处理结果，确保数据类型正确
            $video_list = [];
            foreach ($videos as $video) {
                $video_list[] = [
                    'vod_id' => intval($video['vod_id']),
                    'vod_name' => $video['vod_name'] ?: '',
                    'vod_pic' => $video['vod_pic'] ?: '',
                    'vod_remarks' => $video['vod_remarks'] ?: '',
                    'vod_score' => floatval($video['vod_score'] ?: 0),
                    'vod_hits' => intval($video['vod_hits'] ?: 0),
                    'vod_time' => intval($video['vod_time'] ?: 0),
                    'vod_blurb' => $video['vod_blurb'] ?: '',
                    'vod_lang' => $video['vod_lang'] ?: '',
                    'vod_year' => $video['vod_year'] ?: '',
                    'vod_class' => $video['vod_class'] ?: '',
                    'type_id' => intval($video['type_id'] ?: 0),
                    'type_name' => $video['type_name'] ?: ''
                ];
            }
            
            // 查询分类信息
            $type_sql = "SELECT `type_id`, `type_name`, `type_en` 
                        FROM `" . DB_PREFIX . "type` 
                        WHERE `type_id` = :type_id";
            
            $type_stmt = $this->pdo->prepare($type_sql);
            $type_stmt->bindParam(':type_id', $type_id, PDO::PARAM_INT);
            $type_stmt->execute();
            $type_info = $type_stmt->fetch(PDO::FETCH_ASSOC);
            
            // 返回分类下的视频列表
            $response_data = [
                'list' => $video_list,
                'type' => [
                    'type_id' => intval($type_info['type_id']),
                    'type_name' => $type_info['type_name'],
                    'type_en' => $type_info['type_en']
                ],
                'total' => $total,
                'page' => $page,
                'limit' => $limit,
                'pages' => $pages
            ];
            
            response_success($response_data);
        } catch (Exception $e) {
            response_error(500, '获取分类视频列表失败: ' . $e->getMessage());
        }
    }

    /**
     * 获取视频扩展分类（类型/地区/语言/年代等）
     * @return void
     */
    public function getVodExtends() {
        try {
            // 支持type_id参数
            $type_id = isset($_GET['type_id']) ? intval($_GET['type_id']) : 0;
            $where = ["`vod_status` = 1"];
            $where_params = [];
            if ($type_id > 0) {
                $where[] = "(`type_id` = :type_id OR `type_id_1` = :type_id)";
                $where_params[':type_id'] = $type_id;
            }
            $where_clause = !empty($where) ? "WHERE " . implode(" AND ", $where) : "";

            // 查询所有可用的扩展分类（去重）
            $class_sql = "SELECT DISTINCT `vod_class` FROM `" . DB_PREFIX . "vod` $where_clause AND `vod_class` != ''";
            $area_sql = "SELECT DISTINCT `vod_area` FROM `" . DB_PREFIX . "vod` $where_clause AND `vod_area` != ''";
            $lang_sql = "SELECT DISTINCT `vod_lang` FROM `" . DB_PREFIX . "vod` $where_clause AND `vod_lang` != ''";
            $year_sql = "SELECT DISTINCT `vod_year` FROM `" . DB_PREFIX . "vod` $where_clause AND `vod_year` != ''";

            $class_stmt = $this->pdo->prepare($class_sql);
            foreach ($where_params as $k => $v) $class_stmt->bindValue($k, $v);
            $class_stmt->execute();
            $class_rows = $class_stmt->fetchAll(PDO::FETCH_COLUMN);
            $class_list = [];
            foreach ($class_rows as $row) {
                $arr = array_filter(array_map('trim', explode(',', $row)));
                $class_list = array_merge($class_list, $arr);
            }
            $class_list = array_values(array_unique($class_list));

            $area_stmt = $this->pdo->prepare($area_sql);
            foreach ($where_params as $k => $v) $area_stmt->bindValue($k, $v);
            $area_stmt->execute();
            $area_list = array_values(array_unique(array_filter($area_stmt->fetchAll(PDO::FETCH_COLUMN))));

            $lang_stmt = $this->pdo->prepare($lang_sql);
            foreach ($where_params as $k => $v) $lang_stmt->bindValue($k, $v);
            $lang_stmt->execute();
            $lang_list = array_values(array_unique(array_filter($lang_stmt->fetchAll(PDO::FETCH_COLUMN))));

            $year_stmt = $this->pdo->prepare($year_sql);
            foreach ($where_params as $k => $v) $year_stmt->bindValue($k, $v);
            $year_stmt->execute();
            $year_list = array_values(array_unique(array_filter($year_stmt->fetchAll(PDO::FETCH_COLUMN))));

            $response_data = [
                'class' => $class_list,
                'area' => $area_list,
                'lang' => $lang_list,
                'year' => $year_list
            ];
            response_success($response_data);
        } catch (Exception $e) {
            response_error(500, '获取扩展分类失败: ' . $e->getMessage());
        }
    }

    /**
     * 通过扩展分类筛选视频列表
     * 支持class/area/lang/year参数，分页
     * @param array $params
     * @return void
     */
    public function getListByExtend($params = []) {
        try {
            $page = isset($params['page']) ? intval($params['page']) : 1;
            $limit = isset($params['limit']) ? intval($params['limit']) : 20;
            if ($page <= 0) $page = 1;
            if ($limit <= 0 || $limit > 100) $limit = 20;
            $offset = ($page - 1) * $limit;

            $where = ["v.`vod_status` = 1"];
            $where_params = [];
            // 扩展分类筛选（使用表别名）
            if (!empty($params['type_id'])) {
                $where[] = "(v.`type_id` = :type_id OR v.`type_id_1` = :type_id)";
                $where_params[':type_id'] = intval($params['type_id']);
            }
            if (!empty($params['class'])) {
                $where[] = "FIND_IN_SET(:class, v.`vod_class`)";
                $where_params[':class'] = $params['class'];
            }
            if (!empty($params['area'])) {
                $where[] = "v.`vod_area` = :area";
                $where_params[':area'] = $params['area'];
            }
            if (!empty($params['lang'])) {
                $where[] = "v.`vod_lang` = :lang";
                $where_params[':lang'] = $params['lang'];
            }
            if (!empty($params['year'])) {
                $where[] = "v.`vod_year` = :year";
                $where_params[':year'] = $params['year'];
            }
            $where_clause = !empty($where) ? "WHERE " . implode(" AND ", $where) : "";

            // 查询总数（使用LEFT JOIN保持与主查询一致）
            $count_sql = "SELECT COUNT(*) FROM `" . DB_PREFIX . "vod` v 
                         LEFT JOIN `" . DB_PREFIX . "type` t ON v.`type_id` = t.`type_id` 
                         $where_clause";
            $stmt = $this->pdo->prepare($count_sql);
            foreach ($where_params as $key => $value) {
                $stmt->bindValue($key, $value);
            }
            $stmt->execute();
            $total = $stmt->fetchColumn();
            $pages = ceil($total / $limit);

            // 查询视频列表，包含前端需要的所有字段
            $sql = "SELECT v.`vod_id`, v.`vod_name`, v.`vod_pic`, v.`vod_remarks`, v.`vod_score`, 
                           v.`vod_hits`, v.`vod_time`, v.`vod_blurb`, v.`vod_lang`, v.`vod_year`, 
                           v.`vod_class`, v.`type_id`, t.`type_name`
                   FROM `" . DB_PREFIX . "vod` v
                   LEFT JOIN `" . DB_PREFIX . "type` t ON v.`type_id` = t.`type_id`
                   $where_clause ORDER BY v.`vod_time` DESC LIMIT :offset, :limit";
            $stmt = $this->pdo->prepare($sql);
            foreach ($where_params as $key => $value) {
                $stmt->bindValue($key, $value);
            }
            $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->execute();
            $videos = $stmt->fetchAll(PDO::FETCH_ASSOC);

            $video_list = [];
            foreach ($videos as $video) {
                $video_list[] = [
                    'vod_id' => intval($video['vod_id']),
                    'vod_name' => $video['vod_name'] ?: '',
                    'vod_pic' => $video['vod_pic'] ?: '',
                    'vod_remarks' => $video['vod_remarks'] ?: '',
                    'vod_score' => floatval($video['vod_score'] ?: 0),
                    'vod_hits' => intval($video['vod_hits'] ?: 0),
                    'vod_time' => intval($video['vod_time'] ?: 0),
                    'vod_blurb' => $video['vod_blurb'] ?: '',
                    'vod_lang' => $video['vod_lang'] ?: '',
                    'vod_year' => $video['vod_year'] ?: '',
                    'vod_class' => $video['vod_class'] ?: '',
                    'type_id' => intval($video['type_id'] ?: 0),
                    'type_name' => $video['type_name'] ?: ''
                ];
            }
            $response_data = [
                'list' => $video_list,
                'total' => $total,
                'page' => $page,
                'limit' => $limit,
                'pages' => $pages
            ];
            response_success($response_data);
        } catch (Exception $e) {
            response_error(500, '获取扩展分类视频失败: ' . $e->getMessage());
        }
    }
}
