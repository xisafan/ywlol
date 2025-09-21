<?php
namespace app\api\controllers;

class RankController {
    protected $pdo;

    public function __construct($pdo) {
        $this->pdo = $pdo;
    }

    // 获取排行榜
    public function getTop($params) {
        $sql = "SELECT vod_id, vod_name, vod_content, vod_pic, vod_remarks, vod_lang, vod_year, 
                       vod_class, vod_director, vod_actor, vod_score, vod_hits
                FROM " . DB_PREFIX . "vod ";
        $where = [];
        $bind = [];

        if (!empty($params['type'])) {
            $where[] = "type_id = :type_id";
            $bind[':type_id'] = intval($params['type']);
        }

        if ($where) {
            $sql .= "WHERE " . implode(' AND ', $where) . " ";
        }

        $sql .= "ORDER BY vod_hits DESC LIMIT 10";

        $stmt = $this->pdo->prepare($sql);
        foreach ($bind as $k => $v) {
            $stmt->bindValue($k, $v, \PDO::PARAM_INT);
        }
        $stmt->execute();
        $list = $stmt->fetchAll(\PDO::FETCH_ASSOC);

        // 格式化返回数据，确保数值类型正确
        foreach ($list as &$item) {
            $item['vod_id'] = intval($item['vod_id']);
            $item['vod_year'] = intval($item['vod_year'] ?: 0);
            $item['vod_score'] = floatval($item['vod_score'] ?: 0);
            $item['vod_hits'] = intval($item['vod_hits'] ?: 0);
            
            // 确保字符串字段不为null
            $item['vod_class'] = $item['vod_class'] ?: '';
            $item['vod_director'] = $item['vod_director'] ?: '';
            $item['vod_actor'] = $item['vod_actor'] ?: '';
            $item['vod_content'] = $item['vod_content'] ?: '';
            $item['vod_remarks'] = $item['vod_remarks'] ?: '';
            $item['vod_lang'] = $item['vod_lang'] ?: '';
        }

        response_success($list);
    }

    // 获取日榜
    public function getDayTop($params) {
        $sql = "SELECT vod_id, vod_name, vod_content, vod_pic, vod_remarks, vod_lang, vod_year,
                       vod_class, vod_director, vod_actor, vod_score, vod_hits_day
                FROM " . DB_PREFIX . "vod ";
        $where = [];
        $bind = [];

        if (!empty($params['type'])) {
            $where[] = "type_id = :type_id";
            $bind[':type_id'] = intval($params['type']);
        }

        if ($where) {
            $sql .= "WHERE " . implode(' AND ', $where) . " ";
        }

        $sql .= "ORDER BY vod_hits_day DESC LIMIT 10";

        $stmt = $this->pdo->prepare($sql);
        foreach ($bind as $k => $v) {
            $stmt->bindValue($k, $v, \PDO::PARAM_INT);
        }
        $stmt->execute();
        $list = $stmt->fetchAll(\PDO::FETCH_ASSOC);

        // 格式化返回数据，确保数值类型正确
        foreach ($list as &$item) {
            $item['vod_id'] = intval($item['vod_id']);
            $item['vod_year'] = intval($item['vod_year'] ?: 0);
            $item['vod_score'] = floatval($item['vod_score'] ?: 0);
            $item['vod_hits_day'] = intval($item['vod_hits_day'] ?: 0);
            
            // 确保字符串字段不为null
            $item['vod_class'] = $item['vod_class'] ?: '';
            $item['vod_director'] = $item['vod_director'] ?: '';
            $item['vod_actor'] = $item['vod_actor'] ?: '';
            $item['vod_content'] = $item['vod_content'] ?: '';
            $item['vod_remarks'] = $item['vod_remarks'] ?: '';
            $item['vod_lang'] = $item['vod_lang'] ?: '';
        }

        response_success($list);
    }
}
