//
//  YeasNotificationCenter.h
//  myReplayKit
//
//  Created by  on 2021/4/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    FinishScreenShare,//结束共享
} DarwinNotificationCenterState;

typedef void(^NotificationAnswer)(DarwinNotificationCenterState state);

extern NSNotificationName const kBroadcastStartedNotification;
extern NSNotificationName const kBroadcastStoppedNotification;
extern NSNotificationName const kFinishBroadcastNotification;

@interface YeasNotificationCenter : NSObject

+ (instancetype)sharedInstance;
- (void)postNotificationWithName:(NSNotificationName)name;
//注册通知
- (void)registNotificationWithName:(NSString *)name;
/** 收到通知以后回调出去 */
@property (nonatomic, copy) NotificationAnswer NotificationAnswer;


@end

NS_ASSUME_NONNULL_END
