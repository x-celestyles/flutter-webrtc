//
//  FlutterRTCVideoCamera.h
//  flutter_webrtc
//
//  Created by  on 2021/5/11.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FlutterRTCVideoCameraDelegate <NSObject>

- (void)didOutPutSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

@interface FlutterRTCVideoCamera : NSObject
@property(nonatomic, strong) AVCaptureSession *session;
- (void)startCaputre;

- (void)stopCapture;
- (void)changeCameraPosition;
/** delegate */
@property (nonatomic) id <FlutterRTCVideoCameraDelegate>delegate;

@end

NS_ASSUME_NONNULL_END
