import 'dart:convert';
import 'dart:async';

import 'dart:io';

import 'package:flutter/cupertino.dart';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:web_socket_channel/io.dart';

import 'package:random_string/random_string.dart';

// 信令状态
enum SignalingState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

/*
 * callbacks for Signaling API.
 */

// 信令状态的回调
typedef void SignalingStateCallback(SignalingState state);
// 媒体流的状态回调
typedef void StreamStateCallback(MediaStream stream);
// 对方进入房价回调
typedef void OtherEventCallback(dynamic event);

class RTCSignaling {
  final String _selfId = randomNumeric(6);
  late IOWebSocketChannel _channel;

  late String _sessionId;

  late String url;
  late String displayName;
  var _peerConnections = new Map<String, RTCPeerConnection>();

  List<Map<String, dynamic>> peers = [];

  late MediaStream localStream;
  late MediaStream localScreenStream;
  late List<MediaStream> _remoteStreams;
  late SignalingStateCallback onStateChange;
  late StreamStateCallback onLocalStream;
  late StreamStateCallback onAddRemoteStream;
  late StreamStateCallback onRemoveRemoteStream;
  late OtherEventCallback onPeersUpdate;
  late RTCPeerConnection myPeerConnection;

  JsonDecoder decoder = new JsonDecoder();

  /*
  * ice turn、stun 服务器 配置
  * */
  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
      /*
       * turn server configuration example.
      {
        'url': 'turn:123.45.67.89:3478',
        'username': 'change_to_real_user',
        'credential': 'change_to_real_secret'
      },
       */
    ]
  };

  /*
  * DTLS 是否开启
  * */
  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  /*
  * 音视频约束
  * */
  final Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  // ignore: sort_constructors_first
  RTCSignaling({required this.url, required this.displayName});

  /*
  * socket 连接
  * */
  connect() async {
    try {
      _channel = IOWebSocketChannel.connect(url);

      print('连接成功');
      this.onStateChange(SignalingState.ConnectionOpen);

      _channel.stream.listen((message) {
        print('receive $message');
        onMessage(message);
      }).onDone(() {
        print('Closed by server!');

        if (this.onStateChange != null) {
          this.onStateChange(SignalingState.ConnectionClosed);
        }
      });

      /*
      * 连接socket注册自己
      * */
      var operatingSystem;
      _send('new', {
        'name': displayName,
        'id': _selfId,
        'user_agent': 'flutter-webrtc + ${Platform.operatingSystem}'
      });
    } catch (e) {
      print(e.toString());
      if (this.onStateChange != null) {
        this.onStateChange(SignalingState.ConnectionError);
      }
    }
  }

  /*
  * 创建本地媒体流
  * */
  Future<MediaStream> createStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth':
              '640', // Provide your own width, height and frame rate here
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };

    MediaStream stream = await navigator.getUserMedia(mediaConstraints);
    if (this.onLocalStream != null) {
      this.onLocalStream(stream);
    }
    this.localStream = stream;
    return stream;
  }

  /*
  * 创建屏幕共享媒体，必须添加preferredExtension和appGroupId字段
  * */
  Future<MediaStream> screenShareStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      },
      'preferredExtension': 'com.webrtc.cn.YeasScreenShare',
      'appGroupId': 'group.yeas.com'
    };
    MediaStream stream =
        await navigator.mediaDevices.getScreenShareMedia(mediaConstraints);
    this.localScreenStream = stream;
    if (this.onLocalStream != null) {
      this.onLocalStream(stream);
    }
    await myPeerConnection.getSenders().then((senders) {
      senders.forEach((element) {
        if (element.track!.kind == 'video') {
          element.replaceTrack(stream.getVideoTracks()[0]);
        }
      });
    });
    return stream;
  }

