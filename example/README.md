# webrtc_example

Demonstrates how to use the webrtc plugin.

## Getting Started

iOS使用注意事项：
1.在项目的Runner中创建ReplayKit和AppGroup
2.在ReplayKit扩展中创建AppGroup，添加YeasNotificationCenter，YeasSampleUploader和YeasSocketConnection三个文件
3.项目中使用了AppGroup进行跨进程通信，在replayKit和插件中搜索“group.yeas.com”,将其替换成自己创建的AppGroup
4.在插件中搜索“com.webrtc.cn.YeasScreenShare”，将其替换成自己创建的replayKit的BundleId，
5.开始屏幕共享调用navigator.mediaDevices.getScreenShareMedia（屏幕共享开始后flutter端会接收到TRCPeerConnection 的onBeginScreenShare回调事件），关闭屏幕共享调用navigator.mediaDevices.closeScreenShareMedia（屏幕共享结束后flutter端会接收到RTCPeerConnection的onFinishScreenShare回调事件），
6.使用GPUImage和MLImageSegmentationLibrary实现虚拟背景和美颜效果，具体思路：通过FlutterRTCVideoCamera拿到CMSampleBufferRef，将CMSampleBufferRef转成UIImage，然后使用UIImage结合MLImageSegmentationLibrary抠出人体识别获得UIImage1，使用GPUImage混合UIImage1和背景图片，获得UIImage2，使用GPUImage对UIImage2进行美颜处理，获得UIImage3，将UIImage3转成CVPixelBufferRef，然后在执行webRTC的delegate即可。

Make sure your flutter is using the `dev` channel.

```bash
flutter channel dev
./scripts/project_tools.sh create
```

Android/iOS

```bash
flutter run
```

macOS

```bash
flutter run -d macos
```

Web

```bash
flutter run -d web
```

Windows

```bash
flutter channel master
flutter create --platforms windows .
flutter run -d windows
```

