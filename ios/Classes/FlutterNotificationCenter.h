//
//  FlutterNotificationCenter.h
//  flutter_webrtc
//
//  Created by  on 2021/4/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FlutterNotificationCenter : NSObject
- (void)postNotificationWithName:(NSNotificationName)name;
//注册通知
- (void)registNotificationWithName:(NSString *)name;
@end

NS_ASSUME_NONNULL_END
