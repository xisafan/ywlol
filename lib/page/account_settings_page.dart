import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../services/api/ssl_Management.dart';
import '../theme/app_theme.dart';
import 'package:ovofun/page/models/color_models.dart';
import 'login_page.dart';
import 'points_exchange_page.dart';
import 'sponsor_page.dart';
import 'package:dio/dio.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({Key? key}) : super(key: key);

  @override
  _AccountSettingsPageState createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _nicknameController = TextEditingController();
  final _qqController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  File? _selectedImage;
  bool _isEmailVerified = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final user = context.read<UserStore>().user;
    if (user != null) {
      _nicknameController.text = user.nickname;
      _qqController.text = user.qq ?? '';
      _emailController.text = user.email ?? '';
      _isEmailVerified = user.email != null && user.email!.isNotEmpty;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _qqController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white, // 白色背景
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部指示器
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '选择头像',
                style: const TextStyle(
                  fontSize: 16, // 缩小标题字体
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: '从相册选择',
                    onTap: () => _selectImage(ImageSource.gallery),
                  ),
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: '拍照',
                    onTap: () => _selectImage(ImageSource.camera),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(icon, size: 28, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectImage(ImageSource source) async {
    Navigator.pop(context); // 关闭底部选择对话框

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (image != null) {
        // 裁剪图片
        final CroppedFile? croppedFile = await _cropImage(image.path);
        if (croppedFile != null) {
          setState(() {
            _selectedImage = File(croppedFile.path);
          });
          // 显示裁剪预览和上传确认
          _showCropPreview();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
    }
  }

  Future<CroppedFile?> _cropImage(String imagePath) async {
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // 强制正方形
        maxWidth: 512,
        maxHeight: 512,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪头像',
            toolbarColor: AppTheme.primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true, // 锁定为正方形
            hideBottomControls: false,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: '裁剪头像',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );
      return croppedFile;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片裁剪失败: $e')));
      return null;
    }
  }

  void _showCropPreview() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // 白色背景
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // 矩形弹窗
          ),
          title: Text(
            '头像预览',
            style: const TextStyle(
              fontSize: 16, // 缩小标题字体
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child:
                      _selectedImage != null
                          ? Image.file(_selectedImage!, fit: BoxFit.cover)
                          : Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '确认使用这张头像吗？',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          actions: [
            Container(
              height: 36,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null; // 取消选择
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  backgroundColor: Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('重新选择', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 36,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _uploadAvatar(); // 确认上传
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('确认上传', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadAvatar() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 创建FormData用于文件上传
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          _selectedImage!.path,
          filename: 'avatar.${_selectedImage!.path.split('.').last}',
        ),
      });

      final response = await OvoApiManager().dio.post(
        '/v1/user/upload_avatar',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      if (response.data['code'] == 0 || response.data['code'] == 200) {
        // 更新本地用户数据
        final userStore = context.read<UserStore>();
        final currentUser = userStore.user;
        if (currentUser != null && response.data['data'] != null) {
          final userData = response.data['data'];
          final updatedUser = User(
            userId: currentUser.userId,
            username: currentUser.username,
            nickname: currentUser.nickname,
            qq: currentUser.qq,
            email: currentUser.email,
            avatar: userData['user_portrait'] ?? currentUser.avatar,
            token: currentUser.token,
            refreshToken: currentUser.refreshToken,
            expireTime: currentUser.expireTime,
            isVip: currentUser.isVip,
            xp: currentUser.xp,
            userEndTime: currentUser.userEndTime,
          );
          await userStore.setUser(updatedUser);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('头像上传成功'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _selectedImage = null; // 清除临时选择的图片
        });

        // 重新初始化数据显示最新头像
        _initializeData();
      } else {
        throw Exception(response.data['msg'] ?? '上传失败');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('头像上传失败: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    Navigator.pushNamed(context, '/reset_password');
  }

  Future<void> _cacheQQAvatar() async {
    final user = context.read<UserStore>().user;
    if (user?.qq == null || user!.qq!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先设置QQ号')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await OvoApiManager().post('/v1/user/cache_qq_avatar');

      if (response['code'] == 0 || response['code'] == 200) {
        // 更新本地用户数据
        final userStore = context.read<UserStore>();
        final currentUser = userStore.user;
        if (currentUser != null && response['data'] != null) {
          final userData = response['data']['user'];
          final updatedUser = User(
            userId: currentUser.userId,
            username: currentUser.username,
            nickname: currentUser.nickname,
            qq: currentUser.qq,
            email: currentUser.email,
            avatar: userData['user_portrait'] ?? currentUser.avatar,
            token: currentUser.token,
            refreshToken: currentUser.refreshToken,
            expireTime: currentUser.expireTime,
            isVip: currentUser.isVip,
            xp: currentUser.xp,
            userEndTime: currentUser.userEndTime,
          );
          await userStore.setUser(updatedUser);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['data']['message'] ?? 'QQ头像缓存成功'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _initializeData(); // 重新初始化数据
        });
      } else {
        throw Exception(response['msg'] ?? '缓存失败');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('QQ头像缓存失败: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // 白色背景
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // 矩形弹窗
          ),
          title: const Text(
            '确认退出',
            style: TextStyle(
              fontSize: 16, // 缩小标题字体
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: const Text(
            '确定要退出登录吗？',
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          actions: [
            Container(
              height: 36,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  backgroundColor: Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('取消', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 36,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  // 清除用户数据
                  final userStore = context.read<UserStore>();
                  await userStore.logout();

                  // 返回登录页面
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('确定', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _editNickname() {
    _showEditDialog(
      title: '修改昵称',
      controller: _nicknameController,
      hintText: '请输入昵称',
      onSave: (value) async {
        if (value.trim().isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('昵称不能为空')));
          return;
        }
        await _updateSingleField('nickname', value);
      },
    );
  }

  void _editQQ() {
    _showEditDialog(
      title: '修改QQ',
      controller: _qqController,
      hintText: '请输入QQ号码',
      keyboardType: TextInputType.number,
      onSave: (value) async {
        await _updateSingleField('user_qq', value);
      },
    );
  }

  void _editEmail() {
    _showEditDialog(
      title: '修改邮箱',
      controller: _emailController,
      hintText: '请输入邮箱地址',
      keyboardType: TextInputType.emailAddress,
      onSave: (value) async {
        if (value.trim().isNotEmpty &&
            !RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(value)) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('邮箱格式不正确')));
          return;
        }
        await _updateSingleField('email', value);
      },
    );
  }

  Future<void> _updateSingleField(String field, String value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await OvoApiManager().post(
        '/v1/user/update_profile',
        data: {field: value.trim()},
      );

      // 更新本地用户数据
      final userStore = context.read<UserStore>();
      final currentUser = userStore.user;
      if (currentUser != null) {
        User updatedUser;
        switch (field) {
          case 'nickname':
            updatedUser = User(
              userId: currentUser.userId,
              username: currentUser.username,
              nickname: value.trim(),
              qq: currentUser.qq,
              email: currentUser.email,
              avatar: currentUser.avatar,
              token: currentUser.token,
              refreshToken: currentUser.refreshToken,
              expireTime: currentUser.expireTime,
              isVip: currentUser.isVip,
              xp: currentUser.xp,
              userEndTime: currentUser.userEndTime,
            );
            break;
          case 'user_qq':
            updatedUser = User(
              userId: currentUser.userId,
              username: currentUser.username,
              nickname: currentUser.nickname,
              qq: value.trim().isNotEmpty ? value.trim() : null,
              email: currentUser.email,
              avatar: currentUser.avatar,
              token: currentUser.token,
              refreshToken: currentUser.refreshToken,
              expireTime: currentUser.expireTime,
              isVip: currentUser.isVip,
              xp: currentUser.xp,
              userEndTime: currentUser.userEndTime,
            );
            break;
          case 'email':
            updatedUser = User(
              userId: currentUser.userId,
              username: currentUser.username,
              nickname: currentUser.nickname,
              qq: currentUser.qq,
              email: value.trim().isNotEmpty ? value.trim() : null,
              avatar: currentUser.avatar,
              token: currentUser.token,
              refreshToken: currentUser.refreshToken,
              expireTime: currentUser.expireTime,
              isVip: currentUser.isVip,
              xp: currentUser.xp,
              userEndTime: currentUser.userEndTime,
            );
            break;
          default:
            updatedUser = currentUser;
        }
        await userStore.setUser(updatedUser);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('修改成功'), backgroundColor: Colors.green),
      );

      setState(() {
        _initializeData();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('修改失败: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showEditDialog({
    required String title,
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    required Function(String) onSave,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // 白色背景
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // 矩形弹窗，稍微圆角
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16, // 缩小标题字体
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              autofocus: true,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          actions: [
            Container(
              height: 36,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  backgroundColor: Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('取消', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 36,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onSave(controller.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('保存', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserStore>().user;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 30,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.arrow_back, color: Colors.white, size: 12),
            ),
          ),
        ),
        title: const Text(
          '个人中心',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // 头像行
                  _buildAvatarInfoRow(),
                  const SizedBox(height: 12),
                  // 邮箱行
                  _buildInfoRow(
                    title: '邮箱',
                    content: Text(
                      user?.email ?? '未设置',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            user?.email != null
                                ? Colors.black87
                                : Colors.grey[400],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _isEmailVerified
                                ? Colors.green[100]
                                : Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isEmailVerified ? '已激活' : '未激活',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _isEmailVerified
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                        ),
                      ),
                    ),
                    onTap: _editEmail,
                  ),
                  // 昵称行
                  _buildInfoRow(
                    title: '昵称',
                    content: Text(
                      user?.nickname ?? '未设置',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            user?.nickname != null
                                ? Colors.black87
                                : Colors.grey[400],
                      ),
                    ),
                    onTap: _editNickname,
                  ),
                  // QQ行
                  _buildInfoRow(
                    title: 'QQ',
                    content: Text(
                      user?.qq ?? '未设置',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            user?.qq != null
                                ? Colors.black87
                                : Colors.grey[400],
                      ),
                    ),
                    onTap: _editQQ,
                  ),
                  // 🔧 账号名行（不支持修改）
                  _buildInfoRow(
                    title: '账号名',
                    content: Text(
                      user?.username ?? '未设置',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    trailing: Text(
                      '不支持修改',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                    onTap: () {}, // 不允许点击
                  ),
                  // 会员等级行
                  _buildInfoRow(
                    title: '等级',
                    content: Text(
                      user?.groupName ?? '游客',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    onTap: () {}, // 不允许点击
                  ),
                  // 积分行
                  _buildInfoRow(
                    title: '积分',
                    content: Text(
                      '${user?.xp ?? 0}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    trailing: Text(
                      '查看详情',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    onTap: () {
                      // 跳转到赞助页面
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SponsorPage(),
                        ),
                      );
                    },
                  ),
                  // VIP时长行（仅VIP显示）
                  if (user?.isVip == true && user?.userEndTime != null)
                    _buildInfoRow(
                      title: 'VIP到期',
                      content: Text(
                        _formatExpiryDate(user!.userEndTime!),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      trailing: Text(
                        '到期时间',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      onTap: () {
                        // 可以添加查看VIP详情的逻辑
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('VIP详情功能开发中')),
                        );
                      },
                    ),
                  // 密码行
                  _buildInfoRow(
                    title: '密码',
                    content: const Text(
                      '••••••••',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        letterSpacing: 2,
                      ),
                    ),
                    trailing: Text(
                      '修改密码',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    onTap: _changePassword,
                  ),
                  // QQ头像缓存行
                  if (user?.qq != null && user!.qq!.isNotEmpty)
                    _buildInfoRow(
                      title: 'QQ头像',
                      content: const Text(
                        '缓存到本地',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      trailing: Text(
                        '刷新缓存',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      onTap: _cacheQQAvatar,
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // 退出登录按钮
          Container(
            margin: const EdgeInsets.all(20),
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: const Text(
                '退出登录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String title,
    required Widget content,
    Widget? trailing,
    required VoidCallback onTap,
    bool showArrow = true,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: content),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
              if (showArrow) ...[
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.chevron_right,
                    color: Colors.grey[600],
                    size: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarWidget() {
    final user = context.watch<UserStore>().user;
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child:
            _selectedImage != null
                ? Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                  width: 28,
                  height: 28,
                )
                : (() {
                  if (user != null &&
                      user.avatar != null &&
                      user.avatar!.isNotEmpty) {
                    // 显示用户头像（包括缓存的QQ头像）
                    String avatarUrl = user.avatar!;
                    // 如果是相对路径，转换为完整URL
                    if (avatarUrl.startsWith('/uploads/')) {
                      String baseUrl = OvoApiManager().baseUrl;
                      if (baseUrl.endsWith('/api.php')) {
                        baseUrl = baseUrl.substring(
                          0,
                          baseUrl.length - '/api.php'.length,
                        );
                      }
                      avatarUrl = baseUrl + avatarUrl;
                    }

                    return Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/image/touxiang.jpg',
                          fit: BoxFit.cover,
                        );
                      },
                    );
                  } else {
                    // 如果没有头像，显示默认头像
                    return Image.asset(
                      'assets/image/touxiang.jpg',
                      fit: BoxFit.cover,
                    );
                  }
                })(),
      ),
    );
  }

  Widget _buildAvatarInfoRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
      ),
      child: InkWell(
        onTap: _pickImage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  '头像',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Container()), // 空白区域用于推送头像到右侧
              _buildAvatarWidget(),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// 格式化VIP到期日期
  String _formatExpiryDate(String? userEndTime) {
    if (userEndTime == null || userEndTime.isEmpty) {
      return '已过期';
    }

    try {
      // 将字符串时间戳转换为整数
      final endTimeStamp = int.parse(userEndTime);
      final endTime = DateTime.fromMillisecondsSinceEpoch(endTimeStamp * 1000);
      final now = DateTime.now();
      
      // 检查是否已过期
      if (endTime.isBefore(now)) {
        return '已过期';
      }
      
      // 格式化到期日期
      return '${endTime.year}年${endTime.month.toString().padLeft(2, '0')}月${endTime.day.toString().padLeft(2, '0')}日';
    } catch (e) {
      print('[AccountSettings] 解析VIP到期时间失败: $e');
      return '未知';
    }
  }
}
