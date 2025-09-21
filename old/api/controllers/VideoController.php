<?php
/**
 * 视频控制器
 * 
 * 处理视频相关的API请求
 * 
 * @author ovo
 * @version 1.0.0
 * @date 2025-05-20
 */

class VideoController {
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
     * 获取视频列表
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function getList($params) {
        // 分页参数
        $page = isset($params['page']) ? intval($params['page']) : 1;
        $limit = isset($params['limit']) ? intval($params['limit']) : 20;
        
        if ($page < 1) $page = 1;
        if ($limit < 1 || $limit > 100) $limit = 20;
        
        $offset = ($page - 1) * $limit;
        
        // 筛选参数
        $type_id = isset($params['type_id']) ? intval($params['type_id']) : 0;
        $order = isset($params['order']) ? $params['order'] : 'time';
        
        try {
            // 构建查询条件
            $where = [];
            $where_params = [];
            
            // 状态条件（使用表别名）
            $where[] = "v.`vod_status` = 1";
            
            // 分类条件（使用表别名）
            if ($type_id > 0) {
                $where[] = "(v.`type_id` = :type_id OR v.`type_id_1` = :type_id)";
                $where_params[':type_id'] = $type_id;
            }
            
            // 构建WHERE子句
            $where_clause = !empty($where) ? "WHERE " . implode(" AND ", $where) : "";
            
            // 构建ORDER BY子句（使用表别名）
            $order_clause = "ORDER BY ";
            switch ($order) {
                case 'hits':
                    $order_clause .= "v.`vod_hits` DESC";
                    break;
                case 'score':
                    $order_clause .= "v.`vod_score` DESC";
                    break;
                case 'time':
                default:
                    $order_clause .= "v.`vod_time` DESC";
                    break;
            }
            
            // 查询总数（使用LEFT JOIN保持与主查询一致）
            $count_sql = "SELECT COUNT(*) FROM `" . DB_PREFIX . "vod` v 
                         LEFT JOIN `" . DB_PREFIX . "type` t ON v.`type_id` = t.`type_id` 
                         {$where_clause}";
            $stmt = $this->pdo->prepare($count_sql);
            foreach ($where_params as $key => $value) {
                $stmt->bindValue($key, $value);
            }
            $stmt->execute();
            $total = $stmt->fetchColumn();
            
            // 计算总页数
            $pages = ceil($total / $limit);
            
            // 查询视频列表，包含前端需要的所有字段
            $sql = "SELECT v.`vod_id`, v.`vod_name`, v.`vod_pic`, v.`vod_remarks`, v.`vod_score`, 
                           v.`vod_hits`, v.`vod_time`, v.`vod_blurb`, v.`vod_lang`, v.`vod_year`, 
                           v.`vod_class`, v.`type_id`, t.`type_name`
                   FROM `" . DB_PREFIX . "vod` v
                   LEFT JOIN `" . DB_PREFIX . "type` t ON v.`type_id` = t.`type_id`
                   {$where_clause} 
                   {$order_clause} 
                   LIMIT :offset, :limit";
            
            $stmt = $this->pdo->prepare($sql);
            foreach ($where_params as $key => $value) {
                $stmt->bindValue($key, $value);
            }
            $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->execute();
            $videos = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // 处理返回数据，确保数据类型正确
            foreach ($videos as &$video) {
                // 确保数值类型正确
                $video['vod_id'] = intval($video['vod_id']);
                $video['vod_score'] = floatval($video['vod_score'] ?: 0);
                $video['vod_hits'] = intval($video['vod_hits'] ?: 0);
                $video['vod_time'] = intval($video['vod_time'] ?: 0);
                $video['type_id'] = intval($video['type_id'] ?: 0);
                
                // 确保字符串字段不为null
                $video['vod_name'] = $video['vod_name'] ?: '';
                $video['vod_pic'] = $video['vod_pic'] ?: '';
                $video['vod_remarks'] = $video['vod_remarks'] ?: '';
                $video['vod_blurb'] = $video['vod_blurb'] ?: '';
                $video['vod_lang'] = $video['vod_lang'] ?: '';
                $video['vod_year'] = $video['vod_year'] ?: '';
                $video['vod_class'] = $video['vod_class'] ?: '';
                $video['type_name'] = $video['type_name'] ?: '';
            }
            
            // 返回视频列表
            $response_data = [
                'list' => $videos,
                'total' => $total,
                'page' => $page,
                'limit' => $limit,
                'pages' => $pages
            ];
            
            response_success($response_data);
        } catch (Exception $e) {
            response_error(500, '获取视频列表失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 获取视频详情
     * 
     * @param int $vod_id 视频ID
     * @return void
     */
    public function getDetail($vod_id) {
        try {
            // 查询视频详情
            $sql = "SELECT * FROM `" . DB_PREFIX . "vod` WHERE `vod_id` = :vod_id AND `vod_status` = 1 LIMIT 1";
            $stmt = $this->pdo->prepare($sql);
            $stmt->bindParam(':vod_id', $vod_id);
            $stmt->execute();
            $video = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$video) {
                response_error(404, '视频不存在或已下架');
            }
            
            // 查询分类名
            $type_name = '';
            if (!empty($video['type_id'])) {
                $type_stmt = $this->pdo->prepare("SELECT `type_name` FROM `" . DB_PREFIX . "type` WHERE `type_id` = :type_id LIMIT 1");
                $type_stmt->bindParam(':type_id', $video['type_id']);
                $type_stmt->execute();
                $type_row = $type_stmt->fetch(PDO::FETCH_ASSOC);
                if ($type_row) {
                    $type_name = $type_row['type_name'];
                }
            }
            $video['type_name'] = $type_name;
            
            // 更新点击量
            $update_sql = "UPDATE `" . DB_PREFIX . "vod` SET `vod_hits` = `vod_hits` + 1 WHERE `vod_id` = :vod_id";
            $stmt = $this->pdo->prepare($update_sql);
            $stmt->bindParam(':vod_id', $vod_id);
            $stmt->execute();
            
            // 查询所有播放器
            $player_sql = "SELECT `player`, `type`, `lib`, `url`, `referer`, `name` FROM `qwq_player`";
            $stmt = $this->pdo->prepare($player_sql);
            $stmt->execute();
            $players = $stmt->fetchAll(PDO::FETCH_ASSOC);

            // 获取所有播放器编码
            $player_codes = array_column($players, 'player');

            // 处理vod_play_from和vod_play_url
            $vod_play_from = explode('$$$', $video['vod_play_from']);
            $vod_play_url = explode('$$$', $video['vod_play_url']);

            $new_play_from = [];
            $new_play_url = [];
            foreach ($vod_play_from as $idx => $from) {
                if (in_array($from, $player_codes)) {
                    $new_play_from[] = $from;
                    $new_play_url[] = isset($vod_play_url[$idx]) ? $vod_play_url[$idx] : '';
                }
            }

            // 重新赋值
            $video['vod_play_from'] = implode('$$$', $new_play_from);
            $video['vod_play_url'] = implode('$$$', $new_play_url);

            // 新增播放器信息
            $video['player_list'] = $players;

            // 返回视频详情
            response_success($video);
        } catch (Exception $e) {
            response_error(500, '获取视频详情失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 搜索视频
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function search($params) {
        // 验证参数
        if (!isset($params['keyword']) || empty($params['keyword'])) {
            response_error(400, '搜索关键词不能为空');
        }
        
        $keyword = trim($params['keyword']);
        
        // 分页参数
        $page = isset($params['page']) ? intval($params['page']) : 1;
        $limit = isset($params['limit']) ? intval($params['limit']) : 20;
        
        if ($page < 1) $page = 1;
        if ($limit < 1 || $limit > 100) $limit = 20;
        
        $offset = ($page - 1) * $limit;
        
        try {
            // 构建查询条件
            $where = [];
            $where_params = [];
            
            // 状态条件（使用表别名）
            $where[] = "v.`vod_status` = 1";
            
            // 关键词条件（使用表别名）
            $where[] = "(v.`vod_name` LIKE :keyword OR v.`vod_actor` LIKE :keyword OR v.`vod_director` LIKE :keyword)";
            $where_params[':keyword'] = '%' . $keyword . '%';
            
            // 构建WHERE子句
            $where_clause = !empty($where) ? "WHERE " . implode(" AND ", $where) : "";
            
            // 查询总数（使用LEFT JOIN保持与主查询一致）
            $count_sql = "SELECT COUNT(*) FROM `" . DB_PREFIX . "vod` v 
                         LEFT JOIN `" . DB_PREFIX . "type` t ON v.`type_id` = t.`type_id` 
                         {$where_clause}";
            $stmt = $this->pdo->prepare($count_sql);
            foreach ($where_params as $key => $value) {
                $stmt->bindValue($key, $value);
            }
            $stmt->execute();
            $total = $stmt->fetchColumn();
            
            // 计算总页数
            $pages = ceil($total / $limit);
            
            // 查询视频列表，包含前端需要的所有字段
            $sql = "SELECT v.`vod_id`, v.`vod_name`, v.`vod_pic`, v.`vod_remarks`, v.`vod_score`, 
                           v.`vod_hits`, v.`vod_time`, v.`vod_blurb`, v.`vod_lang`, v.`vod_year`, 
                           v.`vod_class`, v.`type_id`, t.`type_name`
                   FROM `" . DB_PREFIX . "vod` v
                   LEFT JOIN `" . DB_PREFIX . "type` t ON v.`type_id` = t.`type_id`
                   {$where_clause} 
                   ORDER BY v.`vod_time` DESC 
                   LIMIT :offset, :limit";
            
            $stmt = $this->pdo->prepare($sql);
            foreach ($where_params as $key => $value) {
                $stmt->bindValue($key, $value);
            }
            $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->execute();
            $videos = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // 处理返回数据，确保数据类型正确
            foreach ($videos as &$video) {
                // 确保数值类型正确
                $video['vod_id'] = intval($video['vod_id']);
                $video['vod_score'] = floatval($video['vod_score'] ?: 0);
                $video['vod_hits'] = intval($video['vod_hits'] ?: 0);
                $video['vod_time'] = intval($video['vod_time'] ?: 0);
                $video['type_id'] = intval($video['type_id'] ?: 0);
                
                // 确保字符串字段不为null
                $video['vod_name'] = $video['vod_name'] ?: '';
                $video['vod_pic'] = $video['vod_pic'] ?: '';
                $video['vod_remarks'] = $video['vod_remarks'] ?: '';
                $video['vod_blurb'] = $video['vod_blurb'] ?: '';
                $video['vod_lang'] = $video['vod_lang'] ?: '';
                $video['vod_year'] = $video['vod_year'] ?: '';
                $video['vod_class'] = $video['vod_class'] ?: '';
                $video['type_name'] = $video['type_name'] ?: '';
            }
            
            // 返回搜索结果
            $response_data = [
                'list' => $videos,
                'total' => $total,
                'page' => $page,
                'limit' => $limit,
                'pages' => $pages,
                'keyword' => $keyword
            ];
            
            response_success($response_data);
        } catch (Exception $e) {
            response_error(500, '搜索视频失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 星期格式转换映射表（转换为数字）
     * 
     * @return array
     */
    private function getWeekdayMappings() {
        return [
            // 中文星期（完整）
            '星期一' => 1, '星期二' => 2, '星期三' => 3, '星期四' => 4, 
            '星期五' => 5, '星期六' => 6, '星期日' => 7, '星期天' => 7,
            
            // 中文星期（简写）
            '一' => 1, '二' => 2, '三' => 3, '四' => 4, 
            '五' => 5, '六' => 6, '日' => 7, '天' => 7,
            
            // 英文星期（完整）
            'monday' => 1, 'tuesday' => 2, 'wednesday' => 3, 'thursday' => 4,
            'friday' => 5, 'saturday' => 6, 'sunday' => 7,
            
            // 英文星期（简写）
            'mon' => 1, 'tue' => 2, 'wed' => 3, 'thu' => 4,
            'fri' => 5, 'sat' => 6, 'sun' => 7,
            
            // 数字字符串
            '1' => 1, '2' => 2, '3' => 3, '4' => 4,
            '5' => 5, '6' => 6, '7' => 7, '0' => 7,
        ];
    }
    
    /**
     * 数字转中文星期映射表（用于数据库查询）
     * 
     * @return array
     */
    private function getNumberToChineseMappings() {
        return [
            1 => '一', 2 => '二', 3 => '三', 4 => '四',
            5 => '五', 6 => '六', 7 => '天'  // 注意：7对应'天'而不是'日'
        ];
    }
    
    /**
     * 中文星期转数字映射表（用于分组）
     * 
     * @return array
     */
    private function getChineseToNumberMappings() {
        return [
            '一' => 1, '二' => 2, '三' => 3, '四' => 4,
            '五' => 5, '六' => 6, '日' => 7, '天' => 7,
            '星期一' => 1, '星期二' => 2, '星期三' => 3, '星期四' => 4,
            '星期五' => 5, '星期六' => 6, '星期日' => 7, '星期天' => 7,
        ];
    }
    
    /**
     * 转换星期参数为数字
     * 
     * @param mixed $weekday 星期参数（支持多种格式）
     * @return int 返回1-7的数字，0表示无效参数
     */
    private function parseWeekday($weekday) {
        // 如果已经是数字，直接验证并返回
        if (is_numeric($weekday)) {
            $day = intval($weekday);
            return ($day >= 0 && $day <= 7) ? ($day == 0 ? 7 : $day) : 0;
        }
        
        // 如果是字符串，进行格式转换
        if (is_string($weekday)) {
            $mappings = $this->getWeekdayMappings();
            $weekday = trim($weekday);
            
            // 直接匹配
            if (isset($mappings[$weekday])) {
                return $mappings[$weekday];
            }
            
            // 不区分大小写匹配（针对英文）
            $lower_weekday = strtolower($weekday);
            if (isset($mappings[$lower_weekday])) {
                return $mappings[$lower_weekday];
            }
        }
        
        return 0; // 无效参数
    }
    
    /**
     * 转换星期参数为数据库查询用的中文字符
     * 
     * @param mixed $weekday 星期参数（支持多种格式）
     * @return string 返回数据库中对应的中文字符，空字符串表示查询全部
     */
    private function parseWeekdayForDatabase($weekday) {
        if (empty($weekday)) {
            return ''; // 查询全部
        }
        
        // 如果输入的就是数据库中的格式（中文），直接使用
        $chineseToNumber = $this->getChineseToNumberMappings();
        if (isset($chineseToNumber[$weekday])) {
            return $weekday; // 直接使用中文
        }
        
        // 否则先转换为数字，再转换为数据库中的中文格式
        $weekdayNumber = $this->parseWeekday($weekday);
        if ($weekdayNumber > 0) {
            $numberToChinese = $this->getNumberToChineseMappings();
            return $numberToChinese[$weekdayNumber] ?? '';
        }
        
        return ''; // 无效参数，查询全部
    }
    
    /**
     * 获取星期的中文名称
     * 
     * @param int $weekday_num 星期数字(1-7)
     * @return string
     */
    private function getWeekdayChineseName($weekday_num) {
        $names = [
            1 => '一', 2 => '二', 3 => '三', 4 => '四',
            5 => '五', 6 => '六', 7 => '日'
        ];
        return isset($names[$weekday_num]) ? $names[$weekday_num] : '';
    }
    
    /**
     * 获取排期表（按星期分组）
     * 
     * @param array $params 请求参数，支持weekday（支持多种格式：1-7数字、中文、英文）
     *                     支持的格式示例：
     *                     - 数字：1, 2, 3, 4, 5, 6, 7 (或0表示星期日)
     *                     - 中文简写：一, 二, 三, 四, 五, 六, 日, 天
     *                     - 中文完整：星期一, 星期二, 星期三, 星期四, 星期五, 星期六, 星期日, 星期天
     *                     - 英文完整：Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday
     *                     - 英文简写：Mon, Tue, Wed, Thu, Fri, Sat, Sun
     * @return void
     */
    public function getSchedule($params = []) {
        $weekday_param = isset($params['weekday']) ? $params['weekday'] : null;
        $weekday_number = 0; // 数字形式的星期，用于返回数据
        $weekday_database = ''; // 数据库查询用的中文字符
        
        // 解析星期参数
        if ($weekday_param !== null) {
            $weekday_number = $this->parseWeekday($weekday_param);
            $weekday_database = $this->parseWeekdayForDatabase($weekday_param);
            
            // 记录调试信息
            error_log("排期表API调试：原始参数='{$weekday_param}', 解析数字={$weekday_number}, 数据库查询='{$weekday_database}'");
        }
        
        // 构建查询条件
        $where = ["`vod_status` = 1"];
        $where_params = [];
        
        // 如果有有效的星期参数，添加到查询条件中
        if (!empty($weekday_database)) {
            $where[] = "`vod_weekday` = :weekday";
            $where_params[':weekday'] = $weekday_database;
        }
        
        $where_clause = !empty($where) ? "WHERE " . implode(" AND ", $where) : "";
        
        try {
            // 查询视频数据，包含vod_weekday和vod_class字段
            $sql = "SELECT `vod_id`, `vod_name`, `vod_pic`, `vod_remarks`, `vod_weekday`, `vod_class` 
                   FROM `" . DB_PREFIX . "vod` 
                   $where_clause 
                   ORDER BY `vod_weekday` ASC, `vod_time` DESC";
            
            $stmt = $this->pdo->prepare($sql);
            foreach ($where_params as $key => $value) {
                $stmt->bindValue($key, $value);
            }
            $stmt->execute();
            $videos = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            error_log("排期表API调试：查询SQL = " . $sql);
            error_log("排期表API调试：查询参数 = " . json_encode($where_params));
            error_log("排期表API调试：查询结果数量 = " . count($videos));
            
            // 初始化1-7天的数组
            $result = [];
            for ($i = 1; $i <= 7; $i++) {
                $result[$i] = [];
            }
            
            // 按星期分组数据
            $chineseToNumber = $this->getChineseToNumberMappings();
            foreach ($videos as $video) {
                $vod_weekday_str = trim($video['vod_weekday']);
                
                // 将数据库中的中文星期转换为数字用于分组
                $day_number = isset($chineseToNumber[$vod_weekday_str]) ? $chineseToNumber[$vod_weekday_str] : 0;
                
                error_log("排期表API调试：视频 {$video['vod_name']} 的vod_weekday='{$vod_weekday_str}', 转换为数字={$day_number}");
                
                if ($day_number >= 1 && $day_number <= 7) {
                    $result[$day_number][] = [
                        'vod_id' => $video['vod_id'],
                        'vod_name' => $video['vod_name'],
                        'vod_pic' => $video['vod_pic'],
                        'vod_remarks' => $video['vod_remarks'],
                        'vod_class' => $video['vod_class'], // 添加分类字段
                        'vod_weekday_original' => $vod_weekday_str // 调试用，显示原始数据库值
                    ];
                }
            }
            
            // 统计每天的视频数量
            $day_counts = [];
            for ($i = 1; $i <= 7; $i++) {
                $day_counts[$i] = count($result[$i]);
            }
            error_log("排期表API调试：各天视频数量 = " . json_encode($day_counts));
            
            // 添加星期的中文映射信息，方便前端使用
            $weekday_names = [];
            for ($i = 1; $i <= 7; $i++) {
                $weekday_names[$i] = [
                    'number' => $i,
                    'chinese_short' => $this->getWeekdayChineseName($i),
                    'chinese_full' => '星期' . $this->getWeekdayChineseName($i),
                ];
            }
            
            // 返回增强的响应数据
            $response_data = [
                'schedule' => $result,
                'weekday_names' => $weekday_names,
                'current_filter' => [
                    'weekday_param' => $weekday_param,
                    'parsed_weekday_number' => $weekday_number,
                    'parsed_weekday_database' => $weekday_database,
                    'chinese_name' => $weekday_number > 0 ? $this->getWeekdayChineseName($weekday_number) : '全部'
                ],
                'debug_info' => [
                    'total_videos' => count($videos),
                    'day_counts' => $day_counts,
                    'sql_query' => $sql,
                    'where_params' => $where_params
                ],
                'supported_formats' => [
                    'numbers' => '1-7 (1=星期一, 7=星期日)',
                    'chinese_short' => '一,二,三,四,五,六,日,天',
                    'chinese_full' => '星期一,星期二,星期三,星期四,星期五,星期六,星期日,星期天',
                    'english_short' => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun',
                    'english_full' => 'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday',
                    'database_format' => '数据库存储格式：一,二,三,四,五,六,天'
                ]
            ];
            
            response_success($response_data);
        } catch (Exception $e) {
            error_log("排期表API错误: " . $e->getMessage());
            response_error(500, '获取排期表失败: ' . $e->getMessage());
        }
    }
}
