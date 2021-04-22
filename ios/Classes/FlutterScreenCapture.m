//
//  FlutterScreenCapture.m
//  flutter_webrtc
//
//  Created by  on 2021/4/20.
//

#import "FlutterScreenCapture.h"
#include <mach/mach_time.h>
#import <WebRTC/RTCCVPixelBuffer.h>
#import <WebRTC/RTCVideoFrameBuffer.h>
#import <ReplayKit/ReplayKit.h>
#import "FlutterSocketConnection.h"
#import <UIKit/UIKit.h>

const NSUInteger kMaxReadLength = 10 * 1024;
const CGFloat kScrMaximumSupportedResolution = 640;

@interface Message: NSObject

@property (nonatomic, assign, readonly) CVImageBufferRef imageBuffer;
@property (nonatomic, copy, nullable) void (^didComplete)(BOOL succes, Message *message);

- (NSInteger)appendBytes: (UInt8 *)buffer length:(NSUInteger)length;

@end

@interface Message ()

@property (nonatomic, assign) CVImageBufferRef imageBuffer;
@property (nonatomic, assign) CFHTTPMessageRef framedMessage;

@end

@implementation Message

- (instancetype)init {
    self = [super init];
    if (self) {
        self.imageBuffer = NULL;
    }
    
    return self;
}

- (void)dealloc {
    CVPixelBufferRelease(_imageBuffer);
}


- (NSInteger)appendBytes: (UInt8 *)buffer length:(NSUInteger)length {
    if (!_framedMessage) {
        _framedMessage = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, false);
    }
    
    CFHTTPMessageAppendBytes(_framedMessage, buffer, length);
    if (!CFHTTPMessageIsHeaderComplete(_framedMessage)) {
        return -1;
    }
    
    NSInteger contentLength = [CFBridgingRelease(CFHTTPMessageCopyHeaderFieldValue(_framedMessage, (__bridge CFStringRef)@"Content-Length")) integerValue];
    NSInteger bodyLength = (NSInteger)[CFBridgingRelease(CFHTTPMessageCopyBody(_framedMessage)) length];

    NSInteger missingBytesCount = contentLength - bodyLength;
    if (missingBytesCount == 0) {
        BOOL success = [self unwrapMessage:self.framedMessage];
        self.didComplete(success, self);
        
        CFRelease(self.framedMessage);
        self.framedMessage = NULL;
    }
    
    return missingBytesCount;
}


- (CIContext *)imageContext {
    static CIContext *imageContext = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        imageContext = [[CIContext alloc] initWithOptions:nil];
    });
    
    return imageContext;
}

- (BOOL)unwrapMessage:(CFHTTPMessageRef)framedMessage {
    size_t width = [CFBridgingRelease(CFHTTPMessageCopyHeaderFieldValue(_framedMessage, (__bridge CFStringRef)@"Buffer-Width")) integerValue];
    size_t height = [CFBridgingRelease(CFHTTPMessageCopyHeaderFieldValue(_framedMessage, (__bridge CFStringRef)@"Buffer-Height")) integerValue];
    
    NSData *messageData = CFBridgingRelease(CFHTTPMessageCopyBody(_framedMessage));
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, NULL, &_imageBuffer);
    if (status != kCVReturnSuccess) {
        NSLog(@"CVPixelBufferCreate failed");
        return false;
    }
    
    [self copyImageData:messageData toPixelBuffer:&_imageBuffer];

    return true;
}

- (void)copyImageData:(NSData *)data toPixelBuffer:(CVPixelBufferRef*)pixelBuffer {
    CVPixelBufferLockBaseAddress(*pixelBuffer, 0);
        
    CIImage *image = [CIImage imageWithData:data];
    [self.imageContext render:image toCVPixelBuffer:*pixelBuffer];
    CVPixelBufferUnlockBaseAddress(*pixelBuffer, 0);
}

@end

// MARK: -

@interface FlutterScreenCapture () <NSStreamDelegate>

@property (nonatomic, strong) FlutterSocketConnection *connection;
@property (nonatomic, strong) Message *message;

@end

@implementation FlutterScreenCapture {
    mach_timebase_info_data_t _timebaseInfo;
    NSInteger _readLength;
    int64_t _startTimeStampNs;
}

- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate {
    self = [super initWithDelegate:delegate];
    if (self) {
        mach_timebase_info(&_timebaseInfo);
    }
    
    return self;
}

- (void)startCaptureWithConnection:(FlutterSocketConnection *)connection {
    _startTimeStampNs = -1;
    
    self.connection = connection;
    self.message = nil;
    
    [self.connection openWithStreamDelegate:self];
}