/*
*关闭屏幕共享
**/
  Future<void> closeScreenShare() async {
    await navigator.mediaDevices.closeScreenShareMedia();
  }

  //改变虚拟背景图片(同时会开启虚拟背景，需要传一张png格式的图片)
  Future<void> changeVirtualBack() async {
    final constraints = <String, dynamic>{
      'virtualBackground': 'back_groud2.png'
    };
    await navigator.mediaDevices.changeVirtualBackGround(constraints);
  }

  //关闭虚拟背景
  Future<void> closeVirtualBack() async {
    final constraints = <String, dynamic>{'close': '1'};
    await navigator.mediaDevices.changeVirtualBackGround(constraints);
  }

  /*
  * 关闭本地媒体，断开socket
  * */
  close() {
    debugPrint('signal ----close======>>>>${localStream == null}');
    if (localStream != null) {
      debugPrint('signal ---localStream-close======>>>>');
      localStream.dispose();
      // localStream = null;
    }

    _peerConnections.forEach((key, pc) {
      pc.close();
    });
    this.peers.clear();
    if (_channel != null) _channel.sink.close();
  }

  /*
  * 切换前后摄像头
  * */
  void switchCamera() {
    if (localStream != null) {
      localStream.getVideoTracks()[0].switchCamera();
    }
  }

  /*
  * 邀请对方进行会话
  * */
  void invite(String peer_id) {
    this._sessionId = '$_selfId-$peer_id}';

    if (this.onStateChange != null) {
      this.onStateChange(SignalingState.CallStateNew);
    }

    /*
    * 创建一个peerconnection
    * */
    _createPeerConnection(peer_id, _config).then((pc) {
      _peerConnections[peer_id] = pc;
      //
      _createOffer(peer_id, pc);

      // pc.onBeginScreenShare = () {
      //   //关闭本地的摄像
      //   localStream.dispose();
      // };
      // pc.onFinishScreenShare = () {
      //   //重新开启本地拍摄
      //   createStream();
      // };
    });
  }

  /*
  * 收到消息处理逻辑
  * */
  void onMessage(message) async {
    Map<String, dynamic> mapData = decoder.convert(message);
    // if(mapData['id'] == _selfId){
    //   return;
    // }
    var data = mapData['data'];

    switch (mapData['type']) {
      /*
      * 新成员加入刷新界面
      * */
      // case 'peers':
      case 'new':
        {
          debugPrint('new=========>>>${peers.length}');
          Map<String, dynamic> peer = data;
          bool exist = false;
          if (this.peers.length > 0) {
            this.peers.forEach((element) {
              debugPrint('new=========>>>${peer['id']}');
              debugPrint('new=========>>>${element['id']}');
              if (peer['id'] == element['id']) {
                exist = true;
              }
            });
          }

          debugPrint('new=======exist==>>>$exist');
          if (!exist) {
            this.peers.add(peer);
            Map<String, dynamic> event = Map<String, dynamic>();
            event['self'] = _selfId;
            event['peers'] = peers;
            this.onPeersUpdate(event);
          }
          // List<dynamic> peers = data;
          // if (this.onPeersUpdate != null) {
          //   Map<String, dynamic> event = Map<String, dynamic>();
          //   event['self'] = _selfId;
          //   event['peers'] = peers;
          //   this.onPeersUpdate(event);
          // }
        }
        break;

      /*
      * 获取远端的offer
      * */
      case 'offer':
        {
          String id = data['from'];
          if (id == _selfId) return;

          print('offer from $id ');
          var description = data['description'];
          var sessionId = data['session_id'];
          this._sessionId = sessionId;

          if (this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateNew);
          }
          /*
          * 收到远端offer后 创建自己的peerconnection
          * 之后设置远端的媒体信息,并向对端发送answer进行应答
          * */
          _config['isMine'] = '1';
          _createPeerConnection(id, _config).then((pc) {
            pc.onBeginScreenShare = () {
              localStream.dispose();
            };
            pc.onFinishScreenShare = () {
              localScreenStream.dispose();
              createStream();
            };
            _peerConnections[id] = pc;
            pc.setRemoteDescription(
                RTCSessionDescription(description['sdp'], description['type']));
            _createAnswer(id, pc);
          });
        }
        break;

      /*
      * 收到对端 answer
      * */
      case 'answer':
        {
          String id = data['from'];
          if (id == _selfId) return;

          print('answer from $id ');
          Map description = data['description'];

          RTCPeerConnection pc = _peerConnections[id]!;
          if (pc != null) {
            // 给peerconnection设置remote媒体信息
            pc.setRemoteDescription(
                RTCSessionDescription(description['sdp'], description['type']));
          }
        }
        break;
      /*
      * 收到远端的候选者，并添加给候选者
      * */
      case 'candidate':
        {
          String id = data['from'];
          if (id == _selfId) return;

          print('candidate from $id ');
          Map candidateMap = data['candidate'];
          RTCPeerConnection pc = _peerConnections[id]!;

          if (pc != null) {
            RTCIceCandidate candidate = new RTCIceCandidate(
                candidateMap['candidate'],
                candidateMap['sdpMid'],
                candidateMap['sdpMLineIndex']);
            pc.addCandidate(candidate);
          }
        }
        break;

      /*
      * 对方离开，断开连接
      * */
      case 'leave':
        {
          var id = data;
          _peerConnections.remove(id);
          if (localStream != null) {
            localStream.dispose();
            // localStream = null;
          }

          RTCPeerConnection pc = _peerConnections[id]!;
          if (pc != null) {
            pc.close();
            _peerConnections.remove(id);
          }
          this._sessionId = "";
          if (this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateBye);
          }
        }
        break;

      case 'bye':
        {
          var to = data['to'];

          if (localStream != null) {
            localStream.dispose();
            // localStream = null;
          }

          RTCPeerConnection pc = _peerConnections[to]!;
          if (pc != null) {
            pc.close();
            _peerConnections.remove(to);
          }

          this._sessionId = "";
          if (this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateBye);
          }
        }
        break;

      case 'keepalive':
        {
          print('keepaive');
        }
        break;
    }
  }

  /*
  * 结束会话
  * */
  void bye() {
    _send('bye', {
      'session_id': this._sessionId,
      'from': this._selfId,
      'to': this._selfId,
    });
  }

  /*
  * 创建peerconnection
  * */
  Future<RTCPeerConnection> _createPeerConnection(id, config) async {
    //获取本地媒体 并赋值给peerconnection
    RTCPeerConnection pc = await createPeerConnection(_iceServers, config);
    myPeerConnection = pc;

    pc.addStream(this.localStream);

    /*
    * 获得获选者
    * */
    pc.onIceCandidate = (candidate) {
      print('onIceCandidate');
      /*
      * 获取候选者后，向对方发送候选者
      * */
      _send('candidate', {
        'from': _selfId,
        'to': id,
        'candidate': {
          'sdpMLineIndex': candidate.sdpMlineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        },
        'session_id': this._sessionId,
      });
    };

    pc.onIceConnectionState = (state) {};

    /*
    * 获取远端的媒体流
    * */
    pc.onAddStream = (stream) {
      if (this.onAddRemoteStream != null) this.onAddRemoteStream(stream);
    };

    /*
    * 移除远端的媒体流
    * */
    pc.onRemoveStream = (stream) {
      if (this.onRemoveRemoteStream != null) this.onRemoveRemoteStream(stream);
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };

    return pc;
  }

  /*
  * 创建offer
  * */
  _createOffer(String id, RTCPeerConnection pc) async {
    try {
      RTCSessionDescription s = await pc.createOffer(_constraints);
      pc.setLocalDescription(s);
      //向远端发送自己的媒体信息
      _send('offer', {
        'from': _selfId,
        'to': id,
        'description': {'sdp': s.sdp, 'type': s.type},
        'session_id': this._sessionId,
      });
    } catch (e) {
      print(e.toString());
    }
  }

  /*
  * 创建answer
  * */
  _createAnswer(String id, RTCPeerConnection pc) async {
    try {
      RTCSessionDescription s = await pc.createAnswer(_constraints);
      pc.setLocalDescription(s);
      /*
      * 回复answer
      * */
      _send('answer', {
        'from': _selfId,
        'to': id,
        'description': {'sdp': s.sdp, 'type': s.type},
        'session_id': this._sessionId,
      });
    } catch (e) {
      print(e.toString());
    }
  }

  /*
  * 消息发送
  * */
  void _send(event, data) {
    Map<String, dynamic> dataMap = <String, dynamic>{};
    dataMap['type'] = event;
    dataMap['data'] = data;
    JsonEncoder encoder = new JsonEncoder();
    if (_channel != null) _channel.sink.add(encoder.convert(dataMap));
    print('send: ' + encoder.convert(data));
  }
}
