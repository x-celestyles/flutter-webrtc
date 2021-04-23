//
//  FlutterScreenCaptureController.m
//  flutter_webrtc
//
//  Created by  on 2021/4/20.
//

#import "FlutterScreenCaptureController.h"
#import "FlutterSocketConnection.h"

NSString* const kRTCScreensharingSocketFD = @"rtc_SSFD";

@interface FlutterScreenCaptureController ()

@end

@interface FlutterScreenCaptureController (Private)

@property (nonatomic, readonly) NSString *appGroupIdentifier;

@end


@implementation FlutterScreenCaptureController
- (instancetype)initWithCapturer:(nonnull FlutterScreenCapture *)capturer {
    self = [super init];
    if (self) {
        self.capturer = capturer;
    }
    
    return self;
}

- (void)startCapture {
    
    if (!self.appGroupIdentifier) {
        return;
    }
    
    NSString *socketFilePath = [self filePathForApplicationGroupIdentifier:self.appGroupIdentifier];
    FlutterSocketConnection *connection = [[FlutterSocketConnection alloc] initWithFilePath:socketFilePath];
    
    
    [self.capturer startCaptureWithConnection:connection];
}

- (void)stopCapture {

    [self.capturer stopCapture];
}



- (NSString *)appGroupIdentifier {

//    return @"group.yeas.com";
    return self.appGroupId;
}

- (NSString *)filePathForApplicationGroupIdentifier:(nonnull NSString *)identifier {
    NSURL *sharedContainer = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:identifier];
    NSString *socketFilePath = [[sharedContainer URLByAppendingPathComponent:kRTCScreensharingSocketFD] path];
    
    return socketFilePath;
}
@end