- (void)stopCapture {
    [self.connection close];
}

// MARK: Private Methods

- (void)readBytesFromStream:(NSInputStream *)stream {
    if (!stream.hasBytesAvailable) {
        return;
    }
        
    if (!self.message) {
        self.message = [[Message alloc] init];
        _readLength = kMaxReadLength;
        
        __weak __typeof__(self) weakSelf = self;
        self.message.didComplete = ^(BOOL success, Message *message) {
            if (success) {
                [weakSelf didCaptureVideoFrame:message.imageBuffer];
            }
            
            weakSelf.message = nil;
        };
    }
    
    uint8_t buffer[_readLength];
    NSInteger numberOfBytesRead = [stream read:buffer maxLength:_readLength];
    if (numberOfBytesRead < 0) {
        NSLog(@"error reading bytes from stream");
        return;
    }
    
    _readLength = [self.message appendBytes:buffer length:numberOfBytesRead];
    if (_readLength == -1 || _readLength > kMaxReadLength) {
        _readLength = kMaxReadLength;
    }
}

- (void)didCaptureVideoFrame:(CVPixelBufferRef)pixelBuffer {
    
    RTCCVPixelBuffer * rtcPixelBuffer = nil;
    CGFloat originalWidth = (CGFloat)CVPixelBufferGetWidth(pixelBuffer);
    CGFloat originalHeight = (CGFloat)CVPixelBufferGetHeight(pixelBuffer);
    if (originalWidth > kScrMaximumSupportedResolution || originalHeight > kScrMaximumSupportedResolution) {
      rtcPixelBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer: pixelBuffer];
      int width = originalWidth * kScrMaximumSupportedResolution / originalHeight;
      int height = kScrMaximumSupportedResolution;
      if (originalWidth > originalHeight) {
        width = kScrMaximumSupportedResolution;
        height = originalHeight * kScrMaximumSupportedResolution / originalWidth;
      }
      CVPixelBufferRef outputPixelBuffer = nil;
      OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
      CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width,
                                              height, pixelFormat, nil,
                                              &outputPixelBuffer);
      if (status!=kCVReturnSuccess) {
          return;
      }
      int tmpBufferSize = [rtcPixelBuffer bufferSizeForCroppingAndScalingToWidth:width height:height];
      uint8_t* tmpBuffer = malloc(tmpBufferSize);
      if ([rtcPixelBuffer cropAndScaleTo:outputPixelBuffer withTempBuffer:tmpBuffer]) {
          rtcPixelBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer: outputPixelBuffer];
      } else {
          CVPixelBufferRelease(outputPixelBuffer);
          free(tmpBuffer);
          return;
      }
      CVPixelBufferRelease(outputPixelBuffer);
      free(tmpBuffer);
    }
    int64_t currentTime = mach_absolute_time();
    int64_t currentTimeStampNs = currentTime * _timebaseInfo.numer / _timebaseInfo.denom;
    int64_t frameTimeStampNs = currentTimeStampNs - _startTimeStampNs;
    RTCVideoFrame *videoFrame = [[RTCVideoFrame alloc] initWithBuffer:rtcPixelBuffer
                                                             rotation:RTCVideoRotation_0
                                                          timeStampNs:frameTimeStampNs];
    
    
//    NSLog(@"有视频数据过偶来");
    [self.delegate capturer:self didCaptureVideoFrame:videoFrame];
}


- (void)imageFromPixelBuffer:(CVPixelBufferRef)pixelBufferRef {
    
    CIImage *ciimage = [CIImage imageWithCVPixelBuffer:pixelBufferRef];
    CIImage *scaledImage = [ciimage imageByApplyingTransform:(CGAffineTransformMakeScale(0.5, 0.5))];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgimage = [context
                       createCGImage:scaledImage
                       fromRect:scaledImage.extent];
    UIImage *uiimage = [UIImage imageWithCGImage:cgimage];
    
    UIImageWriteToSavedPhotosAlbum(uiimage, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSLog(@"图片保存完毕");
}

@end

@implementation FlutterScreenCapture (NSStreamDelegate)

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            //通知flutter端屏幕共享开始
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ScreenShareBeginNotification" object:nil];
            break;
        case NSStreamEventHasBytesAvailable:
            [self readBytesFromStream: (NSInputStream *)aStream];
            break;
        case NSStreamEventEndEncountered:
            //通知flutter端屏幕共享结束
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ScreenShareEndNotification" object:nil];
            [self stopCapture];
            break;
        case NSStreamEventErrorOccurred:
            NSLog(@"server stream error encountered: %@", aStream.streamError.localizedDescription);
            break;
            
        default:
            break;
    }
}

@end
