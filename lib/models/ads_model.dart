import 'package:flutter/material.dart';
import 'package:flutter_unionad/flutter_unionad.dart';
import 'package:flutter_unionad/bannerad/BannerAdView.dart';
import 'package:flutter_unionad/drawfeedad/DrawFeedAdView.dart';
import 'package:flutter_unionad/nativead/NativeAdView.dart';

class AdsManager {
  // 单例实现
  static final AdsManager instance = AdsManager._internal();
  factory AdsManager() => instance;
  AdsManager._internal();

  // 广告开关
  bool enableBanner = true;
  bool enableDrawFeed = true;
  bool enableNative = true;
  bool enableSplash = true;

  /// Banner 广告 Widget
  Widget bannerAdWidget() {
    if (!enableBanner) return SizedBox.shrink();
    return Column(
      children: [
        FlutterUnionadBannerView(
          androidCodeId: "102735527",
          iosCodeId: "102735527",
          width: 600.5,
          height: 120.5,
          callBack: FlutterUnionadBannerCallBack(
            onShow: () => print("banner广告加载完成"),
            onDislike: (message) => print("banner不感兴趣 $message"),
            onFail: (error) => print("banner广告加载失败 $error"),
            onClick: () => print("banner广告点击"),
            onEcpm: (info) => print("banner广告ecpm:$info"),
          ),
        ),
        FlutterUnionad.bannerAdView(
          androidCodeId: "102735527",
          iosCodeId: "102735527",
          expressViewWidth: 600,
          expressViewHeight: 200,
          callBack: FlutterUnionadBannerCallBack(
            onShow: () => print("banner广告加载完成"),
            onDislike: (message) => print("banner不感兴趣 $message"),
            onFail: (error) => print("banner广告加载失败 $error"),
            onClick: () => print("banner广告点击"),
          ),
        ),
      ],
    );
  }

  /// DrawFeed 广告 Widget
  Widget drawFeedAdWidget(BuildContext context) {
    if (!enableDrawFeed) return SizedBox.shrink();
    return Column(
      children: [
        FlutterUnionadDrawFeedAdView(
          androidCodeId: "102734241",
          iosCodeId: "102734241",
          width: MediaQuery.of(context).size.width,
          height: 800.5,
          isMuted: false,
          callBack: FlutterUnionadDrawFeedCallBack(
            onShow: () => print("draw广告显示"),
            onFail: (error) => print("draw广告加载失败 $error"),
            onClick: () => print("draw广告点击"),
            onDislike: (message) => print("draw点击不喜欢 $message"),
            onVideoPlay: () => print("draw视频播放"),
            onVideoPause: () => print("draw视频暂停"),
            onVideoStop: () => print("draw视频结束"),
            onEcpm: (info) => print("draw视频ecpm $info"),
          ),
        ),
        FlutterUnionad.drawFeedAdView(
          androidCodeId: "102734241",
          iosCodeId: "102734241",
          supportDeepLink: true,
          expressViewWidth: 600.5,
          expressViewHeight: 800.5,
          downloadType: FlutterUnionadDownLoadType.DOWNLOAD_TYPE_POPUP,
          adLoadType: FlutterUnionadLoadType.LOAD,
          callBack: FlutterUnionadDrawFeedCallBack(
            onShow: () => print("draw广告显示"),
            onFail: (error) => print("draw广告加载失败 $error"),
            onClick: () => print("draw广告点击"),
            onDislike: (message) => print("draw点击不喜欢 $message"),
            onVideoPlay: () => print("draw视频播放"),
            onVideoPause: () => print("draw视频暂停"),
            onVideoStop: () => print("draw视频结束"),
          ),
        ),
      ],
    );
  }

  /// Native 信息流广告 Widget
  Widget nativeAdWidget() {
    if (!enableNative) return SizedBox.shrink();
    return Column(
      children: [
        FlutterUnionadNativeAdView(
          androidCodeId: "102730271",
          iosCodeId: "102730271",
          supportDeepLink: true,
          width: 375.5,
          height: 100,
          isMuted: false,
          callBack: FlutterUnionadNativeCallBack(
            onShow: () => print("信息流广告显示"),
            onFail: (error) => print("信息流广告失败 $error"),
            onDislike: (message) => print("信息流广告不感兴趣 $message"),
            onClick: () => print("信息流广告点击"),
            onEcpm: (info) => print("信息流广告ecpm $info"),
          ),
        ),
        FlutterUnionad.nativeAdView(
          androidCodeId: "102730271",
          iosCodeId: "102730271",
          expressViewWidth: 300,
          expressViewHeight: 200,
          callBack: FlutterUnionadNativeCallBack(
            onShow: () => print("信息流广告显示"),
            onFail: (error) => print("信息流广告失败 $error"),
            onDislike: (message) => print("信息流广告不感兴趣 $message"),
            onClick: () => print("信息流广告点击"),
          ),
        ),
      ],
    );
  }

  /// Splash 开屏广告 Widget
  Widget splashAdWidget(BuildContext context) {
    if (!enableSplash) return SizedBox.shrink();
    return FlutterUnionadSplashAdView(
      androidCodeId: "102729400",
      iosCodeId: "102729400",
      supportDeepLink: true,
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height - 100,
      hideSkip: false,
      timeout: 3000,
      isShake: true,
      callBack: FlutterUnionadSplashCallBack(
        onShow: () => print("开屏广告显示"),
        onClick: () => print("开屏广告点击"),
        onFail: (error) {
          print("开屏广告失败 $error");
          // 这里可以自定义关闭逻辑
        },
        onFinish: () => print("开屏广告倒计时结束"),
        onSkip: () => print("开屏广告跳过"),
        onTimeOut: () => print("开屏广告超时"),
        onEcpm: (info) => print("开屏广告获取ecpm:$info"),
      ),
    );
  }
}
