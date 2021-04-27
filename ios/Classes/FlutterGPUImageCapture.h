//
//  FlutterGPUImageCapture.h
//  flutter_webrtc
//
//  Created by  on 2021/4/27.
//

#import <WebRTC/WebRTC.h>
#import <UIKit/UIKit.h>
#import <GPUImage/GPUImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface FlutterGPUImageCapture : RTCVideoCapturer
/** videoCamera */
@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate;
- (void)startCapture;
- (void)stopCapture;
@end

NS_ASSUME_NONNULL_END
