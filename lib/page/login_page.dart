import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'register_page.dart';
import 'reset_password_page.dart';
import '../models/user_model.dart';
import '../services/api/ssl_Management.dart';
import 'package:ovofun/page/models/color_models.dart';

class LoginPage extends StatefulWidget {
  final Function(dynamic)? onLoginSuccess;

  const LoginPage({Key? key, this.onLoginSuccess}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}
// 123
enum LoginStatus { normal, success, fail }

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _canLogin = false;
  LoginStatus _loginStatus = LoginStatus.normal;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_updateCanLogin);
    _passwordController.addListener(_updateCanLogin);
  }

  void _updateCanLogin() {
    setState(() {
      _canLogin = _usernameController.text.trim().isNotEmpty &&
          _passwordController.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _usernameController.removeListener(_updateCanLogin);
    _passwordController.removeListener(_updateCanLogin);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _resetLoginStatus() {
    if (mounted) {
      setState(() {
        _loginStatus = LoginStatus.normal;
      });
    }
  }

  void _login() async {
    setState(() {
      _isLoading = true;
      _loginStatus = LoginStatus.normal;
    });

    try {
      final userData = await OvoApiManager().post('/v1/user/login', data: {
        'username': _usernameController.text.trim(),
        'password': _passwordController.text.trim(),
      });
      if (userData == null) throw Exception('未获取到用户信息');

      // 字段映射
      final userMap = {
        'userId': userData['user_id']?.toString() ?? '',
        'username': userData['username']?.toString() ?? '',
        'nickname': userData['nickname'] ?? '',
        'avatar': userData['avatar'],
        'qq': userData['user_qq'],
        'token': userData['token'],
        'refreshToken': userData['refresh_token'],
      };

      await UserStore().saveUser(User.fromJson(userMap));
      if (userMap['token'] != null) {
        OvoApiManager().setToken(userMap['token']);
      }

      setState(() {
        _loginStatus = LoginStatus.success;
      });

      if (widget.onLoginSuccess != null) {
        print('调用onLoginSuccess回调');
        widget.onLoginSuccess!(userMap);
      }

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        print('Navigator.of(context).pop(true)');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _loginStatus = LoginStatus.fail;
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      _resetLoginStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // 返回按钮
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // 标题
                const Text(
                  '登录',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                // 副标题
                const Text(
                  '登录后即可享受更多权益~',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),
                // 用户名输入框
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '用户名',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 密码输入框
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '密码',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // 登录按钮
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_canLogin || _loginStatus == LoginStatus.success) ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _loginStatus == LoginStatus.success
                          ? Colors.green
                          : _loginStatus == LoginStatus.fail
                              ? Colors.red
                              : _canLogin
                                  ? kPrimaryColor
                                  : kSecondaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _loginStatus == LoginStatus.success
                                ? '登录成功'
                                : _loginStatus == LoginStatus.fail
                                    ? '登录失败'
                                    : '登录',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                // 底部链接
                Center(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '立即注册',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterPage(),
                                ),
                              );
                            },
                        ),
                        const TextSpan(
                          text: '  |  ',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text: '找回密码',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ResetPasswordPage(),
                                ),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
