#!/bin/bash

# iOS IPA打包脚本
# 参数: $1 = 构建类型 (debug/release), $2 = 输出文件名

BUILD_TYPE=${1:-debug}
OUTPUT_NAME=${2:-ovofun}

echo "🍎 开始创建iOS IPA文件..."
echo "构建类型: $BUILD_TYPE"
echo "输出文件名: $OUTPUT_NAME"

# 检查构建目录
if [ ! -d "build/ios/iphoneos" ]; then
    echo "❌ 错误: 未找到iOS构建目录 build/ios/iphoneos"
    exit 1
fi

# 检查Runner.app
if [ ! -d "build/ios/iphoneos/Runner.app" ]; then
    echo "❌ 错误: 未找到Runner.app文件"
    ls -la build/ios/iphoneos/
    exit 1
fi

echo "✅ 找到Runner.app，开始打包..."

# 进入构建目录
cd build/ios/iphoneos

# 清理并创建Payload目录
rm -rf Payload
mkdir Payload

# 复制app文件
cp -r Runner.app Payload/

echo "📦 Payload目录内容:"
ls -la Payload/

# 创建IPA文件
IPA_NAME="${OUTPUT_NAME}-${BUILD_TYPE}.ipa"
echo "🔄 正在创建IPA文件: $IPA_NAME"

# 使用zip创建IPA文件
zip -r "$IPA_NAME" Payload/

# 检查文件是否创建成功
if [ ! -f "$IPA_NAME" ]; then
    echo "❌ 错误: IPA文件创建失败"
    exit 1
fi

# 显示文件信息
echo "✅ IPA文件创建成功!"
ls -la "$IPA_NAME"
file "$IPA_NAME"

# 移动到项目根目录
mv "$IPA_NAME" ../../../

# 返回根目录
cd ../../../

echo "📱 最终IPA文件:"
ls -la "$IPA_NAME"

echo "🎉 IPA打包完成: $IPA_NAME"
