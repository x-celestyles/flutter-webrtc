//
//  FlutterGPUImageCapture.m
//  flutter_webrtc
//
//  Created by  on 2021/4/27.
//

#import "FlutterGPUImageCapture.h"
#include <mach/mach_time.h>
#import "FlutterScreenCapture.h"
#import <MLImageSegmentationLibrary/MLImageSegmentationLibrary.h>

#import "FlutterGPUImagePicture.h"
#import "UIImage+PixBuffer.h"


@interface FlutterGPUImageCapture ()<FlutterRTCVideoCameraDelegate>{
    
    double _tiem_pre;
}

//背景墙
@property(nonatomic, strong) MLImageSegmentationAnalyzer *imgSegAnalyzer;

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
        
        [self initMLSegment];
    }
    return self;
}

- (void)initMLSegment {
    
    self.imgSegAnalyzer = [MLImageSegmentationAnalyzer sharedInstance];
    MLImageSegmentationSetting *setting = [[MLImageSegmentationSetting alloc] init];
    [setting setAnalyzerType:MLImageSegmentationAnalyzerTypeBody];
    [setting setScene:MLImageSegmentationSceneForegroundOnly];
    [setting setExact:NO];
    [self.imgSegAnalyzer setImageSegmentationAnalyzer:setting];
}

- (FlutterRTCVideoCamera *)videoCamera {
    if (!_videoCamera) {
        _videoCamera = [[FlutterRTCVideoCamera alloc] init];
        _videoCamera.delegate = self;
    }
    return _videoCamera;
}

- (void)didOutPutSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
    //在这里添加背景墙
    HW_TIME_BEGIN(total);
    
    UIImage *image = [UIImage convertPixBufferToImage:CMSampleBufferGetImageBuffer(sampleBuffer)];
    MLFrame *frame = [[MLFrame alloc] initWithImage:image];
    MLImageSegmentation *imgSeg = [self.imgSegAnalyzer analyseFrame:frame];
    UIImage *foregroundImage = [imgSeg getForeground];
    UIImage *backImage = [UIImage imageNamed:@"background.jpg"];
    if (foregroundImage && backImage) {
        
        FlutterGPUImagePicture *input = [[FlutterGPUImagePicture alloc] initWithImage:foregroundImage outPutSize:CGSizeMake(720, 1280)];
        
        FlutterGPUImagePicture *input1 = [[FlutterGPUImagePicture alloc] initWithImage:backImage outPutSize:CGSizeMake(720, 1280)];
        //混合前后两张图片
        GPUImageAlphaBlendFilter *filter = [[GPUImageAlphaBlendFilter alloc] init];
        filter.mix = 1.0;
        //先混合背景图片
        [input1 addTarget:filter];
        [input1 processImage];
        
        [filter useNextFrameForImageCapture];
        //再混合前景图片
        [input addTarget:filter];
        [input processImage];
        //获取混合的图片
       foregroundImage = filter.imageFromCurrentFramebuffer;
    }
    HW_TIME_END(total);
    
    CVPixelBufferRef convertBuffer = [UIImage convertImageToPixBuffer:foregroundImage];
    if (totalt1.tv_sec - self->_tiem_pre > 1) {
        self->_tiem_pre = totalt1.tv_sec;
    }
    [self handlePixbuffer:convertBuffer];
}

- (void)startCapture {
    _startTimeStampNs = -1;
    [self.videoCamera startCaputre];
 
}

- (void)stopCapture {
    [self.videoCamera stopCapture];
}


- (void)handlePixbuffer:(CVPixelBufferRef)convertBuffer {
        
    RTCCVPixelBuffer * rtcPixelBuffer = nil;
    CGFloat originalWidth = (CGFloat)CVPixelBufferGetWidth(convertBuffer);
    CGFloat originalHeight = (CGFloat)CVPixelBufferGetHeight(convertBuffer);
    if (originalWidth > kScrMaximumSupportedResolution || originalHeight > kScrMaximumSupportedResolution) {
        rtcPixelBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer: convertBuffer];
        int width = originalWidth * kScrMaximumSupportedResolution / originalHeight;
        int height = kScrMaximumSupportedResolution;
        if (originalWidth > originalHeight) {
            width = kScrMaximumSupportedResolution;
            height = originalHeight * kScrMaximumSupportedResolution / originalWidth;
        }
        CVPixelBufferRef outputPixelBuffer = nil;
        OSType pixelFormat = CVPixelBufferGetPixelFormatType(convertBuffer);
        CVPixelBufferRelease(convertBuffer);
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
