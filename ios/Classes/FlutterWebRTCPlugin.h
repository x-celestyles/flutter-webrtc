#import <Flutter/Flutter.h>
#import <Foundation/Foundation.h>

#import <WebRTC/RTCDataChannel.h>
#import <WebRTC/RTCPeerConnection.h>
#import <WebRTC/RTCDataChannel.h>
#import <WebRTC/RTCDataChannelConfiguration.h>
#import <WebRTC/RTCMediaStreamTrack.h>
#import <WebRTC/RTCCameraVideoCapturer.h>

#import <ReplayKit/ReplayKit.h>
#import "FlutterScreenCaptureController.h"
#import "FlutterNotificationCenter.h"
#import "FlutterGPUImageCapture.h"

//#import "FlutterWebrtcCameraWithGPUImageCapture.h"
//#import "FlutterWebrtcCameraWithGPUImageCapture.h"

@class FlutterRTCVideoRenderer;

@interface FlutterWebRTCPlugin : NSObject<FlutterPlugin, RTCPeerConnectionDelegate>

@property (nonatomic, strong) RTCPeerConnectionFactory *peerConnectionFactory;
@property (nonatomic, strong) NSMutableDictionary<NSString *, RTCPeerConnection *> *peerConnections;
@property (nonatomic, strong) NSMutableDictionary<NSString *, RTCMediaStream *> *localStreams;
@property (nonatomic, strong) NSMutableDictionary<NSString *, RTCMediaStreamTrack *> *localTracks;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, FlutterRTCVideoRenderer *> *renders;
@property (nonatomic, retain) UIViewController *viewController;/*for broadcast or ReplayKit */
@property (nonatomic, strong) NSObject<FlutterBinaryMessenger>* messenger;
@property (nonatomic, strong) RTCCameraVideoCapturer *videoCapturer;

/** 使用GPUImage的videoCamera */
@property (nonatomic, strong) FlutterGPUImageCapture *GPUVideoCamera;

@property (nonatomic) BOOL _usingFrontCamera;
@property (nonatomic) int _targetWidth;
@property (nonatomic) int _targetHeight;
@property (nonatomic) int _targetFps;

@property (nonatomic, strong) RPSystemBroadcastPickerView *pickView;
/** FlutterScreenCaptureController */
@property (nonatomic, strong) FlutterScreenCaptureController *screenCaptureController;
/** replayKitVideoTrack */
@property (nonatomic, strong) RTCVideoTrack *screenVideoTrack;
@property (nonatomic, strong) RTCVideoTrack *GPUImageVideoTrack;
/** FlutterNotificationCenter */
@property (nonatomic, strong) FlutterNotificationCenter *notification;
/** 是否使用美颜效果 */
@property (nonatomic) BOOL isUseGPUImage;

- (RTCMediaStream*)streamForId:(NSString*)streamId peerConnectionId:(NSString *)peerConnectionId;

@end
