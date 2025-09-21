#!/bin/bash

# iOS配置修复脚本
echo "🔧 开始修复iOS配置问题..."

# 检查Flutter环境
echo "=== Flutter环境检查 ==="
flutter --version
flutter doctor --android-licenses || echo "Android licenses检查完成"

# 重新生成配置
echo "=== 重新生成Flutter配置 ==="
flutter clean
flutter pub get
flutter precache --ios

# 检查iOS目录
echo "=== 检查iOS目录结构 ==="
if [ ! -d "ios" ]; then
    echo "❌ ios目录不存在"
    exit 1
fi

if [ ! -d "ios/Flutter" ]; then
    echo "📁 创建Flutter目录"
    mkdir -p ios/Flutter
fi

# 生成必要的配置文件
echo "=== 生成iOS配置文件 ==="
flutter build ios --config-only || echo "配置生成可能失败，继续尝试其他方法..."

# 检查关键文件
GENERATED_CONFIG="ios/Flutter/Generated.xcconfig"
if [ ! -f "$GENERATED_CONFIG" ]; then
    echo "⚠️ Generated.xcconfig不存在，手动创建基础配置..."
    
    # 创建基础配置文件
    cat > "$GENERATED_CONFIG" << EOF
// This is a generated file; do not edit or check into version control.
FLUTTER_ROOT=$(flutter --version --machine | jq -r '.flutterRoot' | tr -d '"')
FLUTTER_APPLICATION_PATH=$PWD
COCOAPODS_PARALLEL_CODE_SIGN=true
FLUTTER_BUILD_DIR=build
FLUTTER_BUILD_NAME=1.0.0
FLUTTER_BUILD_NUMBER=1
EXCLUDED_ARCHS[sdk=iphonesimulator*]=i386
DART_DEFINES=
DART_OBFUSCATION=false
TRACK_WIDGET_CREATION=true
TREE_SHAKE_ICONS=false
PACKAGE_CONFIG=.dart_tool/package_config.json
EOF
    echo "✅ 基础配置文件已创建"
fi

# 检查其他必要文件
echo "=== 检查其他配置文件 ==="
ls -la ios/Flutter/

# 验证Podfile
echo "=== 验证Podfile ==="
if [ -f "ios/Podfile" ]; then
    echo "✅ Podfile存在"
    cat ios/Podfile | head -20
else
    echo "❌ Podfile不存在"
    exit 1
fi

echo "🎉 iOS配置修复完成"
