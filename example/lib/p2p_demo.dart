import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// ignore: unused_import

// import 'package:webrtc_example/p2p_demo.dart';
import 'package:flutter_webrtc_example/rtc_signaling.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_webrtc_example/p2p_demo.dart';

//import 'package:flutter_webrtc/rtc_video_view.dart';

class P2PDemo extends StatefulWidget {
  final String url;

  // ignore: sort_constructors_first
  P2PDemo({required this.url});

  @override
  _P2PDemoState createState() => _P2PDemoState(serverurl: url);
}

class _P2PDemoState extends State<P2PDemo> {
  final String serverurl;

  // ignore: sort_constructors_first
  _P2PDemoState({required this.serverurl});

  // rtc 信令对象
  late RTCSignaling _rtcSignaling;

  // 本地设备名称
  final String _displayName =
      '${Platform.localeName.substring(0, 2)} + ( ${Platform.operatingSystem} )';
  // 房间内的
  final List<dynamic> _peers = [];
  var _selfId;
  // 本地媒体视频窗口
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  // 对端媒体视频窗口

  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _inCalling = false;

  // 初始化
  @override
  void initState() {
    super.initState();
    initRenderers();
    // connect();
    _rtcSignaling = RTCSignaling(url: serverurl, displayName: _displayName);
    _connect();
  }

  // void connect() async {
  //   await _connect();
  //   // 加载本地媒体流
  //   await _rtcSignaling.createStream();
  // }

  void dispose() {
    _localRenderer.dispose();
    // _localRenderer = null;
    _remoteRenderer.dispose();
    // _remoteRenderer = null;
    debugPrint('dispose=========>>>>>>>');
    if (_rtcSignaling != null) _rtcSignaling.close();

    super.dispose();
  }

  // 懒加载本地和对端渲染窗口
  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  // 销毁操作
  @override
  void deactivate() {
    super.deactivate();
  }

  // 创建联系
  Future<void> _connect() async {
    // 初始化信令
    // if (_rtcSignaling == null) {
    // _rtcSignaling = RTCSignaling(url: serverurl, displayName: _displayName);
    // 信令状态回调
    _rtcSignaling.onStateChange = (SignalingState state) {
      switch (state) {
        case SignalingState.CallStateNew:
          setState(() {
            _inCalling = true;
          });
          break;
        case SignalingState.CallStateBye:
          setState(() {
            _localRenderer.srcObject = null;
            _remoteRenderer.srcObject = null;
            _inCalling = false;
          });
          break;
        case SignalingState.CallStateRinging:
          break;
        case SignalingState.CallStateInvite:
          break;
        case SignalingState.CallStateConnected:
          break;

        case SignalingState.ConnectionOpen:
          break;
        case SignalingState.ConnectionClosed:
          break;
        case SignalingState.ConnectionError:
          break;
      }
    };
    // 更新房间人员列表
    _rtcSignaling.onPeersUpdate = (event) {
      debugPrint('onPeersUpdate========>>>>>>');
      setState(() {
        _selfId = event['self'];
        _peers.removeRange(0, _peers.length);
        _peers.addAll(event['peers']);
      });
    };

    // 设置本地媒体
    _rtcSignaling.onLocalStream = (stream) {
      _localRenderer.srcObject = stream;
    };

    // 设置远端媒体
    _rtcSignaling.onAddRemoteStream = (stream) {
      _remoteRenderer.srcObject = stream;
      setState(() {});
    };

    // 移除远端媒体
    _rtcSignaling.onRemoveRemoteStream = (stream) {
      _remoteRenderer.srcObject = null;
    };

    // socket 进行连接
    await _rtcSignaling.createStream();
    // await _rtcSignaling.screenShareStream();
    await Future.delayed(Duration(milliseconds: 1000));
    _rtcSignaling.connect();
    // }
  }

  // 邀请对方
  // ignore: always_declare_return_types
  _invitePeer(peerId) async {
    if (_rtcSignaling != null && peerId != _selfId) {
      _rtcSignaling.invite(peerId);
    }
  }

  // 挂断
  // ignore: always_declare_return_types
  _hangUp() {
    _rtcSignaling.closeScreenShare();
    // if (_rtcSignaling != null) {
    //   _rtcSignaling.bye();
    // }
  }

  // 切换成屏幕共享
  void _switchCamera() {
    _rtcSignaling.localStream.dispose();
    // _rtcSignaling.screenShareStream();
    // _rtcSignaling.switchCamera();
    // _localRenderer.mirror = true;

    _rtcSignaling.changeVirtualBack();
  }

  // 初始化 列表
  ListBody _buildRow(context, peer) {
    bool self = peer['id'] == _selfId;

    return ListBody(
      children: <Widget>[
        ListTile(
          title: Text(self
              ? peer['name'] + '自己'
              : peer['name'] + '${peer['user_agent']}]'),
          trailing: SizedBox(
            width: 100.0,
            child: IconButton(
              icon: Icon(Icons.videocam),
              onPressed: () => _invitePeer(peer['id']),
            ),
          ),
        ),
        Divider()
      ],
    );
  }

  // 构建当前视图
  @override
  Widget build(BuildContext context) {
    // _inCalling = true;
    return Scaffold(
      appBar: AppBar(
        title: Text('P2P Call sample'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _inCalling
          ? SizedBox(
              width: 200.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  FloatingActionButton(
                    heroTag: 1,
                    onPressed: _switchCamera,
                    child: Icon(Icons.switch_camera),
                  ),
                  FloatingActionButton(
                    heroTag: 2,
                    onPressed: _hangUp,
                    child: Icon(Icons.call_end),
                    backgroundColor: Colors.deepOrange,
                  )
                ],
              ),
            )
          : null,
      body: _inCalling
          ? OrientationBuilder(
              builder: (context, orientation) {
                return Container(
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            margin: EdgeInsets.all(0),
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height,
                            child: RTCVideoView(_remoteRenderer),
                            decoration: BoxDecoration(color: Colors.grey),
                          )),
                      Positioned(
                          right: 20.0,
                          top: 20.0,
                          child: Container(
                            width: orientation == Orientation.portrait
                                ? 135.0
                                : 180.0,
                            height: orientation == Orientation.portrait
                                ? 180.0
                                : 135.0,
                            child: RTCVideoView(_localRenderer),
                            decoration: BoxDecoration(color: Colors.black54),
                          ))
                    ],
                  ),
                );
              },
            )
          : ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.all(0.0),
              // ignore: unnecessary_null_comparison
              itemCount: _peers != null ? _peers.length : 0,
              itemBuilder: (context, i) {
                return _buildRow(context, _peers[i]);
              }),
    );
  }
}
