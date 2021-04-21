//
//  SampleHandler.m
//  YeasScreenShare
//
//  Created by  on 2021/4/21.
//


#import "SampleHandler.h"
#import "YeasSampleUploader.h"
#import "YeasSocketConnection.h"
#import "YeasNotificationCenter.h"

@interface SampleHandler()
@property (nonatomic, retain) YeasSocketConnection *clientConnection;
@property (nonatomic, retain) YeasSampleUploader *uploader;
@end

@implementation SampleHandler

- (instancetype)init {
    if (self = [super init]) {
        self.clientConnection = [[YeasSocketConnection alloc] initWithFilePath:self.socketFilePath];
        [self setupConnection];

        self.uploader = [[YeasSampleUploader alloc] initWithConnection:self.clientConnection];
        
    }
    return self;
}

- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *,NSObject *> *)setupInfo {
    
    __weak typeof(self) weakSelf = self;
    [[YeasNotificationCenter sharedInstance] registNotificationWithName:kFinishBroadcastNotification];
    [YeasNotificationCenter sharedInstance].NotificationAnswer = ^(DarwinNotificationCenterState state) {
        [weakSelf handleWithState:state];
    };
    [self openConnection];
}

- (void)broadcastPaused {
    
}

- (void)broadcastResumed {
    
}

- (void)broadcastFinished {
    [self.clientConnection close];
}



- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType {
    
    static NSUInteger frameCount = 0;
    switch (sampleBufferType) {
        case RPSampleBufferTypeVideo:
            if (++frameCount%3 == 0 && self.uploader.isReady) {
              [self.uploader sendSample:sampleBuffer];
            }
            break;
        case RPSampleBufferTypeAudioApp:
            break;
        case RPSampleBufferTypeAudioMic:
            break;
        default:
            break;
    }
}

- (void)handleWithState:(DarwinNotificationCenterState)stata {
    switch (stata) {
        case FinishScreenShare:
            [self finishBroadcastWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil]];
            break;
        default:
            break;
    }
}

- (NSString *)socketFilePath {


    NSString *appGroupIdentifier = @"group.yeas.com";
    NSURL *sharedContainer = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:appGroupIdentifier];
    NSString *socketFilePath = [[sharedContainer URLByAppendingPathComponent:@"rtc_SSFD"] path];

    return socketFilePath;
}

- (void)setupConnection {
  __weak __typeof(self) weakSelf = self;
  self.clientConnection.didClose = ^(NSError *error) {
    if (error) {
      [weakSelf finishBroadcastWithError:error];
    }
    else {
      NSInteger JMScreenSharingStopped = 10001;
      NSError *customError = [NSError errorWithDomain:RPRecordingErrorDomain
                                                 code:JMScreenSharingStopped
                                             userInfo:@{NSLocalizedDescriptionKey: @"Screen sharing stopped"}];
      [weakSelf finishBroadcastWithError:customError];
    }
  };
}

- (void)openConnection {
  dispatch_queue_t queue = dispatch_queue_create("org.jitsi.meet.broadcast.connectTimer", 0);
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
  dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), 0.1 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);

  dispatch_source_set_event_handler(timer, ^{
    BOOL success = [self.clientConnection open];
    if (success) {
      dispatch_source_cancel(timer);
    }
  });

  dispatch_resume(timer);
}

@end
