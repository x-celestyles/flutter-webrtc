//
//  FlutterGPUImageCapture.h
//  flutter_webrtc
//
//  Created by  on 2021/4/27.
//

#import <WebRTC/WebRTC.h>
#import <UIKit/UIKit.h>
#import <GPUImage/GPUImage.h>

#include <sys/time.h>

#import "FlutterRTCVideoCamera.h"


#define HW_TIME_BEGIN(name) \
    struct timeval name##t1, name##t2; \
    __block double name##t1t2; \
    gettimeofday(&name##t1, NULL);

#define HW_TIME_END(name) \
    gettimeofday(&name##t2, NULL); \
    name##t1t2 = (name##t2.tv_sec - name##t1.tv_sec) * 1000 + (name##t2.tv_usec - name##t1.tv_usec) / 1000.0f;

NS_ASSUME_NONNULL_BEGIN

@interface FlutterGPUImageCapture : RTCVideoCapturer
/** 视频采集 */
@property (nonatomic, strong) FlutterRTCVideoCamera *videoCamera;
/** videoCamera */
//@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
/** 磨皮的数值 */
@property (nonatomic) CGFloat bilateral;
/** 美白的数值 */
@property (nonatomic) CGFloat brightness;
- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate;
- (void)startCapture;
- (void)stopCapture;
@end

NS_ASSUME_NONNULL_END
