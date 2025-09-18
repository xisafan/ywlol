<?php
namespace app\api\controllers;

class ScoreController {
    protected $pdo;

    public function __construct($pdo) {
        $this->pdo = $pdo;
    }

    // 1. 通过视频ID获取评分平均值
    public function getAverageScore($params) {
        if (empty($params['vod_id'])) {
            response_error(400, '缺少视频ID');
        }
        $vod_id = $params['vod_id'];
        $stmt = $this->pdo->prepare("SELECT AVG(score) as avg_score FROM mac_ovo_score WHERE vod_id = ?");
        $stmt->execute([$vod_id]);
        $row = $stmt->fetch(\PDO::FETCH_ASSOC);
        $avg = $row['avg_score'] ? round($row['avg_score'], 2) : 0;
        response_success(['vod_id' => $vod_id, 'average_score' => $avg]);
    }

    // 2. 通过视频ID获取该视频所有评分详情
    public function getScoreDetails($params) {
        if (empty($params['vod_id'])) {
            response_error(400, '缺少视频ID');
        }
        $vod_id = $params['vod_id'];
        // 获取平均分
        $stmt = $this->pdo->prepare("SELECT AVG(score) as avg_score FROM mac_ovo_score WHERE vod_id = ?");
        $stmt->execute([$vod_id]);
        $row = $stmt->fetch(\PDO::FETCH_ASSOC);
        $avg = $row['avg_score'] ? round($row['avg_score'], 2) : 0;

        // 获取所有评分详情
        $stmt = $this->pdo->prepare("SELECT username, score, comment, likes FROM mac_ovo_score WHERE vod_id = ? ORDER BY id DESC");
        $stmt->execute([$vod_id]);
        $list = $stmt->fetchAll(\PDO::FETCH_ASSOC);

        response_success([
            'vod_id' => $vod_id,
            'average_score' => $avg,
            'scores' => $list
        ]);
    }

    // 3. 新增评分
    public function addScore($params) {
        if (empty($params['vod_id']) || empty($params['username']) || !isset($params['score']) || !isset($params['comment'])) {
            response_error(400, '参数不完整');
        }
        $vod_id = $params['vod_id'];
        $username = $params['username'];
        $score = floatval($params['score']);
        $comment = $params['comment'];
        $likes = isset($params['likes']) ? intval($params['likes']) : 0;

        $stmt = $this->pdo->prepare("INSERT INTO mac_ovo_score (vod_id, username, score, comment, likes) VALUES (?, ?, ?, ?, ?)");
        $res = $stmt->execute([$vod_id, $username, $score, $comment, $likes]);
        if ($res) {
            response_success(['msg' => '评分成功']);
        } else {
            response_error(500, '评分失败');
        }
    }
}