//
//  YeasNotificationCenter.m
//  myReplayKit
//
//  Created by  on 2021/4/20.
//

#import "YeasNotificationCenter.h"

//共享已开启
NSNotificationName const kBroadcastStartedNotification = @"iOS_BroadcastStarted";
//共享已暂停
NSNotificationName const kBroadcastStoppedNotification = @"iOS_BroadcastStopped";
//暂停共享
NSNotificationName const kFinishBroadcastNotification = @"iOS_FinishBroadcast";

@implementation YeasNotificationCenter{
    CFNotificationCenterRef _notificationCenter;
}

+ (instancetype)sharedInstance {
    static YeasNotificationCenter *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
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
                                    MyHoleNotificationCallback,
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


void MyHoleNotificationCallback(CFNotificationCenterRef center,
                                void * observer,
                                CFStringRef name,
                                void const * object,
                                CFDictionaryRef userInfo) {
    
    NSString *identifier = (__bridge NSString *)name;
    YeasNotificationCenter *noti = (__bridge YeasNotificationCenter *)observer;
    if (noti.NotificationAnswer) {
        if ([identifier isEqualToString:kFinishBroadcastNotification]) {
            noti.NotificationAnswer(FinishScreenShare);
        }
    }
}


@end
