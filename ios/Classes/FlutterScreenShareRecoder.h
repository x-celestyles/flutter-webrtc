//
//  FlutterScreenShareRecoder.h
//  flutter_webrtc
//
//  Created by  on 2021/4/10.
//

#import <WebRTC/WebRTC.h>

NS_ASSUME_NONNULL_BEGIN

@interface FlutterScreenShareRecoder : RTCVideoCapturer

- (void)startCapture;
-(void)stopCapture;


@end

NS_ASSUME_NONNULL_END
