#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
简化版API测试脚本 - 只需要requests库
"""

import requests
import json

def test_api():
    """测试API接口"""
    base_url = "http://156.238.253.228:6466/api.php"
    
    # 测试的API端点
    endpoints = [
        {"path": "/types", "name": "视频分类"},
        {"path": "/xp_lv", "name": "等级系统"},
        {"path": "/banners", "name": "轮播图"},
        {"path": "/hotvedios", "name": "热门视频"},
        {"path": "/schedule", "name": "排期表"},
        {"path": "/check_update", "name": "版本检查", "params": {"platform": "android", "version": "1.0.0"}}
    ]
    
    print("🚀 开始API接口测试")
    print("=" * 60)
    
    for endpoint in endpoints:
        print(f"\n🧪 测试 {endpoint['name']} - {endpoint['path']}")
        
        try:
            # 构造查询参数（使用s参数格式）
            params = {'s': f'/api/v1{endpoint["path"]}'}
            
            # 添加额外参数
            if 'params' in endpoint:
                params.update(endpoint['params'])
            
            print(f"📡 请求URL: {base_url}")
            print(f"📊 参数: {params}")
            
            response = requests.get(
                base_url,
                params=params,
                headers={
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'User-Agent': 'OVO-Test-Client/1.0'
                },
                timeout=10
            )
            
            print(f"📈 状态码: {response.status_code}")
            
            if response.status_code == 200:
                try:
                    data = response.json()
                    print(f"✅ 成功! 响应数据:")
                    print(json.dumps(data, ensure_ascii=False, indent=2))
                except json.JSONDecodeError:
                    print(f"⚠️ 响应不是JSON格式:")
                    print(response.text[:500] + "..." if len(response.text) > 500 else response.text)
            else:
                print(f"❌ 失败! HTTP {response.status_code}")
                print(f"📄 错误信息: {response.text[:200]}...")
                
        except requests.exceptions.RequestException as e:
            print(f"❌ 网络错误: {e}")
        
        print("-" * 60)
    
    print("\n🎉 测试完成!")

if __name__ == "__main__":
    try:
        test_api()
    except KeyboardInterrupt:
        print("\n⚠️ 测试被用户中断")
    except Exception as e:
        print(f"\n❌ 发生错误: {e}")
