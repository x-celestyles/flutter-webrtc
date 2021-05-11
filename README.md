# Flutter-WebRTC

[![Financial Contributors on Open Collective](https://opencollective.com/flutter-webrtc/all/badge.svg?label=financial+contributors)](https://opencollective.com/flutter-webrtc) [![pub package](https://img.shields.io/pub/v/flutter_webrtc.svg)](https://pub.dartlang.org/packages/flutter_webrtc) [![Gitter](https://badges.gitter.im/flutter-webrtc/Lobby.svg)](https://gitter.im/flutter-webrtc/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

WebRTC plugin for Flutter Mobile/Desktop/Web

</br>
<p align="center">
<strong>Sponsored with 💖 &nbsp by</strong><br />
<a href="https://getstream.io/?utm_source=github.com/flutter-webrtc/flutter-webrtc&utm_medium=github&utm_campaign=oss_sponsorship" target="_blank">
<img src="https://stream-blog-v2.imgix.net/blog/wp-content/uploads/f7401112f41742c4e173c30d4f318cb8/stream_logo_white.png?w=350" alt="Stream Chat" style="margin: 8px" />
</a>
<br />
Enterprise Grade APIs for Feeds & Chat. <a href="https://getstream.io/chat/flutter/tutorial/?utm_source=github.com/flutter-webrtc/flutter-webrtc&utm_medium=github&utm_campaign=oss_sponsorship" target="_blank">Try the Flutter Chat tutorial</a> 💬
</p>

</br>

## Functionality

| Feature | Android | iOS | [Web](https://flutter.dev/web) | macOS | Windows | Linux | [Fuchsia](https://fuchsia.googlesource.com/) |
| :-------------: | :-------------:| :-----: | :-----: | :-----: | :-----: | :-----: | :-----: |
| Audio/Video | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | [WIP] | |
| Data Channel | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | [WIP] | |
| Screen Capture | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | | | | |
| Unified-Plan | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | | | |
| Simulcast | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | | | |
| MediaRecorder| :warning: | :warning: | :heavy_check_mark: | | | | |

## Usage

Add `flutter_webrtc` as a [dependency in your pubspec.yaml file](https://flutter.io/using-packages/).

### iOS

Add the following entry to your _Info.plist_ file, located in `<project root>/ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>$(PRODUCT_NAME) Camera Usage!</string>
<key>NSMicrophoneUsageDescription</key>
<string>$(PRODUCT_NAME) Microphone Usage!</string>
```

This entry allows your app to access camera and microphone.

iOS使用注意事项：
1.在项目的Runner中创建ReplayKit和AppGroup
2.在ReplayKit扩展中创建AppGroup，添加YeasNotificationCenter，YeasSampleUploader和YeasSocketConnection三个文件
3.项目中使用了AppGroup进行跨进程通信，在replayKit和插件中搜索“group.yeas.com”,将其替换成自己创建的AppGroup
4.在插件中搜索“com.webrtc.cn.YeasScreenShare”，将其替换成自己创建的replayKit的BundleId，
5.开始屏幕共享调用navigator.mediaDevices.getScreenShareMedia（屏幕共享开始后flutter端会接收到TRCPeerConnection 的onBeginScreenShare回调事件），关闭屏幕共享调用navigator.mediaDevices.closeScreenShareMedia（屏幕共享结束后flutter端会接收到RTCPeerConnection的onFinishScreenShare回调事件），
6.使用GPUImage和MLImageSegmentationLibrary实现虚拟背景和美颜效果，具体思路：通过FlutterRTCVideoCamera拿到CMSampleBufferRef，将CMSampleBufferRef转成UIImage，然后使用UIImage结合MLImageSegmentationLibrary抠出人体识别获得UIImage1，使用GPUImage混合UIImage1和背景图片，获得UIImage2，使用GPUImage对UIImage2进行美颜处理，获得UIImage3，将UIImage3转成CVPixelBufferRef，然后在执行webRTC的delegate即可。


### Android

Ensure the following permission is present in your Android Manifest file, located in `<project root>/android/app/src/main/AndroidManifest.xml`:

```xml
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

If you need to use a Bluetooth device, please add:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
```

The Flutter project template adds it, so it may already be there.

Also you will need to set your build settings to Java 8, because official WebRTC jar now uses static methods in `EglBase` interface. Just add this to your app level `build.gradle`:

```groovy
android {
    //...
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
```

If necessary, in the same `build.gradle` you will need to increase `minSdkVersion` of `defaultConfig` up to `21` (currently default Flutter generator set it to `16`).

### Important reminder
When you compile the release apk, you need to add the following operations,
[Setup Proguard Rules](https://github.com/flutter-webrtc/flutter-webrtc/commit/d32dab13b5a0bed80dd9d0f98990f107b9b514f4)

## Contributing

The project is inseparable from the contributors of the community.

- [CloudWebRTC](https://github.com/cloudwebrtc) - Original Author
- [RainwayApp](https://github.com/rainwayapp) - Sponsor
- [亢少军](https://github.com/kangshaojun) - Sponsor
- [ION](https://github.com/pion/ion) - Sponsor
- [reSipWebRTC](https://github.com/reSipWebRTC) - Sponsor

### Example

For more examples, please refer to [flutter-webrtc-demo](https://github.com/cloudwebrtc/flutter-webrtc-demo/).

## Contributors

### Code Contributors

This project exists thanks to all the people who contribute. [[Contribute](CONTRIBUTING.md)].
<a href="https://github.com/cloudwebrtc/flutter-webrtc/graphs/contributors"><img src="https://opencollective.com/flutter-webrtc/contributors.svg?width=890&button=false" /></a>

### Financial Contributors

Become a financial contributor and help us sustain our community. [[Contribute](https://opencollective.com/flutter-webrtc/contribute)]

#### Individuals

<a href="https://opencollective.com/flutter-webrtc"><img src="https://opencollective.com/flutter-webrtc/individuals.svg?width=890"></a>

#### Organizations

Support this project with your organization. Your logo will show up here with a link to your website. [[Contribute](https://opencollective.com/flutter-webrtc/contribute)]

<a href="https://opencollective.com/flutter-webrtc/organization/0/website"><img src="https://opencollective.com/flutter-webrtc/organization/0/avatar.svg"></a>
<a href="https://opencollective.com/flutter-webrtc/organization/1/website"><img src="https://opencollective.com/flutter-webrtc/organization/1/avatar.svg"></a>
<a href="https://opencollective.com/flutter-webrtc/organization/2/website"><img src="https://opencollective.com/flutter-webrtc/organization/2/avatar.svg"></a>
<a href="https://opencollective.com/flutter-webrtc/organization/3/website"><img src="https://opencollective.com/flutter-webrtc/organization/3/avatar.svg"></a>
<a href="https://opencollective.com/flutter-webrtc/organization/4/website"><img src="https://opencollective.com/flutter-webrtc/organization/4/avatar.svg"></a>
<a href="https://opencollective.com/flutter-webrtc/organization/5/website"><img src="https://opencollective.com/flutter-webrtc/organization/5/avatar.svg"></a>
<a href="https://opencollective.com/flutter-webrtc/organization/6/website"><img src="https://opencollective.com/flutter-webrtc/organization/6/avatar.svg"></a>
<a href="https://opencollective.com/flutter-webrtc/organization/7/website"><img src="https://opencollective.com/flutter-webrtc/organization/7/avatar.svg"></a>
<a href="https://opencollective.com/flutter-webrtc/organization/8/website"><img src="https://opencollective.com/flutter-webrtc/organization/8/avatar.svg"></a>
<a href="https://opencollective.com/flutter-webrtc/organization/9/website"><img src="https://opencollective.com/flutter-webrtc/organization/9/avatar.svg"></a>
