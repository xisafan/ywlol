# 🍎 iOS远程构建指南

本项目已配置GitHub Actions来自动构建iOS版本，无需本地Mac环境即可构建iOS应用。

## 🚀 快速开始

### 方法1: 手动触发构建

1. 打开GitHub仓库页面：https://github.com/shiyun0001/qwqfun
2. 点击 `Actions` 标签页
3. 选择 `🍎 Build iOS App` 或 `🚀 Simple iOS Build` workflow
4. 点击 `Run workflow` 按钮
5. 选择构建类型（debug/release）
6. 点击绿色的 `Run workflow` 按钮

### 方法2: 推送代码自动构建

- 每次推送到 `main` 分支时会自动触发构建
- 创建Pull Request时也会触发构建

## 📦 下载构建产物

1. 构建完成后，在Actions页面找到对应的构建任务
2. 点击进入构建详情页面
3. 在 `Artifacts` 部分下载IPA文件
4. 下载的文件名格式：`ovofun-ios-debug.ipa` 或 `ovofun-ios-release.ipa`

## 📱 安装到iOS设备

### 选项1: 使用AltStore (推荐)

1. 在iPhone上安装AltStore: https://altstore.io/
2. 将IPA文件传输到手机
3. 使用AltStore安装IPA文件
4. 信任开发者证书

### 选项2: 使用Xcode

1. 将IPA文件解压得到.app文件
2. 使用Xcode的Devices窗口安装到设备
3. 信任开发者证书

### 选项3: 使用第三方工具

- TrollStore (需要越狱)
- Sideloadly
- 3uTools

## 🔧 构建配置

### 应用信息
- **应用名称**: Ovofun
- **Bundle ID**: com.qwqfun.ovofun
- **最低iOS版本**: 13.0
- **支持架构**: arm64

### 构建类型

1. **Debug构建**
   - 包含调试信息
   - 文件较大
   - 性能较慢
   - 适合开发测试

2. **Release构建**
   - 优化性能
   - 文件较小
   - 移除调试信息
   - 适合发布使用

## 🛠️ 技术细节

### 构建环境
- **macOS版本**: macOS-14 (latest)
- **Xcode版本**: 最新稳定版
- **Flutter版本**: 自动使用最新稳定版 (支持Dart SDK 3.7.0+)
- **CocoaPods**: 最新版本

### 🔧 IPA打包改进
- ✅ **专用打包脚本**: 使用 `.github/scripts/create_ipa.sh` 确保正确生成IPA文件
- ✅ **详细日志**: 完整的构建和打包过程日志，便于调试
- ✅ **文件验证**: 自动检查Runner.app和IPA文件的完整性
- ✅ **标准格式**: 生成标准iOS IPA格式，而非文件夹

### 主要依赖
- media_kit (视频播放)
- dio (网络请求)
- cached_network_image (图片缓存)
- flutter_downloader (下载功能)
- 更多依赖请查看 pubspec.yaml

## ⚠️ 注意事项

1. **签名问题**
   - 构建的IPA未签名，需要自行签名或使用第三方工具
   - 企业证书用户可以直接安装

2. **设备信任**
   - 首次安装需要在设置中信任开发者
   - 路径：设置 → 通用 → VPN与设备管理 → 开发者App

3. **兼容性**
   - 支持iOS 13.0及以上版本
   - 支持iPhone和iPad
   - 支持横屏和竖屏

## 🐛 常见问题

### Q: 构建失败怎么办？
A: 查看Actions日志，常见原因：
- 依赖版本冲突
- iOS配置问题
- Podfile.lock冲突

### Q: IPA无法安装？
A: 检查：
- iOS版本是否兼容
- 是否已信任开发者
- 安装工具是否正确配置

### Q: 应用闪退？
A: 可能原因：
- 设备架构不兼容
- 缺少必要权限
- 依赖库问题

## 📞 支持

如有问题请：
1. 查看Actions构建日志
2. 创建GitHub Issue
3. 检查Flutter和iOS相关文档

---

**构建愉快！** 🎉
