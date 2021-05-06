//
//  FlutterGPUImageCapture.m
//  flutter_webrtc
//
//  Created by  on 2021/4/27.
//

#import "FlutterGPUImageCapture.h"
#include <mach/mach_time.h>
#import "FlutterScreenCapture.h"
#import "FlutterGPUImageWriterExport.h"

@interface FlutterGPUImageCapture ()<PixelBufferDelegate>


@property (atomic, strong) GPUImageOutput<GPUImageInput> *filter;
/** FlutterGPUImageWriterExport */
@property (nonatomic, strong) FlutterGPUImageWriterExport *writerExport;
/** 磨皮 */
@property (nonatomic, strong) GPUImageBilateralFilter *bilateralFilter;
/** 美白 */
@property (nonatomic, strong) GPUImageBrightnessFilter *brightnessFilter;
@end

@implementation FlutterGPUImageCapture

{
    mach_timebase_info_data_t _timebaseInfo;
    int64_t _startTimeStampNs;
}


- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate {
    self = [super initWithDelegate:delegate];
    if (self) {
        mach_timebase_info(&_timebaseInfo);
        _bilateral = 8;
        _brightness = 0.1;
    }
    return self;
}

- (GPUImageVideoCamera *)videoCamera {
    if (!_videoCamera) {
        _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront];
        _videoCamera.outputImageOrientation = UIDeviceOrientationPortrait;
        
        GPUImageFilterGroup *filterGroup = [[GPUImageFilterGroup alloc] init];
        //设置磨皮,值越大磨皮效果越好，最大10
        GPUImageBilateralFilter *bilateralFilter = [[GPUImageBilateralFilter alloc] init];
        bilateralFilter.distanceNormalizationFactor = _bilateral;
        [filterGroup addTarget:bilateralFilter];
        _bilateralFilter = bilateralFilter;
        
        //设置美白取值-1~1,0是正常范围
        GPUImageBrightnessFilter *brightnessFilter = [[GPUImageBrightnessFilter alloc] init];
        brightnessFilter.brightness = _brightness;
        [filterGroup addTarget:brightnessFilter];
        _brightnessFilter = brightnessFilter;
        
        //添加滤镜组链
        [bilateralFilter addTarget:brightnessFilter];
        [filterGroup setInitialFilters:@[bilateralFilter]];
        filterGroup.terminalFilter = brightnessFilter;
        
        //相机添加滤镜组
        [_videoCamera addTarget:filterGroup];
        
        NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"];
        unlink([pathToMovie UTF8String]);
        NSURL *movieURL = [NSURL fileURLWithPath:pathToMovie];
        _writerExport = [[FlutterGPUImageWriterExport alloc] initWithMovieURL:movieURL size:CGSizeMake(720, 1280)];
        _writerExport.encodingLiveVideo =  YES;
        _writerExport.pixelBufferdelegate = self;
        [filterGroup addTarget:_writerExport];
    }
    return _videoCamera;
}

- (void)setBilateral:(CGFloat)bilateral {
    _bilateral = bilateral;
    if (_bilateralFilter) {
        _bilateralFilter.distanceNormalizationFactor = bilateral;
    }
}

- (void)setBrightness:(CGFloat)brightness {
    _brightness =  brightness;
    if (_brightnessFilter) {
        _brightnessFilter.brightness = brightness;
    }
}

- (void)startCapture {
    _startTimeStampNs = -1;
    [self.videoCamera startCameraCapture];
    [_writerExport startRecording];
}

- (void)stopCapture {
    [_videoCamera stopCameraCapture];
    [_writerExport cancelRecording];
}

-(void)PixelBufferCallback:(CVPixelBufferRef)pixelFrameBuffer {
    
    [self didCaptureVideoFrame:pixelFrameBuffer];
}



//UIImage* imageFromSampleBuffer(CVImageBufferRef nextBuffer) {
//    
//    CVImageBufferRef imageBuffer =  nextBuffer;
//    
//    CVPixelBufferLockBaseAddress(imageBuffer, 0);
//    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
//    size_t width = CVPixelBufferGetWidth(imageBuffer);
//    size_t height = CVPixelBufferGetHeight(imageBuffer);
//    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
//    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
//    
//    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
//    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);
//    
//    CGImageRef cgImage = CGImageCreate(width, height, 8, 32, bytesPerRow, rgbColorSpace, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrderDefault, provider, NULL, true, kCGRenderingIntentDefault);
//    UIImage *image = [UIImage imageWithCGImage:cgImage];
//    CGImageRelease(cgImage);
//    CGDataProviderRelease(provider);
//    CGColorSpaceRelease(rgbColorSpace);
//    
//    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
//    return image;
//}


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
    [self.delegate capturer:self didCaptureVideoFrame:videoFrame];
}

@end
