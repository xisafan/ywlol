<?php
/**
 * 评论控制器
 * 
 * 提供评论相关的API接口
 * 
 * @author ovo
 * @version 1.0.1
 * @date 2025-05-24
 */

namespace app\api\controllers;

class CommentController {
    private $pdo;
    
    /**
     * 构造函数
     * 
     * @param \PDO $pdo PDO实例
     */
    public function __construct($pdo) {
        $this->pdo = $pdo;
    }
    
    /**
     * 获取评论列表
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function getComments($params) {
        // 验证参数
        if (!isset($params['vod_id']) || empty($params['vod_id'])) {
            response_error(400, '缺少必要参数: vod_id');
        }
        
        $vodId = intval($params['vod_id']);
        $page = isset($params['page']) ? intval($params['page']) : 1;
        $limit = isset($params['limit']) ? intval($params['limit']) : 20;
        
        // 计算偏移量
        $offset = ($page - 1) * $limit;
        
        try {
            // 获取评论总数
            $countStmt = $this->pdo->prepare("
                SELECT COUNT(*) as total 
                FROM " . DB_PREFIX . "comment 
                WHERE comment_rid = :vod_id AND comment_pid = 0 AND comment_status = 1
            ");
            $countStmt->bindParam(':vod_id', $vodId, \PDO::PARAM_INT);
            $countStmt->execute();
            $totalResult = $countStmt->fetch(\PDO::FETCH_ASSOC);
            $total = $totalResult['total'];
            
            // 计算总页数
            $pages = ceil($total / $limit);
            
            // 获取主评论列表 - 修复：使用字符串拼接方式处理LIMIT参数
            $stmt = $this->pdo->prepare("
                SELECT * 
                FROM " . DB_PREFIX . "comment 
                WHERE comment_rid = :vod_id AND comment_pid = 0 AND comment_status = 1
                ORDER BY comment_time DESC 
                LIMIT " . intval($offset) . ", " . intval($limit) . "
            ");
            $stmt->bindParam(':vod_id', $vodId, \PDO::PARAM_INT);
            $stmt->execute();
            $comments = $stmt->fetchAll(\PDO::FETCH_ASSOC);
            
            // 获取每个主评论的回复
            foreach ($comments as &$comment) {
                // 类型转换：确保数字字段为整数类型
                $comment['comment_id'] = (int)$comment['comment_id'];
                $comment['comment_mid'] = (int)$comment['comment_mid'];
                $comment['comment_rid'] = (int)$comment['comment_rid'];
                $comment['comment_pid'] = (int)$comment['comment_pid'];
                $comment['user_id'] = (int)$comment['user_id'];
                $comment['comment_status'] = (int)$comment['comment_status'];
                $comment['comment_time'] = (int)$comment['comment_time'];
                $comment['comment_up'] = (int)$comment['comment_up'];
                $comment['comment_down'] = (int)$comment['comment_down'];
                $comment['comment_reply'] = (int)$comment['comment_reply'];
                
                $commentId = $comment['comment_id'];
                
                // 获取回复数量
                $replyCountStmt = $this->pdo->prepare("
                    SELECT COUNT(*) as reply_count 
                    FROM " . DB_PREFIX . "comment 
                    WHERE comment_pid = :comment_id AND comment_status = 1
                ");
                $replyCountStmt->bindParam(':comment_id', $commentId, \PDO::PARAM_INT);
                $replyCountStmt->execute();
                $replyCountResult = $replyCountStmt->fetch(\PDO::FETCH_ASSOC);
                $comment['comment_reply'] = (int)$replyCountResult['reply_count'];
                
                // 获取回复列表
                $replyStmt = $this->pdo->prepare("
                    SELECT * 
                    FROM " . DB_PREFIX . "comment 
                    WHERE comment_pid = :comment_id AND comment_status = 1
                    ORDER BY comment_time ASC
                ");
                $replyStmt->bindParam(':comment_id', $commentId, \PDO::PARAM_INT);
                $replyStmt->execute();
                $replies = $replyStmt->fetchAll(\PDO::FETCH_ASSOC);
                
                // 为回复数据也进行类型转换
                foreach ($replies as &$reply) {
                    $reply['comment_id'] = (int)$reply['comment_id'];
                    $reply['comment_mid'] = (int)$reply['comment_mid'];
                    $reply['comment_rid'] = (int)$reply['comment_rid'];
                    $reply['comment_pid'] = (int)$reply['comment_pid'];
                    $reply['user_id'] = (int)$reply['user_id'];
                    $reply['comment_status'] = (int)$reply['comment_status'];
                    $reply['comment_time'] = (int)$reply['comment_time'];
                    $reply['comment_up'] = (int)$reply['comment_up'];
                    $reply['comment_down'] = (int)$reply['comment_down'];
                    $reply['comment_reply'] = (int)$reply['comment_reply'];
                }
                
                $comment['replies'] = $replies;
            }
            
            // 如果没有评论，返回空数组而不是null
            if (empty($comments)) {
                $comments = [];
            }
            
            // 返回结果
            response_success([
                'list' => $comments,
                'total' => $total,
                'page' => $page,
                'limit' => $limit,
                'pages' => $pages
            ]);
        } catch (\Exception $e) {
            // 记录错误日志
            error_log('获取评论列表失败: ' . $e->getMessage());
            
            // 返回空结果而不是错误，避免前端崩溃
            response_success([
                'list' => [],
                'total' => 0,
                'page' => $page,
                'limit' => $limit,
                'pages' => 0
            ]);
        }
    }
    
    /**
     * 添加评论
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function addComment($params) {
        // 验证参数
        if (!isset($params['vod_id']) || empty($params['vod_id'])) {
            response_error(400, '缺少必要参数: vod_id');
        }
        
        if (!isset($params['content']) || empty($params['content'])) {
            response_error(400, '缺少必要参数: content');
        }
        
        $vodId = intval($params['vod_id']);
        $content = trim($params['content']);
        $pid = isset($params['pid']) ? intval($params['pid']) : 0;
        $userId = isset($params['user_id']) ? intval($params['user_id']) : 0;
        $userName = isset($params['user_name']) ? trim($params['user_name']) : '游客';
        
        // 内容长度限制
        if (mb_strlen($content) > 500) {
            response_error(400, '评论内容不能超过500个字符');
        }
        
        try {
            // 检查视频是否存在
            $videoStmt = $this->pdo->prepare("
                SELECT vod_id 
                FROM " . DB_PREFIX . "vod 
                WHERE vod_id = :vod_id
            ");
            $videoStmt->bindParam(':vod_id', $vodId, \PDO::PARAM_INT);
            $videoStmt->execute();
            
            if ($videoStmt->rowCount() == 0) {
                response_error(404, '视频不存在');
            }
            
            // 如果是回复，检查父评论是否存在
            if ($pid > 0) {
                $parentStmt = $this->pdo->prepare("
                    SELECT comment_id 
                    FROM " . DB_PREFIX . "comment 
                    WHERE comment_id = :pid AND comment_status = 1
                ");
                $parentStmt->bindParam(':pid', $pid, \PDO::PARAM_INT);
                $parentStmt->execute();
                
                if ($parentStmt->rowCount() == 0) {
                    response_error(404, '回复的评论不存在或已被删除');
                }
            }
            
            // 添加评论
            $now = time();
            $stmt = $this->pdo->prepare("
                INSERT INTO " . DB_PREFIX . "comment (
                    comment_mid, comment_rid, comment_pid, user_id, 
                    comment_status, comment_name, comment_time, 
                    comment_content, comment_up, comment_down, comment_reply
                ) VALUES (
                    1, :vod_id, :pid, :user_id, 
                    1, :user_name, :comment_time, 
                    :content, 0, 0, 0
                )
            ");
            
            $stmt->bindParam(':vod_id', $vodId, \PDO::PARAM_INT);
            $stmt->bindParam(':pid', $pid, \PDO::PARAM_INT);
            $stmt->bindParam(':user_id', $userId, \PDO::PARAM_INT);
            $stmt->bindParam(':user_name', $userName, \PDO::PARAM_STR);
            $stmt->bindParam(':comment_time', $now, \PDO::PARAM_INT);
            $stmt->bindParam(':content', $content, \PDO::PARAM_STR);
            $stmt->execute();
            
            $commentId = $this->pdo->lastInsertId();
            
            // 如果是回复，更新父评论的回复数
            if ($pid > 0) {
                $updateStmt = $this->pdo->prepare("
                    UPDATE " . DB_PREFIX . "comment 
                    SET comment_reply = comment_reply + 1 
                    WHERE comment_id = :pid
                ");
                $updateStmt->bindParam(':pid', $pid, \PDO::PARAM_INT);
                $updateStmt->execute();
            }
            
            // 返回新评论数据
            $newCommentStmt = $this->pdo->prepare("
                SELECT * 
                FROM " . DB_PREFIX . "comment 
                WHERE comment_id = :comment_id
            ");
            $newCommentStmt->bindParam(':comment_id', $commentId, \PDO::PARAM_INT);
            $newCommentStmt->execute();
            $newComment = $newCommentStmt->fetch(\PDO::FETCH_ASSOC);
            
            // 类型转换：确保数字字段为整数类型
            if ($newComment) {
                $newComment['comment_id'] = (int)$newComment['comment_id'];
                $newComment['comment_mid'] = (int)$newComment['comment_mid'];
                $newComment['comment_rid'] = (int)$newComment['comment_rid'];
                $newComment['comment_pid'] = (int)$newComment['comment_pid'];
                $newComment['user_id'] = (int)$newComment['user_id'];
                $newComment['comment_status'] = (int)$newComment['comment_status'];
                $newComment['comment_time'] = (int)$newComment['comment_time'];
                $newComment['comment_up'] = (int)$newComment['comment_up'];
                $newComment['comment_down'] = (int)$newComment['comment_down'];
                $newComment['comment_reply'] = (int)$newComment['comment_reply'];
            }
            
            response_success([
                'comment_id' => $commentId,
                'comment' => $newComment
            ]);
        } catch (\Exception $e) {
            // 记录错误日志
            error_log('添加评论失败: ' . $e->getMessage());
            response_error(500, '添加评论失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 点赞评论
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function likeComment($params) {
        // 验证参数
        if (!isset($params['comment_id']) || empty($params['comment_id'])) {
            response_error(400, '缺少必要参数: comment_id');
        }
        
        $commentId = intval($params['comment_id']);
        $userId = isset($params['user_id']) ? intval($params['user_id']) : 0;
        
        try {
            // 检查评论是否存在
            $checkStmt = $this->pdo->prepare("
                SELECT comment_id, comment_up 
                FROM " . DB_PREFIX . "comment 
                WHERE comment_id = :comment_id AND comment_status = 1
            ");
            $checkStmt->bindParam(':comment_id', $commentId, \PDO::PARAM_INT);
            $checkStmt->execute();
            
            if ($checkStmt->rowCount() == 0) {
                response_error(404, '评论不存在或已被删除');
            }
            
            $comment = $checkStmt->fetch(\PDO::FETCH_ASSOC);
            
            // 更新点赞数
            $upCount = $comment['comment_up'] + 1;
            $updateStmt = $this->pdo->prepare("
                UPDATE " . DB_PREFIX . "comment 
                SET comment_up = :up_count 
                WHERE comment_id = :comment_id
            ");
            $updateStmt->bindParam(':up_count', $upCount, \PDO::PARAM_INT);
            $updateStmt->bindParam(':comment_id', $commentId, \PDO::PARAM_INT);
            $updateStmt->execute();
            
            // 记录用户点赞行为（实际应用中应该检查用户是否已点赞）
            if ($userId > 0) {
                // 这里可以添加用户点赞记录的逻辑
            }
            
            response_success([
                'comment_id' => $commentId,
                'up_count' => $upCount
            ]);
        } catch (\Exception $e) {
            // 记录错误日志
            error_log('点赞评论失败: ' . $e->getMessage());
            response_error(500, '点赞评论失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 删除评论
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function deleteComment($params) {
        // 验证参数
        if (!isset($params['comment_id']) || empty($params['comment_id'])) {
            response_error(400, '缺少必要参数: comment_id');
        }
        
        $commentId = intval($params['comment_id']);
        $userId = isset($params['user_id']) ? intval($params['user_id']) : 0;
        $isAdmin = isset($params['is_admin']) ? intval($params['is_admin']) : 0;
        
        try {
            // 检查评论是否存在
            $checkStmt = $this->pdo->prepare("
                SELECT comment_id, user_id, comment_pid 
                FROM " . DB_PREFIX . "comment 
                WHERE comment_id = :comment_id AND comment_status = 1
            ");
            $checkStmt->bindParam(':comment_id', $commentId, \PDO::PARAM_INT);
            $checkStmt->execute();
            
            if ($checkStmt->rowCount() == 0) {
                response_error(404, '评论不存在或已被删除');
            }
            
            $comment = $checkStmt->fetch(\PDO::FETCH_ASSOC);
            
            // 检查权限（只有评论作者或管理员可以删除）
            if ($comment['user_id'] != $userId && !$isAdmin) {
                response_error(403, '没有权限删除此评论');
            }
            
            // 软删除评论（将状态设为0）
            $deleteStmt = $this->pdo->prepare("
                UPDATE " . DB_PREFIX . "comment 
                SET comment_status = 0 
                WHERE comment_id = :comment_id
            ");
            $deleteStmt->bindParam(':comment_id', $commentId, \PDO::PARAM_INT);
            $deleteStmt->execute();
            
            // 如果是主评论，同时删除所有回复
            if ($comment['comment_pid'] == 0) {
                $deleteRepliesStmt = $this->pdo->prepare("
                    UPDATE " . DB_PREFIX . "comment 
                    SET comment_status = 0 
                    WHERE comment_pid = :comment_id
                ");
                $deleteRepliesStmt->bindParam(':comment_id', $commentId, \PDO::PARAM_INT);
                $deleteRepliesStmt->execute();
            } else {
                // 如果是回复，更新父评论的回复数
                $updateParentStmt = $this->pdo->prepare("
                    UPDATE " . DB_PREFIX . "comment 
                    SET comment_reply = comment_reply - 1 
                    WHERE comment_id = :pid AND comment_reply > 0
                ");
                $updateParentStmt->bindParam(':pid', $comment['comment_pid'], \PDO::PARAM_INT);
                $updateParentStmt->execute();
            }
            
            response_success();
        } catch (\Exception $e) {
            // 记录错误日志
            error_log('删除评论失败: ' . $e->getMessage());
            response_error(500, '删除评论失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 模拟评论数据（当数据库查询失败时使用）
     * 
     * @param int $vodId 视频ID
     * @return array 模拟评论数据
     */
    private function getMockComments($vodId) {
        return [
            [
                'comment_id' => 1,
                'comment_mid' => 1,
                'comment_rid' => $vodId,
                'comment_pid' => 0,
                'user_id' => 1,
                'comment_status' => 1,
                'comment_name' => '月见草',
                'comment_time' => time() - 86400 * 3,
                'comment_content' => '延迟到明天了？',
                'comment_up' => 42,
                'comment_down' => 0,
                'comment_reply' => 0,
                'user_portrait' => '',
                'replies' => []
            ],
            [
                'comment_id' => 2,
                'comment_mid' => 1,
                'comment_rid' => $vodId,
                'comment_pid' => 0,
                'user_id' => 2,
                'comment_status' => 1,
                'comment_name' => '伊甸园里的蛇',
                'comment_time' => time() - 86400 * 9,
                'comment_content' => '内鬼，恐怖是，新来的电索官',
                'comment_up' => 18,
                'comment_down' => 2,
                'comment_reply' => 0,
                'user_portrait' => '',
                'replies' => []
            ],
            [
                'comment_id' => 3,
                'comment_mid' => 1,
                'comment_rid' => $vodId,
                'comment_pid' => 0,
                'user_id' => 3,
                'comment_status' => 1,
                'comment_name' => '爱莉爱莉爱',
                'comment_time' => time() - 86400 * 14,
                'comment_content' => '好看吗，值得一看吗？',
                'comment_up' => 7,
                'comment_down' => 1,
                'comment_reply' => 0,
                'user_portrait' => '',
                'replies' => []
            ],
            [
                'comment_id' => 4,
                'comment_mid' => 1,
                'comment_rid' => $vodId,
                'comment_pid' => 0,
                'user_id' => 4,
                'comment_status' => 1,
                'comment_name' => 'Citta',
                'comment_time' => time() - 86400 * 17,
                'comment_content' => '低配版异度侵入？',
                'comment_up' => 15,
                'comment_down' => 3,
                'comment_reply' => 0,
                'user_portrait' => '',
                'replies' => []
            ]
        ];
    }
}
