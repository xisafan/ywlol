#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
排期表API功能测试脚本

测试改进后的排期表API，验证多种星期格式的支持情况。

使用方法：
1. 修改下面的API_BASE_URL为你的实际API地址
2. 运行脚本：python test_schedule_api.py
"""

import requests
import json
from typing import Optional, Dict, Any

# 配置
API_BASE_URL = (
    "http://156.238.253.228:6466/api.php/v1/schedule"  # 修改为你的实际API地址
)


def test_schedule_api(weekday: Optional[str] = None) -> Dict[str, Any]:
    """
    测试排期表API

    Args:
        weekday: 星期参数，支持多种格式

    Returns:
        API响应结果
    """
    try:
        params = {}
        if weekday is not None:
            params["weekday"] = weekday

        response = requests.get(API_BASE_URL, params=params, timeout=10)
        response.raise_for_status()

        return {
            "success": True,
            "status_code": response.status_code,
            "data": response.json(),
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "status_code": (
                getattr(e.response, "status_code", None)
                if hasattr(e, "response")
                else None
            ),
        }


def main():
    """主测试函数"""
    print("=" * 80)
    print("排期表API功能测试")
    print("=" * 80)
    print()

    # 测试用例
    test_cases = [
        # 数字格式
        {"weekday": "1", "description": "数字 1（星期一）"},
        {"weekday": "7", "description": "数字 7（星期日）"},
        {"weekday": "0", "description": "数字 0（星期日）"},
        # 中文简写
        {"weekday": "一", "description": "中文简写：一"},
        {"weekday": "二", "description": "中文简写：二"},
        {"weekday": "日", "description": "中文简写：日"},
        {"weekday": "天", "description": "中文简写：天"},
        # 中文完整
        {"weekday": "星期一", "description": "中文完整：星期一"},
        {"weekday": "星期日", "description": "中文完整：星期日"},
        # 英文简写
        {"weekday": "Mon", "description": "英文简写：Mon"},
        {"weekday": "Sun", "description": "英文简写：Sun"},
        # 英文完整
        {"weekday": "Monday", "description": "英文完整：Monday"},
        {"weekday": "Sunday", "description": "英文完整：Sunday"},
        # 无效参数测试
        {"weekday": "invalid", "description": "无效参数测试"},
        {"weekday": "8", "description": "超出范围的数字"},
        # 不传参数
        {"weekday": None, "description": "不传参数（获取全部）"},
    ]

    success_count = 0
    total_count = len(test_cases)

    for i, test_case in enumerate(test_cases, 1):
        weekday = test_case["weekday"]
        description = test_case["description"]

        print(f"测试 {i}: {description}")
        print(f"参数: {weekday if weekday is not None else 'None'}")

        result = test_schedule_api(weekday)

        if result["success"]:
            data = result["data"]

            if data.get("code") == 0:
                print("✅ 测试通过")
                success_count += 1

                # 显示解析结果
                if "data" in data and "current_filter" in data["data"]:
                    filter_info = data["data"]["current_filter"]
                    weekday_param = filter_info.get("weekday_param", "None")
                    chinese_name = filter_info.get("chinese_name", "未知")
                    parsed_weekday = filter_info.get("parsed_weekday", 0)
                    print(
                        f"解析结果: 参数 '{weekday_param}' 解析为 '{chinese_name}' (数字: {parsed_weekday})"
                    )

                # 显示数据统计
                if "data" in data and "schedule" in data["data"]:
                    schedule = data["data"]["schedule"]
                    total_videos = sum(len(videos) for videos in schedule.values())
                    print(f"返回数据: 共 {total_videos} 个视频")

                    # 显示每天的视频数量
                    for day, videos in schedule.items():
                        if videos:  # 只显示有视频的天数
                            print(f"  星期{day}: {len(videos)} 个视频")

            else:
                print("❌ 测试失败")
                print(f"错误信息: {data.get('msg', '未知错误')}")
        else:
            print("❌ 测试失败")
            print(f"错误信息: {result['error']}")
            if result.get("status_code"):
                print(f"HTTP状态码: {result['status_code']}")

        print("-" * 60)
        print()

    # 显示测试统计
    print("=" * 80)
    print("测试统计")
    print("=" * 80)
    print(f"总测试数: {total_count}")
    print(f"通过数: {success_count}")
    print(f"失败数: {total_count - success_count}")
    print(f"通过率: {success_count/total_count*100:.2f}%")
    print()

    # 显示API使用示例
    print("=" * 80)
    print("API使用示例")
    print("=" * 80)
    print("支持的星期格式:")
    print("- 数字: 1-7 (1=星期一, 7=星期日)")
    print("- 中文简写: 一,二,三,四,五,六,日,天")
    print("- 中文完整: 星期一,星期二,星期三,星期四,星期五,星期六,星期日,星期天")
    print("- 英文简写: Mon,Tue,Wed,Thu,Fri,Sat,Sun")
    print("- 英文完整: Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday")
    print()

    print("调用示例:")
    print(f"GET {API_BASE_URL}?weekday=一")
    print(f"GET {API_BASE_URL}?weekday=星期一")
    print(f"GET {API_BASE_URL}?weekday=Monday")
    print(f"GET {API_BASE_URL}?weekday=1")
    print(f"GET {API_BASE_URL}  # 获取全部")


if __name__ == "__main__":
    main()
