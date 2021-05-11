//
//  FlutterScreenCaptureController.h
//  flutter_webrtc
//
//  Created by  on 2021/4/20.
//

#import "FlutterCaptureController.h"
#import "FlutterScreenCapture.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kRTCScreensharingSocketFD;




@interface FlutterScreenCaptureController : FlutterCaptureController
/** appgroupId */
@property (nonatomic, strong) NSString *appGroupId;
@property (nonatomic, retain) FlutterScreenCapture *capturer;
- (instancetype)initWithCapturer:(nonnull FlutterScreenCapture *)capturer;
- (void)startCapture;
- (void)stopCapture;

@end

NS_ASSUME_NONNULL_END
