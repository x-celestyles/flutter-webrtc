//
//  FlutterScreenCapture.h
//  flutter_webrtc
//
//  Created by  on 2021/4/20.
//

#import <WebRTC/WebRTC.h>
#import <AVFoundation/AVFoundation.h>


typedef void(^screenCompletion)(void);

NS_ASSUME_NONNULL_BEGIN

@class FlutterSocketConnection;

@interface FlutterScreenCapture : RTCVideoCapturer

- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate;

- (void)startCaptureWithConnection:(nonnull FlutterSocketConnection *)connection;

- (void)stopCapture;

/** screenCompletion */
@property (nonatomic, copy) screenCompletion screenCompletion;

@end

NS_ASSUME_NONNULL_END
