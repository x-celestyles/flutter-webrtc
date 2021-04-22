//
//  FlutterScreenCapture.h
//  flutter_webrtc
//
//  Created by  on 2021/4/20.
//

#import <WebRTC/WebRTC.h>
#import <AVFoundation/AVFoundation.h>


NS_ASSUME_NONNULL_BEGIN

@class FlutterSocketConnection;

@interface FlutterScreenCapture : RTCVideoCapturer

- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate;

- (void)startCaptureWithConnection:(nonnull FlutterSocketConnection *)connection;

- (void)stopCapture;

@end

NS_ASSUME_NONNULL_END
