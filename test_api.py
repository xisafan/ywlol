#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
API接口测试脚本
用于测试外部API服务器连接和响应
"""

import requests
import json
import pymysql
import time
from typing import Dict, Any

class APITester:
    def __init__(self):
        # API基础URL
        self.base_url = "http://156.238.253.228:6466/api.php"
        
        # 数据库配置
        self.db_config = {
            'host': '127.0.0.1',
            'user': 'maccms',
            'password': 'maccms', 
            'database': 'dmw_0606666_xyz_',
            'charset': 'utf8mb4'
        }
        
        # 请求头
        self.headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'OVO-Test-Client/1.0'
        }

    def test_api_endpoint(self, path: str, params: Dict[str, Any] = None) -> Dict[str, Any]:
        """测试API端点"""
        try:
            print(f"\n🧪 测试API: {path}")
            print(f"📡 完整URL: {self.base_url}")
            print(f"📊 查询参数: {params}")
            
            # 构造查询参数，使用s参数格式
            query_params = {'s': f'/api/v1{path}'}
            if params:
                query_params.update(params)
                
            response = requests.get(
                self.base_url,
                params=query_params,
                headers=self.headers,
                timeout=10
            )
            
            print(f"📈 状态码: {response.status_code}")
            print(f"📝 响应头: {dict(response.headers)}")
            
            if response.status_code == 200:
                try:
                    data = response.json()
                    print(f"✅ 响应数据: {json.dumps(data, ensure_ascii=False, indent=2)}")
                    return data
                except json.JSONDecodeError as e:
                    print(f"❌ JSON解析失败: {e}")
                    print(f"📄 原始响应: {response.text}")
                    return {"error": "JSON解析失败", "raw": response.text}
            else:
                print(f"❌ 请求失败: {response.status_code}")
                print(f"📄 错误响应: {response.text}")
                return {"error": f"HTTP {response.status_code}", "message": response.text}
                
        except requests.exceptions.RequestException as e:
            print(f"❌ 网络请求失败: {e}")
            return {"error": "网络错误", "message": str(e)}

    def create_xp_lv_table(self):
        """直接创建xp_lv表"""
        try:
            print("\n🗄️ 连接数据库创建xp_lv表...")
            
            connection = pymysql.connect(**self.db_config)
            cursor = connection.cursor()
            
            # 创建xp_lv表的SQL
            create_table_sql = """
            CREATE TABLE IF NOT EXISTS `xp_lv` (
              `id` int(11) NOT NULL AUTO_INCREMENT,
              `lv` int(11) NOT NULL COMMENT '等级',
              `xp` int(11) NOT NULL COMMENT '达到该等级所需经验值',
              `level_name` varchar(50) NOT NULL DEFAULT '' COMMENT '等级名称',
              `level_icon` varchar(255) NOT NULL DEFAULT '' COMMENT '等级图标',
              `privileges` text COMMENT '等级特权',
              `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
              `update_time` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
              PRIMARY KEY (`id`),
              UNIQUE KEY `lv` (`lv`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='用户经验等级表'
            """
            
            cursor.execute(create_table_sql)
            print("✅ xp_lv表创建成功")
            
            # 插入默认数据
            insert_data_sql = """
            INSERT IGNORE INTO `xp_lv` (`lv`, `xp`, `level_name`, `level_icon`, `privileges`) VALUES
            (1, 0, '新手', '/assets/icon/lv/lv1.png', '{"daily_sign": true}'),
            (2, 100, '初级用户', '/assets/icon/lv/lv2.png', '{"daily_sign": true, "comment": true}'),
            (3, 300, '活跃用户', '/assets/icon/lv/lv3.png', '{"daily_sign": true, "comment": true, "upload": true}'),
            (4, 600, '资深用户', '/assets/icon/lv/lv4.png', '{"daily_sign": true, "comment": true, "upload": true, "priority_support": true}'),
            (5, 1000, '专家用户', '/assets/icon/lv/lv5.png', '{"daily_sign": true, "comment": true, "upload": true, "priority_support": true, "advanced_features": true}'),
            (6, 1500, '超级用户', '/assets/icon/lv/lv6.png', '{"daily_sign": true, "comment": true, "upload": true, "priority_support": true, "advanced_features": true, "exclusive_content": true}'),
            (7, 2100, '传奇用户', '/assets/icon/lv/lv7.png', '{"daily_sign": true, "comment": true, "upload": true, "priority_support": true, "advanced_features": true, "exclusive_content": true, "custom_avatar": true}'),
            (8, 2800, '大师级', '/assets/icon/lv/lv8.png', '{"daily_sign": true, "comment": true, "upload": true, "priority_support": true, "advanced_features": true, "exclusive_content": true, "custom_avatar": true, "moderator": true}'),
            (9, 3600, '宗师级', '/assets/icon/lv/lv9.png', '{"daily_sign": true, "comment": true, "upload": true, "priority_support": true, "advanced_features": true, "exclusive_content": true, "custom_avatar": true, "moderator": true, "special_badge": true}')
            """
            
            cursor.execute(insert_data_sql)
            connection.commit()
            print("✅ 默认等级数据插入成功")
            
            # 验证数据
            cursor.execute("SELECT COUNT(*) FROM xp_lv")
            count = cursor.fetchone()[0]
            print(f"📊 xp_lv表中有 {count} 条记录")
            
            cursor.close()
            connection.close()
            return True
            
        except Exception as e:
            print(f"❌ 数据库操作失败: {e}")
            return False

    def run_tests(self):
        """运行所有测试"""
        print("🚀 开始API接口测试")
        print("=" * 50)
        
        # 1. 先创建缺失的数据库表
        print("\n📋 步骤1: 创建数据库表")
        self.create_xp_lv_table()
        
        # 2. 测试基础连接
        print("\n📋 步骤2: 测试API基础连接")
        self.test_api_endpoint("/types")
        
        # 3. 测试xp_lv接口
        print("\n📋 步骤3: 测试xp_lv接口")
        self.test_api_endpoint("/xp_lv")
        
        # 4. 测试banners接口
        print("\n📋 步骤4: 测试banners接口")
        self.test_api_endpoint("/banners")
        
        # 5. 测试hotvedios接口
        print("\n📋 步骤5: 测试hotvedios接口")
        self.test_api_endpoint("/hotvedios")
        
        # 6. 测试schedule接口
        print("\n📋 步骤6: 测试schedule接口") 
        self.test_api_endpoint("/schedule")
        
        # 7. 测试check_update接口
        print("\n📋 步骤7: 测试check_update接口")
        self.test_api_endpoint("/check_update", {"platform": "android", "version": "1.0.0"})
        
        print("\n🎉 测试完成!")

if __name__ == "__main__":
    try:
        # 安装依赖提示
        print("📦 确保已安装依赖: pip install requests pymysql")
        print("⏳ 等待3秒后开始测试...")
        time.sleep(3)
        
        tester = APITester()
        tester.run_tests()
        
    except KeyboardInterrupt:
        print("\n⚠️ 测试被用户中断")
    except Exception as e:
        print(f"\n❌ 测试过程中发生错误: {e}")
        import traceback
        traceback.print_exc()
