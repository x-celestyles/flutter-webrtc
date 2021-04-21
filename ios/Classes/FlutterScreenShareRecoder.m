//
//  FlutterScreenShareRecoder.m
//  flutter_webrtc
//
//  Created by  on 2021/4/10.
//

#import "FlutterScreenShareRecoder.h"
#import <ReplayKit/ReplayKit.h>

@implementation FlutterScreenShareRecoder {
    RTCVideoSource *source;
    RPSystemBroadcastPickerView *pickView;
}


- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate {
    source = delegate;
    NSLog(@"添加新的监听");
    [self addNotification];
    return [super initWithDelegate:delegate];
}

//视频录制数据监听
- (void)addNotification {
    [self registerForNotificationsWithIdentifier:@"broadcastStartedWithSetupInfo"];
    [self registerForNotificationsWithIdentifier:@"broadcastPaused"];
    [self registerForNotificationsWithIdentifier:@"broadcastResumed"];
    [self registerForNotificationsWithIdentifier:@"broadcastFinished"];
    [self registerForNotificationsWithIdentifier:@"processSampleBuffer"];
}
//注册通知
- (void)registerForNotificationsWithIdentifier:(nullable NSString *)identifier {
    [self unregisterForNotificationsWithIdentifier:identifier];
    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
    CFStringRef str = (__bridge CFStringRef)identifier;
    CFNotificationCenterAddObserver(center,
                                    (__bridge const void *)(self),
                                    MyHoleNotificationCallback,
                                    str,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}
//移除通知
- (void)removeUploaderEventMonitor {
    [self unregisterForNotificationsWithIdentifier:@"broadcastStartedWithSetupInfo"];
    [self unregisterForNotificationsWithIdentifier:@"broadcastPaused"];
    [self unregisterForNotificationsWithIdentifier:@"broadcastResumed"];
    [self unregisterForNotificationsWithIdentifier:@"broadcastFinished"];
    [self unregisterForNotificationsWithIdentifier:@"processSampleBuffer"];
}

- (void)unregisterForNotificationsWithIdentifier:(nullable NSString *)identifier {
    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
    CFStringRef str = (__bridge CFStringRef)identifier;
    CFNotificationCenterRemoveObserver(center,
                                       (__bridge const void *)(self),
                                       str,
                                       NULL);
}


//收到通知的回调
void MyHoleNotificationCallback(CFNotificationCenterRef center,
                                   void * observer,
                                   CFStringRef name,
                                   void const * object,
                                   CFDictionaryRef userInfo) {
    NSString *identifier = (__bridge NSString *)name;
    NSObject *sender = (__bridge NSObject *)observer;
    NSDictionary *info = CFBridgingRelease(userInfo);
    NSDictionary *notiUserInfo = @{@"identifier":identifier};
    NSLog(@"开始接受通知啦：%@",identifier);
    if ([identifier isEqualToString:@"broadcastStartedWithSetupInfo"]) {
    } else if ([identifier isEqualToString:@"broadcastPaused"]) {
        
    } else if ([identifier isEqualToString:@"broadcastResumed"]) {
        
    } else if ([identifier isEqualToString:@"broadcastFinished"]) {
        
    } else if ([identifier isEqualToString:@"processSampleBuffer"]) {
        
    }
    
}


- (void)startCapture {
    
    pickView = [[RPSystemBroadcastPickerView alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    pickView.preferredExtension = @"com.webrtc.example.myReplayKit";
    pickView.showsMicrophoneButton = NO;
    for (UIView *view in pickView.subviews) {
        NSLog(@"pickviews：%@",view);
        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)view;
            [btn sendActionsForControlEvents:UIControlEventAllEvents];
            break;
        }
    }
}


- (void)stopCapture {
    //停止录制的时候需要移除所有的通知监听
    [self removeUploaderEventMonitor];
    for (UIView *view in pickView.subviews) {
        if ([view isKindOfClass:[UIButton class]]) {
            NSLog(@"pickviews：%@",view);
            UIButton *btn = (UIButton *)view;
            [btn sendActionsForControlEvents:UIControlEventAllEvents];
            break;
        }
    }
    
    __weak typeof(self) weakSelf = self;
//    [[RPScreenRecorder sharedRecorder] stopRecordingWithHandler:^(RPPreviewViewController * _Nullable previewViewController, NSError * _Nullable error) {
//        [weakSelf removeUploaderEventMonitor];
//        if (error) {
//            NSLog(@"关闭失败的描述：%@",error.description);
//        }
//    }];
    
//    [[RPScreenRecorder sharedRecorder] stopCaptureWithHandler:^(NSError * _Nullable error) {
//        [weakSelf removeUploaderEventMonitor];
//        if (error) {
//            NSLog(@"关闭失败的描述：%@",error.description);
//        }
//    }];
}

@end
