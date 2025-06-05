import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:ovofun/models/user_model.dart';
import 'package:ovofun/page/models/color_models.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ovofun/page/home_page.dart';
import 'package:ovofun/page/profile_page.dart';
import 'package:extended_image/extended_image.dart';
import 'package:path_provider/path_provider.dart';
import 'avatar_crop_page.dart';

class UserPage extends StatefulWidget {
  final GlobalKey<ProfilePageState>? profilePageKey;
  final GlobalKey<HomePageState>? homePageKey;
  UserPage({this.profilePageKey, this.homePageKey, Key? key}) : super(key: key);
  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    // 跳转到自定义裁剪页面
    final croppedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvatarCropPage(
          imagePath: picked.path,
          themeColor: kPrimaryColor,
        ),
      ),
    );
    if (croppedData == null) return;
    // 保存临时文件
    final tempDir = await getTemporaryDirectory();
    final file = await File('${tempDir.path}/avatar_cropped.jpg').writeAsBytes(croppedData);
    final ok = await UserStore.uploadAvatar(file.path);
    if (ok) {
      await context.read<UserStore>().loadUser(); // 强制刷新本地user
      setState(() {});
      // 调用ProfilePage的刷新方法
      if (widget.profilePageKey?.currentState != null) {
        await widget.profilePageKey!.currentState!.refreshAvatarAndNickname();
      }
      // 调用HomePage的刷新方法
      if (widget.homePageKey?.currentState != null) {
        widget.homePageKey!.currentState!.refreshAvatar();
      }
    }
  }

  void _showEditDialog({required String title, required String field, required String initialValue}) {
    final controller = TextEditingController(text: initialValue);
    bool isValid(String value) {
      if (field == 'nickname') {
        // 只允许中英文、数字
        return RegExp(r'^[\u4e00-\u9fa5a-zA-Z0-9]{1,20}$').hasMatch(value) && value.isNotEmpty;
      } else if (field == 'qq') {
        // 只允许数字
        return RegExp(r'^[0-9]{5,15}$').hasMatch(value) && value.isNotEmpty;
      }
      return false;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            controller.removeListener(() {});
            controller.addListener(() => setModalState(() {}));
            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: field == 'qq' ? TextInputType.number : TextInputType.text,
                    inputFormatters: [
                      field == 'nickname'
                          ? FilteringTextInputFormatter.allow(RegExp(r'[\u4e00-\u9fa5a-zA-Z0-9]'))
                          : FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      hintText: initialValue,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: kPrimaryColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: kPrimaryColor, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    cursorColor: kPrimaryColor,
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isValid(controller.text) ? kPrimaryColor : Colors.grey,
                        foregroundColor: Colors.white,
                        textStyle: TextStyle(color: Colors.white),
                      ),
                      onPressed: isValid(controller.text)
                          ? () async {
                              bool ok = false;
                              if (field == 'nickname') {
                                ok = await UserStore.updateProfile(nickname: controller.text.trim());
                              } else if (field == 'qq') {
                                ok = await UserStore.updateProfile(qq: controller.text.trim());
                              }
                              if (ok) {
                                await context.read<UserStore>().loadUser(); // 强制刷新本地user
                                // 打印最新用户名
                                final newUser = context.read<UserStore>().user;
                                print('修改后用户名: ${newUser?.nickname}');
                                print('修改后QQ: ${newUser?.qq}');
                                print('修改后用户ID: ${newUser?.userId}');
                                print('修改后头像: ${newUser?.avatar}');
                                print('修改后xp: ${newUser?.xp}');
                                // 调用ProfilePage的刷新方法
                                if (widget.profilePageKey?.currentState != null) {
                                  await widget.profilePageKey!.currentState!.refreshAvatarAndNickname();
                                }
                                // 调用HomePage的刷新方法
                                if (widget.homePageKey?.currentState != null) {
                                  widget.homePageKey!.currentState!.refreshAvatar();
                                }
                                Navigator.pop(context, true);
                                setState(() {});
                              }
                            }
                          : null,
                      child: Text('提交', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<UserStore>().user;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              child: Row(
                children: [
                  SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('信息', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(width: 44), // 占位
                ],
              ),
            ),
            SizedBox(height: 18),
            // 头像
            Center(
              child: GestureDetector(
                onTap: _pickAndUploadAvatar,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: u != null && u.avatar != null && u.avatar!.isNotEmpty
                        ? Image.network(u.avatar!, fit: BoxFit.cover)
                        : (u != null && (u.avatar == null || u.avatar!.isEmpty) && u.qq != null && u.qq!.isNotEmpty)
                            ? Image.network('https://q1.qlogo.cn/g?b=qq&nk=${u.qq}&s=100', fit: BoxFit.cover)
                            : Image.asset('assets/image/touxiang.jpg', fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            SizedBox(height: 18),
            // 信息列表
            Divider(height: 1, color: Colors.grey.shade200),
            _buildInfoRow('用户昵称', u?.nickname ?? '', Icons.chevron_right, onTap: () {
              _showEditDialog(title: '修改昵称', field: 'nickname', initialValue: u?.nickname ?? '');
            }),
            Divider(height: 1, color: Colors.grey.shade200),
            _buildInfoRow('QQ', u?.qq ?? '', Icons.chevron_right, onTap: () {
              _showEditDialog(title: '修改QQ', field: 'qq', initialValue: u?.qq ?? '');
            }),
            Divider(height: 1, color: Colors.grey.shade200),
            _buildInfoRow('用户ID', u?.userId ?? '', null),
            Divider(height: 1, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData? icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: Colors.black87)),
            Spacer(),
            Text(value, style: TextStyle(fontSize: 15, color: Colors.black87)),
            if (icon != null) ...[
              SizedBox(width: 8),
              Icon(icon, color: Colors.grey, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
