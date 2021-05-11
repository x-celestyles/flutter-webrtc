//
//  FlutterSocketConnection.h
//  flutter_webrtc
//
//  Created by  on 2021/4/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FlutterSocketConnection : NSObject

- (instancetype)initWithFilePath:(nonnull NSString *)filePath;
- (void)openWithStreamDelegate:(id <NSStreamDelegate>)streamDelegate;
- (void)close;

@end

NS_ASSUME_NONNULL_END
