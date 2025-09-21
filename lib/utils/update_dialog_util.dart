import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class UpdateDialogUtil {
  static Future<void> showUpdateDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String updateUrl,
    required String updateMethod,
    bool barrierDismissible = true,
    bool showCancelButton = true,
    VoidCallback? onCancel,
    bool forceUpdate = false,
    String? currentVersion,
    String? newVersion,
    String? packageSize,
    String? updateTime,
    String? browserUrl,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => _UpdateDialog(
        title: title,
        content: content,
        updateUrl: updateUrl,
        updateMethod: updateMethod,
        barrierDismissible: barrierDismissible,
        showCancelButton: showCancelButton,
        onCancel: onCancel,
        forceUpdate: forceUpdate,
        currentVersion: currentVersion,
        newVersion: newVersion,
        packageSize: packageSize,
        updateTime: updateTime,
        browserUrl: browserUrl,
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final String title;
  final String content;
  final String updateUrl;
  final String updateMethod;
  final bool barrierDismissible;
  final bool showCancelButton;
  final VoidCallback? onCancel;
  final bool forceUpdate;
  final String? currentVersion;
  final String? newVersion;
  final String? packageSize;
  final String? updateTime;
  final String? browserUrl;

  const _UpdateDialog({
    required this.title,
    required this.content,
    required this.updateUrl,
    required this.updateMethod,
    this.barrierDismissible = true,
    this.showCancelButton = true,
    this.onCancel,
    this.forceUpdate = false,
    this.currentVersion,
    this.newVersion,
    this.packageSize,
    this.updateTime,
    this.browserUrl,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool isDownloading = false;
  double downloadProgress = 0.0;
  bool downloadComplete = false;
  String downloadedPath = '';

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) => WillPopScope(
        onWillPop: () async => widget.barrierDismissible,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            clipBehavior: Clip.none,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 头部区域 - 参考热门新番样式
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 版本更新标题 - 参考热门新番样式，左对齐
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Stack(
                          children: <Widget>[
                            Positioned(
                              left: 0.0,
                              top: 0.0,
                              bottom: 1.4,
                              width: 28.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryColor.withOpacity(0.58),
                                      AppTheme.primaryColor.withOpacity(0.0),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                4.0,
                                0.6,
                                0.0,
                                0.0,
                              ),
                              child: Text(
                                '版本更新',
                                style: const TextStyle(
                                  fontFamily: 'FZLanTingHeiS-EB-GB',
                                  fontSize: 18,
                                  color: Color(0xff000000),
                                  fontWeight: FontWeight.bold,
                                ),
                                softWrap: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 关闭按钮 - 只有在非强制更新时显示
                      if (widget.barrierDismissible)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              if (widget.onCancel != null) widget.onCancel!();
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 内容区域
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 更新标题
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      // 版本信息
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (widget.currentVersion != null && widget.newVersion != null) ...[
                              _buildInfoRow('当前版本', widget.currentVersion!),
                              SizedBox(height: 8),
                              _buildInfoRow('最新版本', widget.newVersion!),
                              SizedBox(height: 8),
                            ],
                            if (widget.packageSize != null && widget.packageSize!.isNotEmpty) ...[
                              _buildInfoRow('安装包大小', widget.packageSize!),
                              SizedBox(height: 8),
                            ],
                            if (widget.updateTime != null && widget.updateTime!.isNotEmpty)
                              _buildInfoRow('更新时间', widget.updateTime!),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // 更新内容
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.content,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      // 按钮区域
                      Row(
                        children: [
                          // 浏览器打开按钮
                          Expanded(
                            child: Container(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () async {
                                  try {
                                    final uri = Uri.parse(_getBrowserUrl());
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    } else {
                                      throw '无法打开链接';
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('打开链接失败: $e')),
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppTheme.primaryColor,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  foregroundColor: AppTheme.primaryColor,
                                ),
                                child: Text(
                                  '浏览器打开',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: 12),

                          // 立即更新按钮
                          Expanded(
                            child: Container(
                              height: 48,
                              child: Stack(
                                children: [
                                  // 背景容器
                                  Container(
                                    height: 48,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: downloadComplete
                                          ? Colors.green
                                          : (!isDownloading && !downloadComplete)
                                              ? AppTheme.primaryColor
                                              : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),

                                  // 下载进度条
                                  if (isDownloading)
                                    AnimatedContainer(
                                      duration: Duration(milliseconds: 300),
                                      height: 48,
                                      width: (MediaQuery.of(context).size.width * 0.9 - 64) / 2 * downloadProgress,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryLightColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),

                                  // 按钮文本
                                  SizedBox(
                                    height: 48,
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: isDownloading
                                          ? null
                                          : downloadComplete
                                              ? _handleInstall
                                              : () => _handleDownload(setState),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        downloadComplete
                                            ? '立即安装'
                                            : isDownloading
                                                ? '下载中 ${(downloadProgress * 100).toInt()}%'
                                                : '立即更新',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _getBrowserUrl() {
    return widget.browserUrl?.isNotEmpty == true ? widget.browserUrl! : widget.updateUrl;
  }

  Future<void> _handleDownload(StateSetter setState) async {
    if (widget.updateMethod == 'external') {
      // 外部更新，直接打开浏览器
      try {
        final uri = Uri.parse(_getBrowserUrl());
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw '无法打开链接';
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开链接失败: $e')),
        );
      }
      return;
    }

    // 直接下载
    setState(() {
      isDownloading = true;
      downloadProgress = 0;
    });

    try {
      final dio = Dio();
      final dir = await getExternalStorageDirectory();
      final savePath = '${dir!.path}/app-update.apk';
      
      await dio.download(
        widget.updateUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              downloadProgress = received / total;
            });
          }
        },
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Android) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          },
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      
      setState(() {
        isDownloading = false;
        downloadComplete = true;
        downloadedPath = savePath;
      });
    } catch (e) {
      setState(() {
        isDownloading = false;
        downloadProgress = 0;
        downloadComplete = false;
        downloadedPath = '';
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }

  Future<void> _handleInstall() async {
    if (downloadedPath.isEmpty) return;
    
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        final result = await Permission.requestInstallPackages.request();
        if (!result.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('需要安装权限才能安装应用')),
            );
          }
          return;
        }
      }
      
      try {
        final result = await OpenFile.open(downloadedPath);
        if (result.type != ResultType.done) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('安装失败: ${result.message}')),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('安装失败: $e')),
          );
        }
      }
    }
  }
}


