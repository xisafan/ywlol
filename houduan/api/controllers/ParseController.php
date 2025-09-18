<?php
/**
 * 解析控制器
 * 
 * 处理视频解析相关的API请求
 * 
 * @author ovo
 * @version 1.0.0
 * @date 2025-05-20
 */

class ParseController {
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
     * 获取解析器列表
     * 
     * @return void
     */
    public function getList() {
        try {
            // 查询解析器列表
            $sql = "SELECT `id`, `name`, `resolution`, `player_type`, `encoding`, `sort`, `status` 
                   FROM `" . DB_PREFIX . "ovo_parser` 
                   WHERE `status` = 1 
                   ORDER BY `sort` ASC, `id` DESC";
            
            $stmt = $this->pdo->prepare($sql);
            $stmt->execute();
            $parsers = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // 返回解析器列表
            $response_data = [
                'list' => $parsers
            ];
            
            response_success($response_data);
        } catch (Exception $e) {
            response_error(500, '获取解析器列表失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 解析视频地址
     * 
     * @param array $params 请求参数
     * @return void
     */
    public function parseUrl($params) {
        // 验证参数
        if (!isset($params['url']) || empty($params['url'])) {
            response_error(400, '视频地址不能为空');
        }
        
        $url = trim($params['url']);
        $parser_id = isset($params['parser_id']) ? intval($params['parser_id']) : 0;
        
        try {
            // 如果指定了解析器ID，则使用指定的解析器
            if ($parser_id > 0) {
                $sql = "SELECT * FROM `" . DB_PREFIX . "ovo_parser` WHERE `id` = :id AND `status` = 1 LIMIT 1";
                $stmt = $this->pdo->prepare($sql);
                $stmt->bindParam(':id', $parser_id);
                $stmt->execute();
                $parser = $stmt->fetch(PDO::FETCH_ASSOC);
                
                if (!$parser) {
                    response_error(404, '指定的解析器不存在或已禁用');
                }
                
                // 使用指定解析器解析视频
                $result = $this->doParseUrl($url, $parser);
                response_success($result);
            } else {
                // 否则，尝试所有可用的解析器
                $sql = "SELECT * FROM `" . DB_PREFIX . "ovo_parser` WHERE `status` = 1 ORDER BY `sort` ASC, `id` DESC";
                $stmt = $this->pdo->prepare($sql);
                $stmt->execute();
                $parsers = $stmt->fetchAll(PDO::FETCH_ASSOC);
                
                if (empty($parsers)) {
                    response_error(404, '没有可用的解析器');
                }
                
                // 尝试每个解析器
                $error_messages = [];
                foreach ($parsers as $parser) {
                    try {
                        $result = $this->doParseUrl($url, $parser);
                        response_success($result);
                    } catch (Exception $e) {
                        $error_messages[] = $parser['name'] . ': ' . $e->getMessage();
                    }
                }
                
                // 如果所有解析器都失败，返回错误
                response_error(500, '所有解析器都失败: ' . implode('; ', $error_messages));
            }
        } catch (Exception $e) {
            response_error(500, '解析视频地址失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 执行视频地址解析
     * 
     * @param string $url 视频地址
     * @param array $parser 解析器信息
     * @return array 解析结果
     * @throws Exception 解析失败时抛出异常
     */
    private function doParseUrl($url, $parser) {
        // 解析方法
        $parse_method = $parser['parse_method'];
        
        // 解析链接
        $parse_url = $parser['parse_url'];
        
        // 根据解析方法执行不同的解析逻辑
        switch ($parse_method) {
            case 'api':
                // API方式解析
                return $this->parseByApi($url, $parse_url);
                
            case 'iframe':
                // iframe方式解析
                return $this->parseByIframe($url, $parse_url);
                
            case 'js':
                // JS方式解析
                return $this->parseByJs($url, $parse_url);
                
            default:
                throw new Exception('不支持的解析方法: ' . $parse_method);
        }
    }
    
    /**
     * API方式解析视频地址
     * 
     * @param string $url 视频地址
     * @param string $parse_url 解析API地址
     * @return array 解析结果
     * @throws Exception 解析失败时抛出异常
     */
    private function parseByApi($url, $parse_url) {
        // 替换API地址中的占位符
        $api_url = str_replace('{url}', urlencode($url), $parse_url);
        
        // 发送HTTP请求
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $api_url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 10);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
        curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36');
        
        $response = curl_exec($ch);
        $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curl_error = curl_error($ch);
        curl_close($ch);
        
        if ($http_code != 200) {
            throw new Exception('HTTP请求失败: ' . $http_code . ' ' . $curl_error);
        }
        
        if (empty($response)) {
            throw new Exception('解析接口返回空数据');
        }
        
        // 尝试解析JSON响应
        $data = json_decode($response, true);
        if ($data === null) {
            // 如果不是JSON，尝试直接提取URL
            if (preg_match('/https?:\/\/[^\s"\'<>]+\.(mp4|m3u8|flv|avi|mkv|rm|wmv|mpg|mpeg)/i', $response, $matches)) {
                return [
                    'play_url' => $matches[0],
                    'headers' => [
                        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                        'Referer' => parse_url($api_url, PHP_URL_HOST)
                    ]
                ];
            } else {
                throw new Exception('解析接口返回的数据格式不正确');
            }
        }
        
        // 提取播放地址
        if (isset($data['url']) || isset($data['data']['url']) || isset($data['data']['play_url'])) {
            $play_url = isset($data['url']) ? $data['url'] : (isset($data['data']['url']) ? $data['data']['url'] : $data['data']['play_url']);
            
            // 提取请求头
            $headers = [];
            if (isset($data['headers']) || isset($data['data']['headers'])) {
                $headers = isset($data['headers']) ? $data['headers'] : $data['data']['headers'];
            } else {
                $headers = [
                    'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                    'Referer' => parse_url($api_url, PHP_URL_HOST)
                ];
            }
            
            return [
                'play_url' => $play_url,
                'headers' => $headers
            ];
        } else {
            throw new Exception('解析接口返回的数据中没有找到播放地址');
        }
    }
    
    /**
     * iframe方式解析视频地址
     * 
     * @param string $url 视频地址
     * @param string $parse_url 解析iframe地址
     * @return array 解析结果
     */
    private function parseByIframe($url, $parse_url) {
        // 替换iframe地址中的占位符
        $iframe_url = str_replace('{url}', urlencode($url), $parse_url);
        
        // 返回iframe地址
        return [
            'iframe_url' => $iframe_url,
            'type' => 'iframe'
        ];
    }
    
    /**
     * JS方式解析视频地址
     * 
     * @param string $url 视频地址
     * @param string $parse_url 解析JS代码
     * @return array 解析结果
     * @throws Exception 解析失败时抛出异常
     */
    private function parseByJs($url, $parse_url) {
        // 这里简化处理，实际应该使用JS引擎执行解析代码
        // 由于PHP环境中执行JS比较复杂，这里返回一个提示
        throw new Exception('JS方式解析需要在客户端实现');
    }
}
