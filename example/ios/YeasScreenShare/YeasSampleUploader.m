//
//  YeasSampleUploader.m
//  myReplayKit
//
//  Created by  on 2021/4/20.
//

#import "YeasSampleUploader.h"

#import <MessageUI/MessageUI.h>
#import <ReplayKit/ReplayKit.h>
#import "YeasSocketConnection.h"

static const NSInteger kBufferMaxLenght = 10 * 1024;

@interface YeasSampleUploader ()

@property (nonatomic, assign) BOOL isReady;

@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) YeasSocketConnection *connection;
@property (nonatomic, strong) CIContext *imageContext;

@property (nonatomic, strong) NSData *dataToSend;
@property (nonatomic, assign) NSUInteger byteIndex;

@end



@implementation YeasSampleUploader
- (instancetype)initWithConnection:(YeasSocketConnection *)connection {
  self = [super init];
  if (self) {
    self.serialQueue = dispatch_queue_create("org.jitsi.meet.broadcast.sampleUploader", DISPATCH_QUEUE_SERIAL);
    
    self.connection = connection;
    [self setupConnection];
    
    self.imageContext = [[CIContext alloc] initWithOptions:nil];
    self.isReady = false;
  }
  
  return self;
}

- (void)sendSample:(CMSampleBufferRef)sampleBuffer {
  self.isReady = false;
  
  self.dataToSend = [self prepareSample:sampleBuffer];
  self.byteIndex = 0;
  
  dispatch_async(self.serialQueue, ^{
    [self sendData];
  });
}


- (void)setupConnection {
  __weak __typeof(self) weakSelf = self;
  self.connection.didOpen = ^{
    weakSelf.isReady = true;
  };
  self.connection.streamHasSpaceAvailable = ^{
    dispatch_async(weakSelf.serialQueue, ^{
      weakSelf.isReady = ![weakSelf sendData];
    });
  };
}


- (NSData *)prepareSample:(CMSampleBufferRef)sampleBuffer {
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
  CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
  
  CGFloat scaleFactor = 2;
  size_t width = CVPixelBufferGetWidth(imageBuffer)/scaleFactor;
  size_t height = CVPixelBufferGetHeight(imageBuffer)/scaleFactor;
    
  CGAffineTransform scaleTransform = CGAffineTransformMakeScale(1/scaleFactor, 1/scaleFactor);
  NSData *bufferData = [self jpegDataFromPixelBuffer:imageBuffer withScaling:scaleTransform];
  
  CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
  
  if (bufferData) {
    CFHTTPMessageRef httpResponse = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 200, NULL, kCFHTTPVersion1_1);
    CFHTTPMessageSetHeaderFieldValue(httpResponse, (__bridge CFStringRef)@"Content-Length", (__bridge CFStringRef)[NSString stringWithFormat:@"%ld", bufferData.length]);
    CFHTTPMessageSetHeaderFieldValue(httpResponse, (__bridge CFStringRef)@"Buffer-Width", (__bridge CFStringRef)[NSString stringWithFormat:@"%ld", width]);
    CFHTTPMessageSetHeaderFieldValue(httpResponse, (__bridge CFStringRef)@"Buffer-Height", (__bridge CFStringRef)[NSString stringWithFormat:@"%ld", height]);

    CFHTTPMessageSetBody(httpResponse, (__bridge CFDataRef)bufferData);

    CFDataRef serializedMessage = CFHTTPMessageCopySerializedMessage(httpResponse);
    CFRelease(httpResponse);
    
    return CFBridgingRelease(serializedMessage);
  }
  
  return nil;
}

- (BOOL)sendData {
  if (!self.dataToSend) {
    NSLog(@"no data to send");
    return false;
  }

  NSUInteger bytesLeft = self.dataToSend.length - self.byteIndex;
  
  NSInteger length = bytesLeft > kBufferMaxLenght ? kBufferMaxLenght : bytesLeft;
  uint8_t buffer[length];
  [self.dataToSend getBytes:&buffer range:NSMakeRange(self.byteIndex, length)];

  length = [self.connection writeBufferToStream:buffer maxLength:length];
  if (length > 0) {
    self.byteIndex += length;
    bytesLeft -= length;

    if (bytesLeft == 0) {
      self.dataToSend = nil;
      self.byteIndex = 0;
    }
  }
  else {
  }
  
  return true;
}

- (NSData *)jpegDataFromPixelBuffer:(CVPixelBufferRef)pixelBuffer withScaling:(CGAffineTransform)scaleTransform {
  CIImage *image = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer];
  image = [image imageByApplyingTransform:scaleTransform];
  
  NSDictionary *options = @{(NSString *)kCGImageDestinationLossyCompressionQuality: [NSNumber numberWithFloat:1.0]};
  NSData *imageData = [self.imageContext JPEGRepresentationOfImage:image
                                                        colorSpace:image.colorSpace
                                                           options:options];
  return imageData;
}
@end
