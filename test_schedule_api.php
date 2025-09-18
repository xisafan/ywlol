<?php
/**
 * 测试改进后的排期表API接口
 * 
 * 使用方法：
 * 1. 将此文件放到后端目录
 * 2. 在浏览器中访问：http://your-domain/test_schedule_api.php
 * 3. 查看不同星期格式的API调用结果
 */

// 设置响应头
header('Content-Type: text/html; charset=utf-8');

// 引入API配置
require_once __DIR__ . '/houduan/database.php';
require_once __DIR__ . '/houduan/api/controllers/VideoController.php';

// 数据库连接
$db_config = include(__DIR__ . '/houduan/database.php');
try {
    $dsn = "mysql:host={$db_config['hostname']};port={$db_config['hostport']};dbname={$db_config['database']};charset={$db_config['charset']}";
    $pdo = new PDO($dsn, $db_config['username'], $db_config['password']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->exec("SET NAMES 'utf8mb4'");
    define('DB_PREFIX', $db_config['prefix']);
} catch (PDOException $e) {
    die('数据库连接失败: ' . $e->getMessage());
}

// 创建控制器实例
$controller = new VideoController($pdo);

// 测试用例
$testCases = [
    // 数字格式
    ['weekday' => '1', 'description' => '数字 1（星期一）'],
    ['weekday' => '7', 'description' => '数字 7（星期日）'],
    ['weekday' => '0', 'description' => '数字 0（星期日）'],
    
    // 中文简写
    ['weekday' => '一', 'description' => '中文简写：一'],
    ['weekday' => '二', 'description' => '中文简写：二'],
    ['weekday' => '日', 'description' => '中文简写：日'],
    ['weekday' => '天', 'description' => '中文简写：天'],
    
    // 中文完整
    ['weekday' => '星期一', 'description' => '中文完整：星期一'],
    ['weekday' => '星期日', 'description' => '中文完整：星期日'],
    
    // 英文简写
    ['weekday' => 'Mon', 'description' => '英文简写：Mon'],
    ['weekday' => 'Sun', 'description' => '英文简写：Sun'],
    
    // 英文完整
    ['weekday' => 'Monday', 'description' => '英文完整：Monday'],
    ['weekday' => 'Sunday', 'description' => '英文完整：Sunday'],
    
    // 无效参数测试
    ['weekday' => 'invalid', 'description' => '无效参数测试'],
    ['weekday' => '8', 'description' => '超出范围的数字'],
    
    // 不传参数
    ['weekday' => null, 'description' => '不传参数（获取全部）'],
];

// 开始测试
?>
<!DOCTYPE html>
<html>
<head>
    <title>排期表API测试</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .test-case { border: 1px solid #ddd; margin: 10px 0; padding: 15px; border-radius: 5px; }
        .success { background-color: #d4edda; border-color: #c3e6cb; }
        .error { background-color: #f8d7da; border-color: #f5c6cb; }
        .header { background-color: #e7f3ff; border-color: #b6d7ff; }
        pre { background-color: #f8f9fa; padding: 10px; border-radius: 3px; overflow-x: auto; }
        .stats { margin: 20px 0; padding: 10px; background-color: #fff3cd; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>排期表API功能测试</h1>
    
    <div class="test-case header">
        <h3>测试说明</h3>
        <p>此页面测试改进后的排期表API，验证多种星期格式的支持情况。</p>
        <p>测试的格式包括：数字(1-7)、中文简写(一二三...)、中文完整(星期一...)、英文简写(Mon,Tue...)、英文完整(Monday,Tuesday...)</p>
    </div>

<?php
$successCount = 0;
$totalCount = count($testCases);

foreach ($testCases as $index => $testCase) {
    $weekday = $testCase['weekday'];
    $description = $testCase['description'];
    
    echo "<div class='test-case'>";
    echo "<h3>测试 " . ($index + 1) . ": {$description}</h3>";
    echo "<p><strong>参数:</strong> " . ($weekday === null ? 'null' : "'{$weekday}'") . "</p>";
    
    try {
        // 捕获输出
        ob_start();
        
        // 模拟API调用
        $params = [];
        if ($weekday !== null) {
            $params['weekday'] = $weekday;
        }
        
        $controller->getSchedule($params);
        
        // 不会执行到这里，因为控制器会调用response_success
        $output = ob_get_contents();
        ob_end_clean();
        
    } catch (Exception $e) {
        $output = ob_get_contents();
        ob_end_clean();
        
        // 如果有输出（说明API正常执行），则认为成功
        if (!empty($output)) {
            $result = json_decode($output, true);
            
            if ($result && isset($result['code']) && $result['code'] === 0) {
                echo "<div class='success'>";
                echo "<p><strong>✅ 测试通过</strong></p>";
                
                // 显示解析结果
                if (isset($result['data']['current_filter'])) {
                    $filter = $result['data']['current_filter'];
                    echo "<p><strong>解析结果:</strong> 参数 '{$filter['weekday_param']}' 解析为 '{$filter['chinese_name']}'</p>";
                }
                
                // 显示数据统计
                if (isset($result['data']['schedule'])) {
                    $schedule = $result['data']['schedule'];
                    $totalVideos = 0;
                    foreach ($schedule as $day => $videos) {
                        $totalVideos += count($videos);
                    }
                    echo "<p><strong>返回数据:</strong> 共 {$totalVideos} 个视频</p>";
                }
                
                echo "</div>";
                $successCount++;
            } else {
                echo "<div class='error'>";
                echo "<p><strong>❌ 测试失败</strong></p>";
                echo "<p><strong>错误信息:</strong> " . ($result['msg'] ?? '未知错误') . "</p>";
                echo "</div>";
            }
            
            // 显示完整响应（仅在开发模式下）
            if (isset($_GET['debug'])) {
                echo "<details><summary>查看完整响应</summary>";
                echo "<pre>" . htmlspecialchars(json_encode($result, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT)) . "</pre>";
                echo "</details>";
            }
        } else {
            echo "<div class='error'>";
            echo "<p><strong>❌ 测试失败</strong></p>";
            echo "<p><strong>异常信息:</strong> " . $e->getMessage() . "</p>";
            echo "</div>";
        }
    }
    
    echo "</div>";
}

// 显示测试统计
echo "<div class='stats'>";
echo "<h3>测试统计</h3>";
echo "<p><strong>总测试数:</strong> {$totalCount}</p>";
echo "<p><strong>通过数:</strong> {$successCount}</p>";
echo "<p><strong>失败数:</strong> " . ($totalCount - $successCount) . "</p>";
echo "<p><strong>通过率:</strong> " . round(($successCount / $totalCount) * 100, 2) . "%</p>";
echo "</div>";

?>

    <div class="test-case header">
        <h3>使用说明</h3>
        <ul>
            <li>在URL后面添加 <code>?debug=1</code> 可以查看完整的API响应内容</li>
            <li>绿色表示测试通过，红色表示测试失败</li>
            <li>每个测试会显示参数解析结果和返回的数据统计</li>
        </ul>
        
        <h4>API调用示例:</h4>
        <pre>
// 获取星期一的排期
GET /api/v1/schedule?weekday=一
GET /api/v1/schedule?weekday=星期一  
GET /api/v1/schedule?weekday=Monday
GET /api/v1/schedule?weekday=1

// 获取全部排期
GET /api/v1/schedule
        </pre>
    </div>
    
</body>
</html>
