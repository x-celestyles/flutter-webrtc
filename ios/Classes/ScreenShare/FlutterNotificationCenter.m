//
//  FlutterNotificationCenter.m
//  flutter_webrtc
//
//  Created by  on 2021/4/22.
//

#import "FlutterNotificationCenter.h"

@implementation FlutterNotificationCenter{
    CFNotificationCenterRef _notificationCenter;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _notificationCenter = CFNotificationCenterGetDarwinNotifyCenter();
    }
    return self;
}

- (void)postNotificationWithName:(NSString*)name {
    CFNotificationCenterPostNotification(_notificationCenter, (__bridge CFStringRef)name, NULL, NULL, true);
}

- (void)registNotificationWithName:(NSString *)name {
    [self unRegistNotificationWithName:name];
    CFStringRef str = (__bridge CFStringRef)name;
    CFNotificationCenterAddObserver(_notificationCenter,
                                    (__bridge const void *)(self),
                                    FlutterNotificationCallback,
                                    str,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}

- (void)unRegistNotificationWithName:(NSString *)name {
    
    CFStringRef str = (__bridge CFStringRef)name;
    CFNotificationCenterRemoveObserver(_notificationCenter,
                                       (__bridge const void *)(self),
                                       str,
                                       NULL);
}


void FlutterNotificationCallback(CFNotificationCenterRef center,
                                void * observer,
                                CFStringRef name,
                                void const * object,
                                CFDictionaryRef userInfo) {
    
//    NSString *identifier = (__bridge NSString *)name;
//    YeasNotificationCenter *noti = (__bridge YeasNotificationCenter *)observer;
//    if (noti.NotificationAnswer) {
//        if ([identifier isEqualToString:kFinishBroadcastNotification]) {
//            noti.NotificationAnswer(FinishScreenShare);
//        }
//    }
}

@end
