//
//  YeasSampleUploader.h
//  myReplayKit
//
//  Created by  on 2021/4/20.
//

#import <Foundation/Foundation.h>
#import <ReplayKit/ReplayKit.h>

NS_ASSUME_NONNULL_BEGIN

@class YeasSocketConnection;
@interface YeasSampleUploader : NSObject
@property (nonatomic, assign, readonly) BOOL isReady;

- (instancetype)initWithConnection:(YeasSocketConnection *)connection;
- (void)sendSample:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
